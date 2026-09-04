// Política de retry pura sobre o mapa de pendentes.
// pending: Map ref -> {line, tick, retries}. Nada aqui toca no socket:
// on_timeout devolve o que fazer ({retry} ou {drop}) e a borda executa.

export const BUDGET = 3; // tentativas máximas por ref
export const TIMEOUT = 2; // ticks sem ACK antes de reenviar

export function addPending(pending, ref, line, tick) {
  const next = new Map(pending);
  next.set(ref, { line, tick, retries: 0 });
  return next;
}

export function onAck(pending, ref) {
  const next = new Map(pending);
  next.delete(ref);
  return next;
}

// refs vencidos: retry enquanto couber no orçamento, drop no limite.
// O mapa devolvido já reflete retries incrementados e drops removidos.
export function onTimeout(pending, now, budget = BUDGET, timeout = TIMEOUT) {
  const effects = [];
  const next = new Map();
  for (const [ref, entry] of pending) {
    if (now - entry.tick < timeout) {
      next.set(ref, entry);
    } else if (entry.retries < budget) {
      const retried = { ...entry, tick: now, retries: entry.retries + 1 };
      next.set(ref, retried);
      effects.push({ retry: ref, line: entry.line });
    } else {
      effects.push({ drop: ref });
    }
  }
  return [next, effects];
}
