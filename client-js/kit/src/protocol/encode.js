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

// E2: ação de domínio -> linha de protocolo com ref correto.
// TODO E2: implemente. O formato é:
//   ACT <ref> <kind> <x> <y>   para expand, attack e fortify
//   ACT <ref> pass             para pass (sem coordenadas)
// A ação de domínio é { kind: "expand" | "attack" | "fortify", x, y }
// ou { kind: "pass" }.
// Enquanto o stub estiver aqui a sua colônia só passa a vez.
export function encodeAction(action, ref) {
  return `ACT ${ref} pass`;
}

export const encodeHello = (ref, role, name) =>
  role === "spectator" ? `HELLO v1 ${ref} spectator` : `HELLO v1 ${ref} colony ${name}`;

export const encodePing = (ref) => `PING ${ref}`;
