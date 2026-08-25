"""Testes do parser e do encode: python3 -m unittest discover -v"""

import unittest

from protocol import Refs, encode_action, parse_cell, parse_line, parse_observation


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


class TestParseLine(unittest.TestCase):
    """demais linhas do servidor e o leitor tolerante"""

    def test_welcome_de_colonia(self):
        tag, msg = parse_line("WELCOME srv-0 3 aurora 96CDFB 60 40 1000 3 4,34")
        self.assertEqual(tag, "ok")
        self.assertEqual(msg["type"], "welcome")
        self.assertEqual(msg["role"], "colony")
        self.assertEqual(msg["id"], 3)
        self.assertEqual(msg["name"], "aurora")
        self.assertEqual(msg["color"], "96CDFB")
        self.assertEqual(
            (msg["w"], msg["h"], msg["tick_ms"], msg["view_radius"]),
            (60, 40, 1000, 3),
        )
        self.assertEqual(msg["spawn"], [4, 34])

    def test_obs_via_parse_line(self):
        tag, msg = parse_line("OBS srv-97 97 alive 97 9,5,plain,0,0;10,5,plain,3,1")
        self.assertEqual(tag, "ok")
        self.assertEqual(msg["tick"], 97)
        self.assertEqual(msg["status"], "alive")
        self.assertEqual(msg["scores_tick"], 97)
        self.assertEqual(msg["cells"], [
            {"x": 9, "y": 5, "terrain": "plain", "owner": 0, "fortified": 0},
            {"x": 10, "y": 5, "terrain": "plain", "owner": 3, "fortified": 1},
        ])

    def test_ack_com_tokens_extra_ignorados(self):
        tag, msg = parse_line("ACK aurora-k3f9-17 97 extra tokens")
        self.assertEqual(tag, "ok")
        self.assertEqual(msg, {"type": "ack", "ref": "aurora-k3f9-17", "tick": 97})

    def test_nack(self):
        tag, msg = parse_line("NACK aurora-k3f9-17 too_late tick 96 resolvido")
        self.assertEqual(tag, "ok")
        self.assertEqual(msg["code"], "too_late")
        self.assertEqual(msg["detail"], "tick 96 resolvido")

    def test_score(self):
        tag, msg = parse_line("SCORE srv-97 97 3,aurora,21,alive;5,nova,14,dead")
        self.assertEqual(tag, "ok")
        self.assertEqual(msg["entries"][1], {
            "id": 5, "name": "nova", "cells": 14, "status": "dead",
        })

    def test_linhas_malformadas_viram_erro_nunca_excecao(self):
        self.assertEqual(parse_line("ACTN foo bar")[0], "error")
        self.assertEqual(parse_line("OBS srv-97 x alive 97")[0], "error")
        self.assertEqual(
            parse_line("WELCOME srv-0 3 aurora 96CDFB 60 40 1000 3")[0], "error",
        )
        self.assertIsNone(parse_cell("9,5,plain,0"))

    def test_encode_com_refs(self):
        refs = Refs("aurora", session="k3f9")
        self.assertEqual(refs.next(), "aurora-k3f9-1")
        self.assertEqual(
            encode_action({"kind": "expand", "x": 12, "y": 7}, refs.next()),
            "ACT aurora-k3f9-2 expand 12 7",
        )
        self.assertEqual(
            encode_action({"kind": "pass"}, refs.next()), "ACT aurora-k3f9-3 pass",
        )


if __name__ == "__main__":
    unittest.main()
