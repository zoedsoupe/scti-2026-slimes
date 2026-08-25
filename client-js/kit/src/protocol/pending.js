// E4: política de retry pura sobre o mapa de pendentes.
// pending: Map ref -> {line, tick, retries}. Nada aqui toca no socket:
// on_timeout devolve o que fazer ({retry} ou {drop}) e a borda executa.

export const BUDGET = 3; // tentativas máximas por ref
export const TIMEOUT = 2; // ticks sem ACK antes de reenviar

export function addPending(pending, ref, line, tick) {
  const next = new Map(pending);
  next.set(ref, { line, tick, retries: 0 });
  return next;
}

// TODO E4: o ACK chegou. Devolva um NOVO mapa sem o ref confirmado.
// (Mapas são tratados como imutáveis aqui: copie, não mute o original.)
// Enquanto o stub estiver aqui os pendentes nunca são confirmados.
export function onAck(pending, ref) {
  return pending;
}

// TODO E4: vence os pendentes antigos. Para cada ref com now - tick >= TIMEOUT:
//   - se retries < budget: reenvia -> efeito { retry: ref, line }, retries+1,
//     tick atualizado para now
//   - se retries esgotou o budget: desiste -> efeito { drop: ref }, some do mapa
// Refs recentes ficam intactos. Devolva [novoMapa, efeitos].
// Enquanto o stub estiver aqui nenhuma ação é reenviada nem descartada.
export function onTimeout(pending, now, budget = BUDGET, timeout = TIMEOUT) {
  return [pending, []];
}
