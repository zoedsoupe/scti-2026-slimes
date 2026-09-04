package main

// E3: classe da ação esperada para observações fixas (não a célula exata).

import "testing"

func cell(x, y, owner, fortified int) Cell {
	return Cell{X: x, Y: y, Terrain: "plain", Owner: owner, Fortified: fortified}
}

func TestE3InimigoDesfortificadoAdjacenteLevaAttack(t *testing.T) {
	obs := Message{Type: "obs", Cells: []Cell{cell(5, 5, 1, 0), cell(6, 5, 2, 0)}}
	if got := Decide(obs, 1).Kind; got != "attack" {
		t.Fatalf("kind: %s", got)
	}
}

func TestE3SemInimigosComVaziaAdjacenteLevaExpand(t *testing.T) {
	obs := Message{Type: "obs", Cells: []Cell{cell(5, 5, 1, 0), cell(6, 5, 0, 0)}}
	if got := Decide(obs, 1).Kind; got != "expand" {
		t.Fatalf("kind: %s", got)
	}
}

func TestE3SoInimigoFortificadoAdjacenteLevaFortify(t *testing.T) {
	// Decide fortifica uma célula de fronteira quando há inimigos mas
	// todos estão fortificados
	obs := Message{Type: "obs", Cells: []Cell{cell(5, 5, 1, 0), cell(6, 5, 2, 1)}}
	if got := Decide(obs, 1).Kind; got != "fortify" {
		t.Fatalf("kind: %s", got)
	}
}

func TestE3SemParaOndeIrLevaPass(t *testing.T) {
	obs := Message{Type: "obs", Cells: []Cell{
		cell(5, 5, 1, 0), cell(4, 5, 1, 0), cell(6, 5, 1, 0), cell(5, 4, 1, 0), cell(5, 6, 1, 0),
	}}
	if got := Decide(obs, 1).Kind; got != "pass" {
		t.Fatalf("kind: %s", got)
	}
}
