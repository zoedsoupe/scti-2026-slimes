"""Estratégia de referência. observação -> ação, pura.

Prioridade: ataca inimigo desfortificado adjacente; fortifica fronteira
sob ameaça; expande na direção do inimigo mais próximo; senão passa.

É O ÚNICO ARQUIVO QUE VOCÊ PRECISA EDITAR para jogar.
"""

from observation import attackable, border_cells, expandable


def decide(obs, my_id):
    enemies = attackable(obs["cells"], my_id)
    weak = [c for c in enemies if c["fortified"] == 0]
    if weak:
        return {"kind": "attack", "x": weak[0]["x"], "y": weak[0]["y"]}

    border = [c for c in border_cells(obs["cells"], my_id) if c["fortified"] == 0]
    if border and enemies:
        return {"kind": "fortify", "x": border[0]["x"], "y": border[0]["y"]}

    targets = expandable(obs["cells"], my_id)
    if targets:
        # expande na direção do inimigo mais próximo, se houver; senão qualquer uma
        targets.sort(key=lambda c: _dist(c, enemies[0] if enemies else None))
        return {"kind": "expand", "x": targets[0]["x"], "y": targets[0]["y"]}

    return {"kind": "pass"}


def _dist(a, b):
    if b is None:
        return 0
    return abs(a["x"] - b["x"]) + abs(a["y"] - b["y"])
