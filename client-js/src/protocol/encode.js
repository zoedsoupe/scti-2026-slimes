// Codificação de mensagens do cliente para a linha de protocolo.
// Refs: <nome>-<sessão>-<n>, sessão de 4 chars gerada uma vez por carga
// da página (assim uma página recarregada nunca colide na dedup do servidor).

const ALPHA = "abcdefghijklmnopqrstuvwxyz0123456789";

export function newSession(random = Math.random) {
  let s = "";
  for (let i = 0; i < 4; i++) s += ALPHA[Math.floor(random() * ALPHA.length)];
  return s;
}

// gerador de refs estável por sessão; n cresce a cada chamada
export function createRefs(name, session = newSession()) {
  let n = 0;
  return { session, next: () => `${name}-${session}-${++n}` };
}

// E2: ação de domínio -> linha de protocolo com ref correto
export function encodeAction(action, ref) {
  if (action.kind === "pass") return `ACT ${ref} pass`;
  return `ACT ${ref} ${action.kind} ${action.x} ${action.y}`;
}

export const encodeHello = (ref, role, name) =>
  role === "spectator" ? `HELLO v1 ${ref} spectator` : `HELLO v1 ${ref} colony ${name}`;

export const encodePing = (ref) => `PING ${ref}`;
