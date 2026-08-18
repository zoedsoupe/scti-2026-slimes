"""Parse e encode das linhas do protocolo, na fronteira.

Regra do PROTOCOL.md: tokens extras no final são ignorados (leitor
tolerante), linha malformada vira ("error", reason) e nunca lança exceção.
Refs: <nome>-<sessão>-<n>, sessão de 4 chars gerada uma vez por processo.
"""

import random
import string

# --- encode ---------------------------------------------------------------


def new_session(rng=random):
    return "".join(rng.choice(string.ascii_lowercase + string.digits) for _ in range(4))


class Refs:
    """gerador de refs estável por sessão; n cresce a cada chamada"""

    def __init__(self, name, session=None):
        self.name = name
        self.session = session or new_session()
        self.n = 0

    def next(self):
        self.n += 1
        return f"{self.name}-{self.session}-{self.n}"


def encode_hello(ref, role, name=None):
    if role == "spectator":
        return f"HELLO v1 {ref} spectator"
    return f"HELLO v1 {ref} colony {name}"


def encode_action(action, ref):
    if action["kind"] == "pass":
        return f"ACT {ref} pass"
    return f"ACT {ref} {action['kind']} {action['x']} {action['y']}"


def encode_ping(ref):
    return f"PING {ref}"


# --- parse ----------------------------------------------------------------


def _int(tok):
    # inteiros base-10; qualquer outra coisa torna a linha malformada
    try:
        return int(tok)
    except (TypeError, ValueError):
        return None


def _tok(t, i):
    return t[i] if i < len(t) else None


def parse_cell(tok):
    """célula: x,y,terrain,owner,fortified (tokens extras na célula ignorados)"""
    f = tok.split(",")
    if len(f) < 5:
        return None
    x, y, owner, fortified = _int(f[0]), _int(f[1]), _int(f[3]), _int(f[4])
    if None in (x, y, owner, fortified):
        return None
    return {"x": x, "y": y, "terrain": f[2], "owner": owner, "fortified": fortified}


def _cell_list(tok):
    if not tok:
        return []
    cells = [parse_cell(c) for c in tok.split(";")]
    return None if None in cells else cells


def _parse_observation(t):
    tick, scores_tick = _int(_tok(t, 2)), _int(_tok(t, 4))
    if tick is None or scores_tick is None:
        return ("error", "tick ausente ou invalido")
    status = _tok(t, 3)
    if status not in ("alive", "dead"):
        return ("error", f"status invalido {status}")
    cells = _cell_list(_tok(t, 5))
    if cells is None:
        return ("error", "lista de celulas malformada")
    return ("ok", {
        "type": "obs", "ref": _tok(t, 1), "tick": tick,
        "status": status, "scores_tick": scores_tick, "cells": cells,
    })


def _parse_welcome(t):
    if _tok(t, 2) == "spectator":
        w, h, tick_ms = _int(_tok(t, 3)), _int(_tok(t, 4)), _int(_tok(t, 5))
        if None in (w, h, tick_ms):
            return ("error", "welcome de espectador malformado")
        cells = _cell_list(_tok(t, 6))
        if cells is None:
            return ("error", "snapshot malformado")
        return ("ok", {
            "type": "welcome", "role": "spectator",
            "w": w, "h": h, "tick_ms": tick_ms, "cells": cells,
        })
    id_, w, h = _int(_tok(t, 2)), _int(_tok(t, 5)), _int(_tok(t, 6))
    tick_ms, view_radius = _int(_tok(t, 7)), _int(_tok(t, 8))
    if None in (id_, w, h, tick_ms, view_radius):
        return ("error", "welcome malformado")
    spawn = [_int(p) for p in (_tok(t, 9) or "").split(",")]
    if len(spawn) < 2 or None in spawn:
        return ("error", "spawn malformado")
    return ("ok", {
        "type": "welcome", "role": "colony", "id": id_, "name": _tok(t, 3),
        "color": _tok(t, 4), "w": w, "h": h, "tick_ms": tick_ms,
        "view_radius": view_radius, "spawn": spawn,
    })


def _parse_score(t):
    tick = _int(_tok(t, 2))
    if tick is None:
        return ("error", "score sem tick")
    entries = []
    for e in (_tok(t, 3) or "").split(";"):
        if not e:
            continue
        f = e.split(",")
        id_, cells = _int(_tok(f, 0)), _int(_tok(f, 2))
        if id_ is None or cells is None:
            return ("error", "score malformado")
        entries.append({
            "id": id_, "name": _tok(f, 1), "cells": cells, "status": _tok(f, 3),
        })
    return ("ok", {"type": "score", "ref": _tok(t, 1), "tick": tick, "entries": entries})


def _parse_diff(t):
    tick = _int(_tok(t, 2))
    if tick is None:
        return ("error", "diff sem tick")
    changes = []
    for c in (_tok(t, 3) or "").split(";"):
        if not c:
            continue
        f = c.split(",")
        x, y = _int(_tok(f, 0)), _int(_tok(f, 1))
        owner, fortified = _int(_tok(f, 2)), _int(_tok(f, 3))
        if None in (x, y, owner, fortified):
            return ("error", "diff malformado")
        changes.append({"x": x, "y": y, "owner": owner, "fortified": fortified})
    return ("ok", {"type": "diff", "ref": _tok(t, 1), "tick": tick, "changes": changes})


def parse_line(line):
    t = line.split(" ")
    kind = t[0]

    if kind == "OBS":
        return _parse_observation(t)

    if kind == "WELCOME":
        return _parse_welcome(t)

    if kind == "ACK":
        tick = _int(_tok(t, 2))
        if tick is None:
            return ("error", "ack sem tick")
        return ("ok", {"type": "ack", "ref": _tok(t, 1), "tick": tick})

    if kind == "NACK":
        return ("ok", {
            "type": "nack", "ref": _tok(t, 1),
            "code": _tok(t, 2), "detail": " ".join(t[3:]),
        })

    if kind == "ERR":
        return ("ok", {
            "type": "err", "ref": _tok(t, 1),
            "code": _tok(t, 2), "detail": " ".join(t[3:]),
        })

    if kind == "SCORE":
        return _parse_score(t)

    if kind == "DIFF":
        return _parse_diff(t)

    if kind == "PONG":
        return ("ok", {"type": "pong", "ref": _tok(t, 1)})

    return ("error", f"tipo desconhecido {kind}")
