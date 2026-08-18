"""Helpers puros sobre uma observação (a visão que chega a cada tick).

Nada aqui conhece socket ou rede.
"""


def cell_map(cells):
    """mapa (x, y) -> célula, para consulta O(1)"""
    return {(c["x"], c["y"]): c for c in cells}


def neighbors4(x, y):
    """adjacência ortogonal (a regra de bad_cell do servidor usa a mesma)"""
    return [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]


def own_cells(cells, my_id):
    return [c for c in cells if c["owner"] == my_id]


def expandable(cells, my_id):
    """células vazias adjacentes a alguma célula da colônia: alvos de expand"""
    m = cell_map(cells)
    seen = {}
    for c in own_cells(cells, my_id):
        for pos in neighbors4(c["x"], c["y"]):
            n = m.get(pos)
            if n and n["owner"] == 0:
                seen.setdefault(pos, n)
    return list(seen.values())


def attackable(cells, my_id):
    """células inimigas adjacentes à colônia: alvos de attack"""
    m = cell_map(cells)
    seen = {}
    for c in own_cells(cells, my_id):
        for pos in neighbors4(c["x"], c["y"]):
            n = m.get(pos)
            if n and n["owner"] != 0 and n["owner"] != my_id:
                seen.setdefault(pos, n)
    return list(seen.values())


def border_cells(cells, my_id):
    """células próprias com vizinho inimigo: fronteira, candidatas a fortify"""
    m = cell_map(cells)
    return [
        c for c in own_cells(cells, my_id)
        if any(
            (n := m.get(pos)) and n["owner"] != 0 and n["owner"] != my_id
            for pos in neighbors4(c["x"], c["y"])
        )
    ]
