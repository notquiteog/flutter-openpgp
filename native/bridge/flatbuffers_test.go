package bridge

import "testing"

func TestStringResponseWritesEmptyOutput(t *testing.T) {
	data := stringResponse("", "")
	table := rootTable(data)

	if table.Offset(4) == 0 {
		t.Fatal("stringResponse should serialize an empty success output")
	}
	if got := fbString(&table, 4); got != "" {
		t.Fatalf("expected empty string output, got %q", got)
	}
}

func TestBytesResponseWritesEmptyOutput(t *testing.T) {
	data := bytesResponse(nil, "")
	table := rootTable(data)

	if table.Offset(4) == 0 {
		t.Fatal("bytesResponse should serialize an empty success output")
	}
	if got := fbBytes(&table, 4); len(got) != 0 {
		t.Fatalf("expected empty byte output, got %d bytes", len(got))
	}
}
