// Codificação de mensagens do cliente para a linha de protocolo.
// Refs: <nome>-<sessão>-<n>, sessão de 4 chars gerada uma vez por carga
// da página (assim uma página recarregada nunca colide na dedup do servidor).

const ALPHA = "abcdefghijklmnopqrstuvwxyz0123456789";

// newSession(random): sorteia o segmento de sessão do ref, 4 chars de
// [a-z0-9]. Chamada uma vez por carga da página; uma página recarregada
// nunca colide na dedup do servidor.
//   random: fonte de aleatoriedade (padrão Math.random)
// Devolve uma string de 4 chars.
// Exemplo: newSession()  // => "a1b2" (aleatório)
export function newSession(random = Math.random) {
  let s = "";
  for (let i = 0; i < 4; i++) s += ALPHA[Math.floor(random() * ALPHA.length)];
  return s;
}

// createRefs(name, session): gerador de refs estável por sessão, no
// formato <nome>-<sessão>-<n>, com n crescendo a cada chamada.
//   name: nome da colônia (o mesmo enviado no HELLO)
//   session: segmento de sessão (padrão: sorteado por newSession())
// Devolve { session, next() }, onde next() devolve o próximo ref.
// Exemplo:
//   const refs = createRefs("mina", "a1b2");
//   refs.next();  // => "mina-a1b2-1"
//   refs.next();  // => "mina-a1b2-2"
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

// encodeHello(ref, role, name): primeira linha enviada no socket.
//   ref: ref da mensagem (de createRefs)
//   role: "colony" para jogar, "spectator" para só assistir
//   name: nome da colônia (obrigatório para colony, [a-z0-9-]{1,16})
// Devolve a linha de protocolo.
// Exemplos:
//   encodeHello("r-1", "colony", "mina")  // => "HELLO v1 r-1 colony mina"
//   encodeHello("r-1", "spectator")       // => "HELLO v1 r-1 spectator"
export const encodeHello = (ref, role, name) =>
  role === "spectator" ? `HELLO v1 ${ref} spectator` : `HELLO v1 ${ref} colony ${name}`;

// encodePing(ref): keepalive do protocolo.
//   ref: ref da mensagem
// Devolve a linha "PING <ref>". O servidor responde com PONG.
// Exemplo: encodePing("r-9")  // => "PING r-9"
export const encodePing = (ref) => `PING ${ref}`;
