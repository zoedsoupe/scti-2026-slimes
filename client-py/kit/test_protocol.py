"""E1/E2: parse das linhas do servidor e codificação das linhas do cliente.

python3 -m unittest discover -v
"""

import unittest

from protocol import Refs, encode_action, parse_cell, parse_observation


class TestParseObservation(unittest.TestCase):
    """E1: uma linha OBS crua vira observação de domínio, resultado tagueado."""

    def test_e1_linha_obs_valida_vira_observacao_de_dominio(self):
        tag, obs = parse_observation("OBS srv-97 97 alive 97 9,5,plain,0,0;10,5,plain,3,1")
        self.assertEqual(tag, "ok")
        self.assertEqual(obs["tick"], 97)
        self.assertEqual(obs["status"], "alive")
        self.assertEqual(obs["scores_tick"], 97)
        self.assertEqual(len(obs["cells"]), 2)
        self.assertEqual(obs["cells"][1], {
            "x": 10, "y": 5, "terrain": "plain", "owner": 3, "fortified": 1,
        })

    def test_e1_token_extra_no_final_e_ignorado(self):
        tag, obs = parse_observation("OBS srv-1 1 alive 1 1,2,plain,0,0 lixo")
        self.assertEqual(tag, "ok")
        self.assertEqual(len(obs["cells"]), 1)

    def test_e1_obs_sem_tick_e_erro(self):
        tag, _ = parse_observation("OBS srv-1 alive 1")
        self.assertEqual(tag, "error")

    def test_e1_tag_diferente_de_obs_e_erro(self):
        tag, _ = parse_observation("WELCOME srv-0 3 aurora 96CDFB 60 40 1000 3 4,34")
        self.assertEqual(tag, "error")

    def test_e1_celula_forest_com_dono_expoe_terreno_e_owner(self):
        c = parse_cell("11,5,forest,2,0")
        self.assertEqual(c["terrain"], "forest")
        self.assertEqual(c["owner"], 2)


class TestEncode(unittest.TestCase):
    """E2: codificação das linhas do cliente."""

    def test_e2_encode_action_cobre_os_quatro_kinds(self):
        self.assertEqual(
            encode_action({"kind": "expand", "x": 1, "y": 2}, "r-1"),
            "ACT r-1 expand 1 2",
        )
        self.assertEqual(
            encode_action({"kind": "attack", "x": 3, "y": 4}, "r-2"),
            "ACT r-2 attack 3 4",
        )
        self.assertEqual(
            encode_action({"kind": "fortify", "x": 5, "y": 6}, "r-3"),
            "ACT r-3 fortify 5 6",
        )
        self.assertEqual(encode_action({"kind": "pass"}, "r-4"), "ACT r-4 pass")

    def test_e2_pass_omite_coordenadas(self):
        line = encode_action({"kind": "pass"}, "r-9")
        self.assertNotIn(",", line)
        self.assertEqual(len(line.split(" ")), 3)

    def test_e2_refs_mantem_o_segmento_de_sessao_e_incrementam_n(self):
        refs = Refs("aurora", session="k3f9")
        self.assertEqual(refs.next(), "aurora-k3f9-1")
        self.assertEqual(refs.next(), "aurora-k3f9-2")
        self.assertEqual(refs.session, "k3f9")


if __name__ == "__main__":
    unittest.main()
