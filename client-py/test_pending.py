"""E4: política de retry pura sobre o mapa de pendentes (at-least-once +
idempotência). ack remove; timeout dentro do orçamento reenvia; no limite
do orçamento descarta.

python3 -m unittest discover -v
"""

import unittest

from pending import BUDGET, TIMEOUT, add_pending, on_ack, on_timeout


class TestPending(unittest.TestCase):
    def test_e4_ack_remove_o_ref_dos_pendentes(self):
        pending = add_pending({}, "r-1", "ACT r-1 pass", 10)
        pending = on_ack(pending, "r-1")
        self.assertNotIn("r-1", pending)

    def test_e4_timeout_dentro_do_orcamento_gera_retry(self):
        pending = add_pending({}, "r-1", "ACT r-1 expand 3 4", 10)
        nxt, effects = on_timeout(pending, 10 + TIMEOUT)
        self.assertEqual(effects, [{"retry": "r-1", "line": "ACT r-1 expand 3 4"}])
        self.assertEqual(nxt["r-1"]["retries"], 1)

    def test_e4_timeout_no_limite_do_orcamento_descarta(self):
        pending = add_pending({}, "r-1", "ACT r-1 pass", 0)
        # estoura o orçamento: BUDGET retries, o timeout seguinte derruba
        for i in range(BUDGET):
            nxt, effects = on_timeout(pending, (i + 1) * TIMEOUT)
            self.assertEqual(len(effects), 1, f"timeout {i} devia gerar retry")
            self.assertIn("retry", effects[0], f"timeout {i} devia ser retry")
            pending = nxt
        nxt, effects = on_timeout(pending, (BUDGET + 1) * TIMEOUT)
        self.assertEqual(effects, [{"drop": "r-1"}])
        self.assertNotIn("r-1", nxt)

    def test_e4_ref_recente_nao_vence(self):
        pending = add_pending({}, "r-1", "ACT r-1 pass", 10)
        nxt, effects = on_timeout(pending, 10 + TIMEOUT - 1)
        self.assertEqual(effects, [])
        self.assertEqual(nxt["r-1"]["retries"], 0)


if __name__ == "__main__":
    unittest.main()
