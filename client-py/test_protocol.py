"""Self-check do parser e do encode: python test_protocol.py"""

from protocol import Refs, encode_action, parse_cell, parse_line


def check():
    tag, msg = parse_line("WELCOME srv-0 3 aurora 96CDFB 60 40 1000 3 4,34")
    assert tag == "ok"
    assert msg["type"] == "welcome" and msg["role"] == "colony"
    assert msg["id"] == 3 and msg["name"] == "aurora" and msg["color"] == "96CDFB"
    assert (msg["w"], msg["h"], msg["tick_ms"], msg["view_radius"]) == (60, 40, 1000, 3)
    assert msg["spawn"] == [4, 34]

    tag, msg = parse_line("OBS srv-97 97 alive 97 9,5,plain,0,0;10,5,plain,3,1")
    assert tag == "ok"
    assert msg["tick"] == 97 and msg["status"] == "alive" and msg["scores_tick"] == 97
    assert msg["cells"] == [
        {"x": 9, "y": 5, "terrain": "plain", "owner": 0, "fortified": 0},
        {"x": 10, "y": 5, "terrain": "plain", "owner": 3, "fortified": 1},
    ]

    # leitor tolerante: tokens extras no final ignorados
    tag, msg = parse_line("ACK aurora-k3f9-17 97 extra tokens")
    assert tag == "ok" and msg == {"type": "ack", "ref": "aurora-k3f9-17", "tick": 97}

    tag, msg = parse_line("NACK aurora-k3f9-17 too_late tick 96 resolvido")
    assert tag == "ok" and msg["code"] == "too_late" and msg["detail"] == "tick 96 resolvido"

    tag, msg = parse_line("SCORE srv-97 97 3,aurora,21,alive;5,nova,14,dead")
    assert tag == "ok" and msg["entries"][1] == {
        "id": 5, "name": "nova", "cells": 14, "status": "dead",
    }

    # linhas malformadas viram ("error", ...), nunca exceção
    assert parse_line("ACTN foo bar")[0] == "error"
    assert parse_line("OBS srv-97 x alive 97")[0] == "error"
    assert parse_line("WELCOME srv-0 3 aurora 96CDFB 60 40 1000 3")[0] == "error"
    assert parse_cell("9,5,plain,0") is None

    refs = Refs("aurora", session="k3f9")
    assert refs.next() == "aurora-k3f9-1"
    assert encode_action({"kind": "expand", "x": 12, "y": 7}, refs.next()) == \
        "ACT aurora-k3f9-2 expand 12 7"
    assert encode_action({"kind": "pass"}, refs.next()) == "ACT aurora-k3f9-3 pass"

    print("ok: parser e encode passam no self-check")


if __name__ == "__main__":
    check()
