package main

// Helpers puros sobre uma observação (a visão que chega a cada tick).
// Nada aqui conhece socket ou rede.

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

// células vazias adjacentes a alguma célula da colônia: alvos de expand
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

// células inimigas adjacentes à colônia: alvos de attack
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

// células próprias com vizinho inimigo: fronteira, candidatas a fortify
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
