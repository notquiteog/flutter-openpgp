package bridge

import (
	"bytes"
	"io"
	"strings"
	"testing"

	"github.com/ProtonMail/go-crypto/openpgp"
	"github.com/ProtonMail/go-crypto/openpgp/armor"
	"github.com/ProtonMail/go-crypto/openpgp/packet"
	openpgpv2 "github.com/ProtonMail/go-crypto/openpgp/v2"
)

// newTestIdentity returns the same key material as both a v1 and a v2 entity
// (serialized once, parsed by each API) plus its armored public key.
func newTestIdentity(t *testing.T, name string) (*openpgp.Entity, *openpgpv2.Entity) {
	t.Helper()
	v1, err := openpgp.NewEntity(name, "", name+"@test.local", nil)
	if err != nil {
		t.Fatalf("NewEntity: %v", err)
	}
	var priv bytes.Buffer
	if err := v1.SerializePrivateWithoutSigning(&priv, nil); err != nil {
		t.Fatalf("serialize private: %v", err)
	}
	v2list, err := openpgpv2.ReadKeyRing(bytes.NewReader(priv.Bytes()))
	if err != nil {
		t.Fatalf("v2 read keyring: %v", err)
	}
	if len(v2list) != 1 {
		t.Fatalf("expected 1 v2 entity, got %d", len(v2list))
	}
	return v1, v2list[0]
}

// encryptHiddenV2 mirrors what the bridge's hidden-recipients path does:
// openpgp/v2 Encrypt with every recipient in toHidden (anonymous PKESKs).
func encryptHiddenV2(t *testing.T, plaintext string, toHidden []*openpgpv2.Entity) string {
	t.Helper()
	var buf bytes.Buffer
	armorWriter, err := armor.Encode(&buf, "PGP MESSAGE", nil)
	if err != nil {
		t.Fatalf("armor: %v", err)
	}
	w, err := openpgpv2.Encrypt(armorWriter, nil, toHidden, nil, nil, nil)
	if err != nil {
		t.Fatalf("v2 encrypt: %v", err)
	}
	if _, err := io.WriteString(w, plaintext); err != nil {
		t.Fatalf("write: %v", err)
	}
	w.Close()
	armorWriter.Close()
	return buf.String()
}

// TestHiddenRecipientsRoundTrip is the gate for the hidden-recipients feature:
// (1) every PKESK in the produced message must carry a zeroed (wildcard) key
// id, and (2) the bridge's EXISTING v1 ReadMessage decrypt path must decrypt
// it by trial — for every recipient. If this fails, the bridge decrypt must
// move to openpgp/v2 before the feature can ship.
func TestHiddenRecipientsRoundTrip(t *testing.T) {
	aliceV1, aliceV2 := newTestIdentity(t, "alice")
	bobV1, bobV2 := newTestIdentity(t, "bob")

	const plaintext = "hidden recipients gate test"
	armored := encryptHiddenV2(t, plaintext, []*openpgpv2.Entity{aliceV2, bobV2})

	// (1) Packet inspection: all PKESKs are anonymous (key id zeroed).
	block, err := armor.Decode(strings.NewReader(armored))
	if err != nil {
		t.Fatalf("armor decode: %v", err)
	}
	reader := packet.NewReader(block.Body)
	pkeskCount := 0
	for {
		p, err := reader.Next()
		if err != nil {
			break
		}
		if pkesk, ok := p.(*packet.EncryptedKey); ok {
			pkeskCount++
			if pkesk.KeyId != 0 {
				t.Fatalf("PKESK %d leaks key id %x — recipients are not hidden", pkeskCount, pkesk.KeyId)
			}
		}
	}
	if pkeskCount != 2 {
		t.Fatalf("expected 2 PKESKs, found %d", pkeskCount)
	}

	// (2) The unchanged v1 decrypt path (what callDecrypt uses) must work for
	// each recipient via trial decryption.
	for _, recipient := range []*openpgp.Entity{aliceV1, bobV1} {
		block, err := armor.Decode(strings.NewReader(armored))
		if err != nil {
			t.Fatalf("armor decode: %v", err)
		}
		md, err := openpgp.ReadMessage(block.Body, openpgp.EntityList{recipient}, nil, nil)
		if err != nil {
			t.Fatalf("v1 ReadMessage with hidden PKESK failed: %v", err)
		}
		got, err := io.ReadAll(md.UnverifiedBody)
		if err != nil {
			t.Fatalf("read body: %v", err)
		}
		if string(got) != plaintext {
			t.Fatalf("plaintext mismatch: %q", got)
		}
	}
}
