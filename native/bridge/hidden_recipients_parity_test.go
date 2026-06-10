package bridge

import (
	"bytes"
	"crypto"
	"io"
	"strings"
	"testing"

	"github.com/ProtonMail/go-crypto/openpgp"
	"github.com/ProtonMail/go-crypto/openpgp/armor"
	"github.com/ProtonMail/go-crypto/openpgp/packet"
)

// messageProperties are the negotiated crypto parameters of an encrypted+
// signed message that could conceivably differ between encrypt paths.
type messageProperties struct {
	sessionCipher packet.CipherFunction // symmetric cipher protecting the body
	sigHash       crypto.Hash           // hash used by the embedded signature
	plaintext     string
}

func inspectMessage(t *testing.T, armored string, recipient *openpgp.Entity) messageProperties {
	t.Helper()
	props := messageProperties{}

	// Session cipher: decrypt the PKESK directly (works for wildcard key ids
	// too — we know which key to use).
	block, err := armor.Decode(strings.NewReader(armored))
	if err != nil {
		t.Fatalf("armor: %v", err)
	}
	reader := packet.NewReader(block.Body)
	for {
		p, err := reader.Next()
		if err != nil {
			break
		}
		if pkesk, ok := p.(*packet.EncryptedKey); ok {
			decKey := recipient.PrivateKey
			for _, sub := range recipient.Subkeys {
				if sub.PrivateKey != nil && sub.PublicKey.PubKeyAlgo.CanEncrypt() {
					decKey = sub.PrivateKey
				}
			}
			if err := pkesk.Decrypt(decKey, nil); err != nil {
				t.Fatalf("pkesk decrypt: %v", err)
			}
			props.sessionCipher = pkesk.CipherFunc
		}
	}

	// Signature hash + plaintext: full ReadMessage pass.
	block, err = armor.Decode(strings.NewReader(armored))
	if err != nil {
		t.Fatalf("armor: %v", err)
	}
	md, err := openpgp.ReadMessage(block.Body, openpgp.EntityList{recipient}, nil, nil)
	if err != nil {
		t.Fatalf("ReadMessage: %v", err)
	}
	body, err := io.ReadAll(md.UnverifiedBody)
	if err != nil {
		t.Fatalf("body: %v", err)
	}
	props.plaintext = string(body)
	if md.SignatureError != nil {
		t.Fatalf("signature: %v", md.SignatureError)
	}
	if md.Signature == nil {
		t.Fatal("expected a signature")
	}
	props.sigHash = md.Signature.Hash
	return props
}

// TestHiddenPathParityWithDefaultPath proves the hidden-recipients path does
// not weaken anything relative to the pre-existing default path for keys like
// the app's (EdDSA/Curve25519 generated with AES-256 + SHA-512 preferences):
// same session cipher, same signature hash, same plaintext round trip. The
// ONLY intended difference is the zeroed PKESK key id.
func TestHiddenPathParityWithDefaultPath(t *testing.T) {
	// Mirror the app's key generation options (Algorithm.EDDSA,
	// Curve.CURVE25519, Hash.SHA512, Cipher.AES256).
	keyCfg := &packet.Config{
		Algorithm:     packet.PubKeyAlgoEdDSA,
		Curve:         packet.Curve25519,
		DefaultCipher: packet.CipherAES256,
		DefaultHash:   crypto.SHA512,
	}
	recipient, err := openpgp.NewEntity("appuser", "", "appuser@test.local", keyCfg)
	if err != nil {
		t.Fatalf("NewEntity: %v", err)
	}
	const plaintext = "cipher/hash parity probe"

	// OLD path: exactly what the app produced before — options absent, so the
	// bridge passed a nil packet.Config to v1 Encrypt.
	var oldBuf bytes.Buffer
	oldArmor, err := armor.Encode(&oldBuf, "PGP MESSAGE", nil)
	if err != nil {
		t.Fatal(err)
	}
	w, err := openpgp.Encrypt(oldArmor, []*openpgp.Entity{recipient}, recipient, nil, nil)
	if err != nil {
		t.Fatalf("v1 encrypt: %v", err)
	}
	if _, err := io.WriteString(w, plaintext); err != nil {
		t.Fatal(err)
	}
	w.Close()
	oldArmor.Close()

	// NEW path: what the app produces now — KeyOptions with ONLY
	// hiddenRecipients set, through the real bridge helper.
	var privBuf bytes.Buffer
	privArmor, err := armor.Encode(&privBuf, openpgp.PrivateKeyType, nil)
	if err != nil {
		t.Fatal(err)
	}
	if err := recipient.SerializePrivateWithoutSigning(privArmor, nil); err != nil {
		t.Fatal(err)
	}
	privArmor.Close()
	var pubBuf bytes.Buffer
	pubArmor, err := armor.Encode(&pubBuf, openpgp.PublicKeyType, nil)
	if err != nil {
		t.Fatal(err)
	}
	if err := recipient.Serialize(pubArmor); err != nil {
		t.Fatal(err)
	}
	pubArmor.Close()

	var newBuf bytes.Buffer
	newArmor, err := armor.Encode(&newBuf, "PGP MESSAGE", nil)
	if err != nil {
		t.Fatal(err)
	}
	ko := &keyOptions{hiddenRecipients: true}
	signed := &entityFields{privateKey: privBuf.String()}
	if err := encryptHiddenRecipients(newArmor, pubBuf.String(), signed, []byte(plaintext), ko, nil); err != nil {
		t.Fatalf("hidden encrypt: %v", err)
	}
	newArmor.Close()

	oldProps := inspectMessage(t, oldBuf.String(), recipient)
	newProps := inspectMessage(t, newBuf.String(), recipient)

	if oldProps.plaintext != plaintext || newProps.plaintext != plaintext {
		t.Fatalf("plaintext mismatch: old=%q new=%q", oldProps.plaintext, newProps.plaintext)
	}
	if newProps.sessionCipher != oldProps.sessionCipher {
		t.Fatalf("session cipher changed: old=%v new=%v — hidden path downgrades the cipher",
			oldProps.sessionCipher, newProps.sessionCipher)
	}
	if newProps.sigHash != oldProps.sigHash {
		t.Fatalf("signature hash changed: old=%v new=%v", oldProps.sigHash, newProps.sigHash)
	}
	// Status quo (both paths): go-crypto seeds the candidate cipher set from
	// the ENCRYPT-TIME config — nil config → AES-128 — and intersects it with
	// the key's preferences, so AES-128 is what the default path has always
	// produced. The hidden path must match it, no better and no worse.
	if oldProps.sessionCipher != packet.CipherAES128 {
		t.Fatalf("baseline assumption broke: default path now yields %v", oldProps.sessionCipher)
	}
	t.Logf("parity: cipher=%v hash=%v on both paths", newProps.sessionCipher, newProps.sigHash)

	// And an explicit cipher option must flow through the hidden path: with
	// KeyOptions{cipher: AES256, hiddenRecipients: true} the session key is
	// AES-256 (the key's preferences include it).
	var strongBuf bytes.Buffer
	strongArmor, err := armor.Encode(&strongBuf, "PGP MESSAGE", nil)
	if err != nil {
		t.Fatal(err)
	}
	strongKo := &keyOptions{cipher: 2 /* AES256 */, hiddenRecipients: true}
	if err := encryptHiddenRecipients(strongArmor, pubBuf.String(), signed, []byte(plaintext), strongKo, nil); err != nil {
		t.Fatalf("hidden AES-256 encrypt: %v", err)
	}
	strongArmor.Close()
	strongProps := inspectMessage(t, strongBuf.String(), recipient)
	if strongProps.sessionCipher != packet.CipherAES256 {
		t.Fatalf("explicit AES-256 option ignored by hidden path: got %v", strongProps.sessionCipher)
	}
	if strongProps.plaintext != plaintext {
		t.Fatalf("AES-256 round trip mismatch: %q", strongProps.plaintext)
	}
}
