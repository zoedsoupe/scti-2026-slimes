"""Política de retry pura sobre o mapa de pendentes.

pending: dict ref -> {"line", "tick", "retries"}. Nada aqui toca no socket:
on_timeout devolve o que fazer (retry ou drop) e a borda executa.
"""

BUDGET = 3  # tentativas máximas por ref
TIMEOUT = 2  # ticks sem ACK antes de reenviar


def add_pending(pending, ref, line, tick):
    return {**pending, ref: {"line": line, "tick": tick, "retries": 0}}


def on_ack(pending, ref):
    return {k: v for k, v in pending.items() if k != ref}


def on_timeout(pending, now, budget=BUDGET, timeout=TIMEOUT):
    """refs vencidos: retry enquanto couber no orçamento, drop no limite."""
    effects = []
    nxt = {}
    for ref, entry in pending.items():
        if now - entry["tick"] < timeout:
            nxt[ref] = entry
        elif entry["retries"] < budget:
            nxt[ref] = {**entry, "tick": now, "retries": entry["retries"] + 1}
            effects.append({"retry": ref, "line": entry["line"]})
        else:
            effects.append({"drop": ref})
    return nxt, effects
