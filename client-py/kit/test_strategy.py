"""E3: classe da ação esperada para observações fixas (não a célula exata).

python3 -m unittest discover -v
"""

import unittest

from decide import decide


def cell(x, y, owner, fortified=0):
    return {"x": x, "y": y, "terrain": "plain", "owner": owner, "fortified": fortified}


class TestDecide(unittest.TestCase):
    def test_e3_inimigo_desfortificado_adjacente_leva_attack(self):
        obs = {"cells": [cell(5, 5, 1), cell(6, 5, 2, 0)]}
        self.assertEqual(decide(obs, 1)["kind"], "attack")

    def test_e3_sem_inimigos_e_com_vazia_adjacente_leva_expand(self):
        obs = {"cells": [cell(5, 5, 1), cell(6, 5, 0)]}
        self.assertEqual(decide(obs, 1)["kind"], "expand")

    def test_e3_so_inimigo_fortificado_adjacente_leva_fortify(self):
        # decide() fortifica uma célula de fronteira quando há inimigos mas
        # todos estão fortificados
        obs = {"cells": [cell(5, 5, 1), cell(6, 5, 2, 1)]}
        self.assertEqual(decide(obs, 1)["kind"], "fortify")

    def test_e3_sem_para_onde_ir_leva_pass(self):
        obs = {"cells": [
            cell(5, 5, 1), cell(4, 5, 1), cell(6, 5, 1), cell(5, 4, 1), cell(5, 6, 1),
        ]}
        self.assertEqual(decide(obs, 1)["kind"], "pass")


if __name__ == "__main__":
    unittest.main()
