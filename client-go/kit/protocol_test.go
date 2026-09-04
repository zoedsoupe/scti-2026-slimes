package main

// E1/E2: parse das linhas do servidor e codificação das linhas do cliente.

import (
	"strings"
	"testing"
)

func TestE1ObsValidaViraObservacao(t *testing.T) {
	msg, err := ParseObservation("OBS srv-97 97 alive 97 9,5,plain,0,0;10,5,plain,3,1")
	if err != nil {
		t.Fatal(err)
	}
	if msg.Type != "obs" || msg.Tick != 97 || msg.Status != "alive" || msg.ScoresTick != 97 {
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

func TestE1TokenExtraIgnorado(t *testing.T) {
	msg, err := ParseObservation("OBS srv-1 1 alive 1 1,2,plain,0,0 lixo")
	if err != nil {
		t.Fatalf("token extra derrubou o parse: %v", err)
	}
	if len(msg.Cells) != 1 {
		t.Fatalf("celulas erradas: %+v", msg.Cells)
	}
}

func TestE1ObsSemTickEhErro(t *testing.T) {
	if _, err := ParseObservation("OBS srv-1 alive 1"); err == nil {
		t.Fatal("OBS sem tick passou")
	}
}

func TestE1CelulaForestComDono(t *testing.T) {
	c, ok := ParseCell("11,5,forest,2,0")
	if !ok || c.Terrain != "forest" || c.Owner != 2 {
		t.Fatalf("celula errada: %+v", c)
	}
}

func TestE2EncodeCobreOsQuatroKinds(t *testing.T) {
	cases := []struct {
		action Action
		ref    string
		want   string
	}{
		{Action{Kind: "expand", X: 1, Y: 2}, "r-1", "ACT r-1 expand 1 2"},
		{Action{Kind: "attack", X: 3, Y: 4}, "r-2", "ACT r-2 attack 3 4"},
		{Action{Kind: "fortify", X: 5, Y: 6}, "r-3", "ACT r-3 fortify 5 6"},
		{Action{Kind: "pass"}, "r-4", "ACT r-4 pass"},
	}
	for _, c := range cases {
		if got := EncodeAction(c.action, c.ref); got != c.want {
			t.Fatalf("encode %+v: got %q, want %q", c.action, got, c.want)
		}
	}
}

func TestE2PassOmiteCoordenadas(t *testing.T) {
	line := EncodeAction(Action{Kind: "pass"}, "r-9")
	if len(strings.Fields(line)) != 3 {
		t.Fatalf("pass com coordenada: %q", line)
	}
}

func TestE2RefsMantemSessaoEIncrementam(t *testing.T) {
	refs := &Refs{name: "aurora", session: "k3f9"}
	if got := refs.Next(); got != "aurora-k3f9-1" {
		t.Fatalf("ref: %s", got)
	}
	if got := refs.Next(); got != "aurora-k3f9-2" {
		t.Fatalf("ref: %s", got)
	}
}
