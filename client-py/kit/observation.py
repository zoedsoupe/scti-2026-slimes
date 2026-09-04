"""Helpers puros sobre uma observação (a visão que chega a cada tick).

Nada aqui conhece socket ou rede.

Infraestrutura do kit, pronta e testada: não modifique este arquivo.
Use estes helpers na sua estratégia (E3).
"""


def cell_map(cells):
    """mapa (x, y) -> célula, para consulta O(1)

    Parâmetros:
        cells: lista de células de uma observação.

    Devolve:
        dict {(x, y): célula}.

    >>> cells = [{"x": 1, "y": 2, "terrain": "plain", "owner": 3, "fortified": 0}]
    >>> cell_map(cells)[(1, 2)]["owner"]
    3
    """
    return {(c["x"], c["y"]): c for c in cells}


def neighbors4(x, y):
    """adjacência ortogonal (a regra de bad_cell do servidor usa a mesma)

    Parâmetros:
        x, y: coordenadas da célula.

    Devolve:
        lista com as 4 posições vizinhas: direita, esquerda, baixo, cima.

    >>> neighbors4(5, 5)
    [(6, 5), (4, 5), (5, 6), (5, 4)]
    """
    return [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]


def own_cells(cells, my_id):
    """células da sua colônia dentro da observação

    Parâmetros:
        cells: lista de células de uma observação.
        my_id: o id da sua colônia (veio no WELCOME).

    Devolve:
        lista das células cujo owner é my_id.

    >>> cells = [
    ...     {"x": 1, "y": 1, "terrain": "plain", "owner": 3, "fortified": 0},
    ...     {"x": 2, "y": 1, "terrain": "plain", "owner": 0, "fortified": 0},
    ... ]
    >>> [c["x"] for c in own_cells(cells, 3)]
    [1]
    """
    return [c for c in cells if c["owner"] == my_id]


def expandable(cells, my_id):
    """células vazias adjacentes a alguma célula da colônia: alvos de expand

    Parâmetros:
        cells: lista de células de uma observação.
        my_id: o id da sua colônia.

    Devolve:
        lista das células com owner 0 que encostam na sua colônia.

    >>> cells = [
    ...     {"x": 5, "y": 5, "terrain": "plain", "owner": 1, "fortified": 0},
    ...     {"x": 6, "y": 5, "terrain": "plain", "owner": 0, "fortified": 0},
    ... ]
    >>> [(c["x"], c["y"]) for c in expandable(cells, 1)]
    [(6, 5)]
    """
    m = cell_map(cells)
    seen = {}
    for c in own_cells(cells, my_id):
        for pos in neighbors4(c["x"], c["y"]):
            n = m.get(pos)
            if n and n["owner"] == 0:
                seen.setdefault(pos, n)
    return list(seen.values())


def attackable(cells, my_id):
    """células inimigas adjacentes à colônia: alvos de attack

    Parâmetros:
        cells: lista de células de uma observação.
        my_id: o id da sua colônia.

    Devolve:
        lista das células de outro dono (owner != 0 e != my_id) que
        encostam na sua colônia.

    >>> cells = [
    ...     {"x": 5, "y": 5, "terrain": "plain", "owner": 1, "fortified": 0},
    ...     {"x": 6, "y": 5, "terrain": "plain", "owner": 2, "fortified": 0},
    ... ]
    >>> [(c["x"], c["y"]) for c in attackable(cells, 1)]
    [(6, 5)]
    """
    m = cell_map(cells)
    seen = {}
    for c in own_cells(cells, my_id):
        for pos in neighbors4(c["x"], c["y"]):
            n = m.get(pos)
            if n and n["owner"] != 0 and n["owner"] != my_id:
                seen.setdefault(pos, n)
    return list(seen.values())


def border_cells(cells, my_id):
    """células próprias com vizinho inimigo: fronteira, candidatas a fortify

    Parâmetros:
        cells: lista de células de uma observação.
        my_id: o id da sua colônia.

    Devolve:
        lista das suas células que têm pelo menos um vizinho inimigo.

    >>> cells = [
    ...     {"x": 5, "y": 5, "terrain": "plain", "owner": 1, "fortified": 0},
    ...     {"x": 6, "y": 5, "terrain": "plain", "owner": 2, "fortified": 0},
    ... ]
    >>> [(c["x"], c["y"]) for c in border_cells(cells, 1)]
    [(5, 5)]
    """
    m = cell_map(cells)
    return [
        c for c in own_cells(cells, my_id)
        if any(
            (n := m.get(pos)) and n["owner"] != 0 and n["owner"] != my_id
            for pos in neighbors4(c["x"], c["y"])
        )
    ]
