package main

import "testing"

func TestParseWelcomeColony(t *testing.T) {
	msg, err := ParseLine("WELCOME srv-0 3 aurora 96CDFB 60 40 1000 3 4,34")
	if err != nil {
		t.Fatal(err)
	}
	if msg.Type != "welcome" || msg.Role != "colony" {
		t.Fatalf("tipo/role errados: %+v", msg)
	}
	if msg.ID != 3 || msg.Name != "aurora" || msg.Color != "96CDFB" {
		t.Fatalf("identidade errada: %+v", msg)
	}
	if msg.W != 60 || msg.H != 40 || msg.TickMs != 1000 || msg.ViewRadius != 3 {
		t.Fatalf("dimensoes erradas: %+v", msg)
	}
	if msg.SpawnX != 4 || msg.SpawnY != 34 {
		t.Fatalf("spawn errado: %+v", msg)
	}
}

func TestParseObservation(t *testing.T) {
	msg, err := ParseLine("OBS srv-97 97 alive 97 9,5,plain,0,0;10,5,plain,3,1")
	if err != nil {
		t.Fatal(err)
	}
	if msg.Tick != 97 || msg.Status != "alive" || msg.ScoresTick != 97 {
		t.Fatalf("cabecalho errado: %+v", msg)
	}
	want := []Cell{
		{X: 9, Y: 5, Terrain: "plain", Owner: 0, Fortified: 0},
		{X: 10, Y: 5, Terrain: "plain", Owner: 3, Fortified: 1},
	}
	if len(msg.Cells) != len(want) || msg.Cells[0] != want[0] || msg.Cells[1] != want[1] {
		t.Fatalf("celulas erradas: %+v", msg.Cells)
	}
}

func TestTolerantReader(t *testing.T) {
	msg, err := ParseLine("ACK aurora-k3f9-17 97 extra tokens")
	if err != nil || msg.Tick != 97 {
		t.Fatalf("ack com tokens extras: %v %+v", err, msg)
	}
}

func TestParseNackScore(t *testing.T) {
	nack, err := ParseLine("NACK aurora-k3f9-17 too_late tick 96 resolvido")
	if err != nil || nack.Code != "too_late" || nack.Detail != "tick 96 resolvido" {
		t.Fatalf("nack: %v %+v", err, nack)
	}
	score, err := ParseLine("SCORE srv-97 97 3,aurora,21,alive;5,nova,14,dead")
	if err != nil {
		t.Fatal(err)
	}
	if len(score.Entries) != 2 || score.Entries[1] != (ScoreEntry{ID: 5, Name: "nova", Cells: 14, Status: "dead"}) {
		t.Fatalf("score: %+v", score.Entries)
	}
}

func TestMalformedNeverPanics(t *testing.T) {
	for _, line := range []string{
		"ACTN foo bar",
		"OBS srv-97 x alive 97",
		"OBS srv-97 97 undead 97",
		"WELCOME srv-0 3 aurora 96CDFB 60 40 1000 3",
		"ACK ref notanumber",
		"NACK aurora-k3f9-17",
		"ERR",
	} {
		if _, err := ParseLine(line); err == nil {
			t.Fatalf("esperava erro para %q", line)
		}
	}
	if _, ok := ParseCell("9,5,plain,0"); ok {
		t.Fatal("celula curta deveria falhar")
	}
}

func TestEncode(t *testing.T) {
	refs := &Refs{name: "aurora", session: "k3f9"}
	if got := refs.Next(); got != "aurora-k3f9-1" {
		t.Fatalf("ref: %s", got)
	}
	if got := EncodeAction(Action{Kind: "expand", X: 12, Y: 7}, refs.Next()); got != "ACT aurora-k3f9-2 expand 12 7" {
		t.Fatalf("encode expand: %s", got)
	}
	if got := EncodeAction(Action{Kind: "pass"}, refs.Next()); got != "ACT aurora-k3f9-3 pass" {
		t.Fatalf("encode pass: %s", got)
	}
}
