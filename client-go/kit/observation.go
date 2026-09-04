package main

// Helpers puros sobre uma observação (a visão que chega a cada tick).
// Nada aqui conhece socket ou rede.
//
// INFRA: não edite este arquivo. Use estes helpers na sua estratégia (E3).

type pos [2]int

// mapa (x, y) -> célula, para consulta O(1)
func cellMap(cells []Cell) map[pos]Cell {
	m := make(map[pos]Cell, len(cells))
	for _, c := range cells {
		m[pos{c.X, c.Y}] = c
	}
	return m
}

// adjacência ortogonal (a regra de bad_cell do servidor usa a mesma)
func neighbors4(x, y int) []pos {
	return []pos{{x + 1, y}, {x - 1, y}, {x, y + 1}, {x, y - 1}}
}

func ownCells(cells []Cell, id int) []Cell {
	var out []Cell
	for _, c := range cells {
		if c.Owner == id {
			out = append(out, c)
		}
	}
	return out
}

// Expandable lista as células vazias (Owner == 0) adjacentes a alguma
// célula da colônia: os alvos válidos de expand.
//
// Parâmetros:
//   - cells: células visíveis da observação
//   - id: id da sua colônia
//
// Devolve as células alvo, sem repetição.
//
// Exemplo:
//
//	targets := Expandable(obs.Cells, myID)
//	if len(targets) > 0 {
//		action = Action{Kind: "expand", X: targets[0].X, Y: targets[0].Y}
//	}
func Expandable(cells []Cell, id int) []Cell {
	m := cellMap(cells)
	seen := map[pos]bool{}
	var out []Cell
	for _, c := range ownCells(cells, id) {
		for _, p := range neighbors4(c.X, c.Y) {
			n, ok := m[p]
			if ok && n.Owner == 0 && !seen[p] {
				seen[p] = true
				out = append(out, n)
			}
		}
	}
	return out
}

// Attackable lista as células inimigas adjacentes a alguma célula da
// colônia: os alvos válidos de attack.
//
// Parâmetros:
//   - cells: células visíveis da observação
//   - id: id da sua colônia
//
// Devolve as células alvo, sem repetição. Células com Fortified > 0
// resistem ao ataque; cheque o campo antes de atacar.
//
// Exemplo:
//
//	for _, c := range Attackable(obs.Cells, myID) {
//		if c.Fortified == 0 {
//			return Action{Kind: "attack", X: c.X, Y: c.Y}
//		}
//	}
func Attackable(cells []Cell, id int) []Cell {
	m := cellMap(cells)
	seen := map[pos]bool{}
	var out []Cell
	for _, c := range ownCells(cells, id) {
		for _, p := range neighbors4(c.X, c.Y) {
			n, ok := m[p]
			if ok && n.Owner != 0 && n.Owner != id && !seen[p] {
				seen[p] = true
				out = append(out, n)
			}
		}
	}
	return out
}

// BorderCells lista as células da colônia que têm pelo menos um vizinho
// inimigo: a fronteira, candidatas a fortify.
//
// Parâmetros:
//   - cells: células visíveis da observação
//   - id: id da sua colônia
//
// Devolve as células próprias na fronteira.
//
// Exemplo:
//
//	for _, c := range BorderCells(obs.Cells, myID) {
//		if c.Fortified == 0 {
//			return Action{Kind: "fortify", X: c.X, Y: c.Y}
//		}
//	}
func BorderCells(cells []Cell, id int) []Cell {
	m := cellMap(cells)
	var out []Cell
	for _, c := range ownCells(cells, id) {
		for _, p := range neighbors4(c.X, c.Y) {
			if n, ok := m[p]; ok && n.Owner != 0 && n.Owner != id {
				out = append(out, c)
				break
			}
		}
	}
	return out
}
