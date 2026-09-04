"""Parse e encode das linhas do protocolo, na fronteira.

Regra do PROTOCOL.md: tokens extras no final são ignorados (leitor
tolerante), linha malformada vira ("error", reason) e nunca lança exceção.
Refs: <nome>-<sessão>-<n>, sessão de 4 chars gerada uma vez por processo.

Os exercícios E1 e E2 moram aqui: mexa só nas duas funções marcadas com
TODO. O resto do arquivo é infraestrutura pronta, não modifique.
"""

import random
import re
import string

# --- encode ---------------------------------------------------------------


def new_session(rng=random):
    """Gera o segmento de sessão do ref: 4 chars de [a-z0-9].

    Parâmetros:
        rng: gerador de aleatórios com .choice (o default é o módulo random).

    Devolve:
        string de 4 caracteres, gerada uma vez por processo.

    >>> len(new_session())
    4
    """
    return "".join(rng.choice(string.ascii_lowercase + string.digits) for _ in range(4))


class Refs:
    """gerador de refs estável por sessão; n cresce a cada chamada

    Parâmetros:
        name: nome da colônia, vira o primeiro segmento do ref.
        session: segmento de sessão; se None, é gerado com new_session().

    >>> refs = Refs("aurora", session="k3f9")
    >>> refs.next()
    'aurora-k3f9-1'
    >>> refs.next()
    'aurora-k3f9-2'
    """

    def __init__(self, name, session=None):
        self.name = name
        self.session = session or new_session()
        self.n = 0

    def next(self):
        """Devolve o próximo ref no formato <nome>-<sessão>-<n>."""
        self.n += 1
        return f"{self.name}-{self.session}-{self.n}"


def encode_hello(ref, role, name=None):
    """Codifica a linha HELLO, a primeira mensagem do socket.

    Parâmetros:
        ref: ref gerado por Refs.next().
        role: "colony" ou "spectator".
        name: nome da colônia (obrigatório quando role é "colony").

    Devolve:
        a linha pronta para enviar.

    >>> encode_hello("aurora-k3f9-1", "colony", "aurora")
    'HELLO v1 aurora-k3f9-1 colony aurora'
    >>> encode_hello("aurora-k3f9-2", "spectator")
    'HELLO v1 aurora-k3f9-2 spectator'
    """
    if role == "spectator":
        return f"HELLO v1 {ref} spectator"
    return f"HELLO v1 {ref} colony {name}"


# E2: ação de domínio -> linha de protocolo com ref correto.
# TODO E2: implemente. O formato é:
#   ACT <ref> <kind> <x> <y>   para expand, attack e fortify
#   ACT <ref> pass             para pass (sem coordenadas)
# A ação de domínio é {"kind": "expand" | "attack" | "fortify", "x": x, "y": y}
# ou {"kind": "pass"}.
# Enquanto o stub estiver aqui a sua colônia só passa a vez.
def encode_action(action, ref):
    return f"ACT {ref} pass"


def encode_ping(ref):
    """Codifica a linha PING.

    >>> encode_ping("r-1")
    'PING r-1'
    """
    return f"PING {ref}"


# --- parse ----------------------------------------------------------------


_INT = re.compile(r"^-?\d+$")


def _int(tok):
    # inteiros base-10; regex igual à do JS, porque int() do Python
    # aceita "+5" e espaços em volta, e isso não pode passar
    if tok is None or not _INT.match(tok):
        return None
    return int(tok)


def _tok(t, i):
    return t[i] if i < len(t) else None


def parse_cell(tok):
    """célula: x,y,terrain,owner,fortified (tokens extras na célula ignorados)

    Parâmetros:
        tok: token cru de uma célula, no formato "x,y,terrain,owner,fortified".

    Devolve:
        dict {"x", "y", "terrain", "owner", "fortified"} ou None se o
        token for malformado.

    >>> parse_cell("11,5,forest,2,0")
    {'x': 11, 'y': 5, 'terrain': 'forest', 'owner': 2, 'fortified': 0}
    >>> parse_cell("9,5,plain,0") is None
    True
    """
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


# E1: uma linha OBS crua -> observação de domínio.
# TODO E1: implemente. O formato da linha é:
#   OBS <ref> <tick> <status> <scores_tick> <celulas>
# status é "alive" ou "dead"; celulas é a lista separada por ";"
# (parse_cell e _cell_list acima já existem, use-as). Devolva:
#   ("ok", {"type": "obs", "ref": ref, "tick": tick, "status": status,
#           "scores_tick": scores_tick, "cells": cells})
# ou ("error", "motivo"). Linha malformada vira ("error", ...), nunca
# exceção. Tokens extras no final são ignorados (é o que salva o seu
# cliente no drill da v2).
def parse_observation(line):
    return ("error", "TODO E1: implemente parse_observation")


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
    """Despacha qualquer linha do servidor para o parser certo.

    Parâmetros:
        line: a linha crua que chegou do socket.

    Devolve:
        ("ok", mensagem de domínio) ou ("error", motivo). Nunca lança
        exceção: tipo desconhecido ou linha malformada viram ("error", ...).

    >>> parse_line("PONG srv-1")
    ('ok', {'type': 'pong', 'ref': 'srv-1'})
    >>> parse_line("ACTN foo bar")[0]
    'error'
    """
    t = line.split(" ")
    kind = t[0]

    if kind == "OBS":
        return parse_observation(line)

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
