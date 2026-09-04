// Política de retry pura sobre o mapa de pendentes (at-least-once).
// pending: Map ref -> {line, tick, retries}. Nada aqui toca no socket:
// onTimeout devolve o que fazer ({retry} ou {drop}) e a borda executa.
// Os mapas são tratados como imutáveis: cada função devolve um Map novo.

export const BUDGET = 3; // tentativas máximas por ref
export const TIMEOUT = 2; // ticks sem ACK antes de reenviar

// Registra uma ação enviada esperando ACK.
//   pending: Map ref -> {line, tick, retries}
//   ref: ref único da ação (ex: "mina-a1b2-3")
//   line: a linha de protocolo enviada (guardada para um possível retry)
//   tick: tick em que a ação foi enviada
// Devolve um NOVO mapa com a entrada adicionada (retries começa em 0).
// Exemplo:
//   addPending(new Map(), "r-1", "ACT r-1 expand 3 4", 10)
//   // => Map { "r-1" => { line: "ACT r-1 expand 3 4", tick: 10, retries: 0 } }
export function addPending(pending, ref, line, tick) {
  const next = new Map(pending);
  next.set(ref, { line, tick, retries: 0 });
  return next;
}

// Confirma um ref: o ACK chegou, a ação não precisa mais de retry.
//   pending: Map ref -> {line, tick, retries}
//   ref: ref confirmado pelo servidor
// Devolve um NOVO mapa sem o ref. Ref desconhecido é ignorado.
// Exemplo:
//   onAck(pending, "r-1")  // => mapa igual a pending, mas sem "r-1"
export function onAck(pending, ref) {
  const next = new Map(pending);
  next.delete(ref);
  return next;
}

// Vence os pendentes antigos no tick now. Para cada ref com
// now - tick >= timeout:
//   - se retries < budget: reenvia -> efeito { retry: ref, line },
//     retries+1 e tick atualizado para now
//   - se o budget esgotou: desiste -> efeito { drop: ref }, sai do mapa
// Refs recentes ficam intactos.
//   pending: Map ref -> {line, tick, retries}
//   now: tick atual
//   budget/timeout: limites (padrão BUDGET e TIMEOUT acima)
// Devolve [novoMapa, efeitos], na ordem de inserção dos refs.
// Exemplo:
//   const [next, effects] = onTimeout(pending, 12);
//   for (const eff of effects) {
//     if (eff.retry) conn.sendLine(eff.line); // reenvia a linha original
//     else log(`acao descartada sem ACK: ${eff.drop}`);
//   }
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
