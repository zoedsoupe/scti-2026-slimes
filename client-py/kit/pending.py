"""Política de retry pura sobre o mapa de pendentes.

pending: dict ref -> {"line", "tick", "retries"}. Nada aqui toca no socket:
on_timeout devolve o que fazer (retry ou drop) e a borda executa.

Infraestrutura do kit, pronta e testada: não modifique este arquivo.
"""

BUDGET = 3  # tentativas máximas por ref
TIMEOUT = 2  # ticks sem ACK antes de reenviar


def add_pending(pending, ref, line, tick):
    """Registra uma linha enviada que ainda espera ACK.

    Parâmetros:
        pending: o mapa atual de pendentes (não é mutado).
        ref: o ref da linha enviada.
        line: a linha crua enviada, guardada para um eventual retry.
        tick: o tick em que a linha foi enviada.

    Devolve:
        um novo mapa com o ref registrado e retries zerado.

    >>> p = add_pending({}, "r-1", "ACT r-1 pass", 10)
    >>> p["r-1"]
    {'line': 'ACT r-1 pass', 'tick': 10, 'retries': 0}
    """
    return {**pending, ref: {"line": line, "tick": tick, "retries": 0}}


def on_ack(pending, ref):
    """Confirma um ref: o ACK chegou, o pendente some do mapa.

    Parâmetros:
        pending: o mapa atual de pendentes (não é mutado).
        ref: o ref confirmado pelo servidor.

    Devolve:
        um novo mapa sem o ref confirmado.

    >>> p = add_pending({}, "r-1", "ACT r-1 pass", 10)
    >>> on_ack(p, "r-1")
    {}
    """
    return {k: v for k, v in pending.items() if k != ref}


def on_timeout(pending, now, budget=BUDGET, timeout=TIMEOUT):
    """refs vencidos: retry enquanto couber no orçamento, drop no limite.

    Para cada ref com now - tick >= timeout:
      - se retries < budget: gera o efeito {"retry": ref, "line": line},
        soma 1 em retries e atualiza o tick para now
      - se retries esgotou o budget: gera o efeito {"drop": ref} e o ref
        some do mapa
    Refs recentes ficam intactos.

    Parâmetros:
        pending: o mapa atual de pendentes (não é mutado).
        now: o tick atual.
        budget: tentativas máximas por ref (default BUDGET).
        timeout: ticks sem ACK antes de reenviar (default TIMEOUT).

    Devolve:
        (novo_mapa, efeitos); a borda reenvia as linhas dos efeitos
        de retry e esquece os refs de drop.

    >>> p = add_pending({}, "r-1", "ACT r-1 expand 3 4", 10)
    >>> nxt, effects = on_timeout(p, 12)
    >>> effects
    [{'retry': 'r-1', 'line': 'ACT r-1 expand 3 4'}]
    >>> nxt["r-1"]["retries"]
    1
    """
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
