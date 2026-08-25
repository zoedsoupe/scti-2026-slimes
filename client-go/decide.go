package main

// Estratégia de referência. observação -> ação, pura.
// Prioridade: ataca inimigo desfortificado adjacente; fortifica fronteira
// sob ameaça; expande na direção do inimigo mais próximo; senão passa.
//
// É O ÚNICO ARQUIVO QUE VOCÊ PRECISA EDITAR para jogar.

import "sort"

func Decide(obs Message, myID int) Action {
	enemies := Attackable(obs.Cells, myID)
	for _, c := range enemies {
		if c.Fortified == 0 {
			return Action{Kind: "attack", X: c.X, Y: c.Y}
		}
	}

	if len(enemies) > 0 {
		for _, c := range BorderCells(obs.Cells, myID) {
			if c.Fortified == 0 {
				return Action{Kind: "fortify", X: c.X, Y: c.Y}
			}
		}
	}

	targets := Expandable(obs.Cells, myID)
	if len(targets) > 0 {
		sort.SliceStable(targets, func(i, j int) bool {
			return dist(targets[i], first(enemies)) < dist(targets[j], first(enemies))
		})
		return Action{Kind: "expand", X: targets[0].X, Y: targets[0].Y}
	}

	return Action{Kind: "pass"}
}

func first(cells []Cell) *Cell {
	if len(cells) == 0 {
		return nil
	}
	return &cells[0]
}

func dist(a Cell, b *Cell) int {
	if b == nil {
		return 0
	}
	return abs(a.X-b.X) + abs(a.Y-b.Y)
}

func abs(n int) int {
	if n < 0 {
		return -n
	}
	return n
}
