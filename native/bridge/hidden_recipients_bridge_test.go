package bridge

import (
	"bytes"
	"strings"
	"testing"

	"github.com/ProtonMail/go-crypto/openpgp"
	"github.com/ProtonMail/go-crypto/openpgp/armor"
	"github.com/ProtonMail/go-crypto/openpgp/packet"
	flatbuffers "github.com/google/flatbuffers/go"
)

// buildEncryptRequest mirrors the Dart EncryptRequestObjectBuilder layout:
// message@4, publicKey@6, options(KeyOptions)@8 — with the new
// hiddenRecipients bool at KeyOptions slot 20 (field index 8).
func buildEncryptRequest(message, publicKey string, hiddenRecipients bool) []byte {
	b := flatbuffers.NewBuilder(0)
	msgOff := b.CreateString(message)
	keyOff := b.CreateString(publicKey)

	// KeyOptions table (9 fields; only hiddenRecipients set).
	b.StartObject(9)
	b.PrependBoolSlot(8, hiddenRecipients, false)
	koOff := b.EndObject()

	// EncryptRequest table.
	b.StartObject(5)
	b.PrependUOffsetTSlot(0, msgOff, 0) // message @4
	b.PrependUOffsetTSlot(1, keyOff, 0) // publicKey @6
	b.PrependUOffsetTSlot(2, koOff, 0)  // options @8
	reqOff := b.EndObject()
	b.Finish(reqOff)
	return b.FinishedBytes()
}

func buildDecryptRequest(message, privateKey string) []byte {
	b := flatbuffers.NewBuilder(0)
	msgOff := b.CreateString(message)
	keyOff := b.CreateString(privateKey)
	b.StartObject(6)
	b.PrependUOffsetTSlot(0, msgOff, 0) // message @4
	b.PrependUOffsetTSlot(1, keyOff, 0) // privateKey @6
	reqOff := b.EndObject()
	b.Finish(reqOff)
	return b.FinishedBytes()
}

func armoredKeys(t *testing.T, e *openpgp.Entity) (pub, priv string) {
	t.Helper()
	var pubBuf bytes.Buffer
	pubArmor, err := armor.Encode(&pubBuf, openpgp.PublicKeyType, nil)
	if err != nil {
		t.Fatal(err)
	}
	if err := e.Serialize(pubArmor); err != nil {
		t.Fatal(err)
	}
	pubArmor.Close()

	var privBuf bytes.Buffer
	privArmor, err := armor.Encode(&privBuf, openpgp.PrivateKeyType, nil)
	if err != nil {
		t.Fatal(err)
	}
	if err := e.SerializePrivateWithoutSigning(privArmor, nil); err != nil {
		t.Fatal(err)
	}
	privArmor.Close()
	return pubBuf.String(), privBuf.String()
}

// TestBridgeEncryptHiddenRecipients drives the REAL bridge entry points the
// app uses ("encrypt"/"decrypt" via flatbuffers payloads) with the new
// hiddenRecipients option and proves: anonymous PKESKs on the wire, and the
// untouched decrypt op still recovers the plaintext.
func TestBridgeEncryptHiddenRecipients(t *testing.T) {
	entity, err := openpgp.NewEntity("carol", "", "carol@test.local", nil)
	if err != nil {
		t.Fatal(err)
	}
	pub, priv := armoredKeys(t, entity)
	const plaintext = "bridge-level hidden recipients"

	// hidden = true → PKESK key ids must be zero.
	resp, err := Call("encrypt", buildEncryptRequest(plaintext, pub, true))
	if err != nil {
		t.Fatalf("encrypt call: %v", err)
	}
	armored := stringResponseOutput(t, resp)

	block, err := armor.Decode(strings.NewReader(armored))
	if err != nil {
		t.Fatalf("armor decode: %v", err)
	}
	reader := packet.NewReader(block.Body)
	sawPKESK := false
	for {
		p, err := reader.Next()
		if err != nil {
			break
		}
		if pkesk, ok := p.(*packet.EncryptedKey); ok {
			sawPKESK = true
			if pkesk.KeyId != 0 {
				t.Fatalf("hidden encrypt leaked key id %x", pkesk.KeyId)
			}
		}
	}
	if !sawPKESK {
		t.Fatal("no PKESK packets found")
	}

	resp, err = Call("decrypt", buildDecryptRequest(armored, priv))
	if err != nil {
		t.Fatalf("decrypt call: %v", err)
	}
	if got := stringResponseOutput(t, resp); got != plaintext {
		t.Fatalf("round trip mismatch: %q", got)
	}

	// hidden = false (default) → behavior unchanged: key ids present.
	resp, err = Call("encrypt", buildEncryptRequest(plaintext, pub, false))
	if err != nil {
		t.Fatalf("plain encrypt call: %v", err)
	}
	armored = stringResponseOutput(t, resp)
	block, err = armor.Decode(strings.NewReader(armored))
	if err != nil {
		t.Fatalf("armor decode: %v", err)
	}
	reader = packet.NewReader(block.Body)
	for {
		p, err := reader.Next()
		if err != nil {
			break
		}
		if pkesk, ok := p.(*packet.EncryptedKey); ok {
			if pkesk.KeyId == 0 {
				t.Fatal("default encrypt unexpectedly produced an anonymous PKESK")
			}
		}
	}
}

// stringResponseOutput unpacks the bridge's StringResponse {output@4, error@6}.
func stringResponseOutput(t *testing.T, payload []byte) string {
	t.Helper()
	tab := rootTable(payload)
	if errMsg := fbString(&tab, 6); errMsg != "" {
		t.Fatalf("bridge returned error: %s", errMsg)
	}
	return fbString(&tab, 4)
}
