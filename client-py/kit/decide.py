"""E3: a sua estratégia. observação -> ação, pura.

É O ÚNICO ARQUIVO QUE VOCÊ PRECISA EDITAR para jogar depois do E1 e E2.
"""

from observation import attackable, border_cells, expandable

# TODO E3: implemente decide(). A observação é o que o seu parse do E1
# devolveu: {"type": "obs", "ref": _, "tick": _, "status": _,
# "scores_tick": _, "cells": cells}, onde cada célula é
# {"x", "y", "terrain", "owner", "fortified"}. my_id é o id da sua colônia
# (veio no WELCOME). Devolva uma ação:
# {"kind": "expand" | "attack" | "fortify", "x": x, "y": y} ou
# {"kind": "pass"}.
#
# Os helpers de observation.py já estão prontos e testados: own_cells,
# expandable (vazias adjacentes), attackable (inimigas adjacentes),
# border_cells (suas células na fronteira). Use-os.
#
# Dica nível 1 (sobrevivência): expanda para células vazias, nunca ataque
# célula fortificada. Dica nível 2 (expansão + defesa): fortifique
# fronteiras com inimigo ao lado, ataque inimigos desfortificados.
#
# Enquanto o stub estiver aqui a sua colônia só passa a vez.


def decide(obs, my_id):
    return {"kind": "pass"}
