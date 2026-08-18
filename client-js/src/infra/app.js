// Ponto de entrada do cliente de referência.
//
// O pipeline do minicurso, verbatim:
//
//   socket message |> protocol.parse() (PURO) |> strategy.decide() (PURO)
//                  |> protocol.encode() (PURO) |> infra.send() (EFEITO)
//
// Este arquivo é a casca imperativa: toca no DOM, no socket e no tempo.
// Toda decisão de domínio mora nos módulos puros de protocol/world/strategy.

import { parseLine } from "../protocol/parse.js";
import { createRefs, encodeHello, encodeAction } from "../protocol/encode.js";
import { addPending, onAck, onTimeout } from "../protocol/pending.js";
import { key } from "../world/observation.js";
import { decide } from "../strategy/decide.js";
import { connect } from "./transport.js";
import { createRenderer } from "./render.js";

// --- estado local (única fonte mutável da casca) ---

const state = {
  conn: null, // {sendLine, close} do transport
  refs: null, // gerador de refs da sessão
  myId: 0,
  w: 0,
  h: 0,
  knownCells: new Map(), // "x,y" -> célula; persiste entre ticks
  scores: [],
  tick: 0,
  pending: new Map(), // ref -> {line, tick, retries}
};

// --- elementos da página ---

const els = {
  name: document.getElementById("name"),
  server: document.getElementById("server"),
  button: document.getElementById("connect"),
  status: document.getElementById("status"),
  log: document.getElementById("log"),
};

const renderer = createRenderer(
  document.getElementById("grid"),
  document.getElementById("scoreboard"),
);

// --- efeitos de saída ---

function setStatus(text, cls) {
  els.status.textContent = text;
  els.status.className = cls || "";
}

function statusText(base) {
  return state.tick > 0 ? `${base}, tick ${state.tick}` : base;
}

function logLine(text) {
  const p = document.createElement("div");
  p.textContent = text;
  els.log.prepend(p);
}

function paint() {
  renderer.render({
    w: state.w,
    h: state.h,
    knownCells: state.knownCells,
    scores: state.scores,
    myId: state.myId,
  });
}

// --- ciclo de vida da conexão ---

function start() {
  const name = els.name.value.trim();
  const url = els.server.value.trim();
  if (!/^[a-z0-9-]{1,16}$/.test(name)) {
    logLine("nome inválido: use [a-z0-9-]{1,16}");
    return;
  }
  setStatus("conectando...", "conectando");
  state.refs = createRefs(name);
  const conn = connect(url, {
    onLine: handleLine,
    onOpen: () => onOpen(conn),
    onClose: () => onClose(conn),
  });
  state.conn = conn;
}

function onOpen(conn) {
  if (state.conn !== conn) return;
  // HELLO é a primeira mensagem do socket, enviada uma vez
  conn.sendLine(encodeHello(state.refs.next(), "colony", els.name.value.trim()));
  setStatus(statusText("conectado"), "conectado");
}

function onClose(conn) {
  if (state.conn !== conn) return; // fecho de uma conexão já substituída
  state.conn = null;
  state.pending = new Map();
  setStatus("desconectado", "");
  logLine("conexão fechada; tentando de novo em 1s");
  // o servidor retoma uma colônia viva pelo nome; refs novos são por sessão
  setTimeout(start, 1000);
}

// --- pipeline: uma linha crua por vez ---

function handleLine(line) {
  const result = parseLine(line);
  if (result.tag === "error") {
    logLine(`linha ignorada: ${result.reason}`);
    return;
  }
  const msg = result.value;
  // OBS não carrega campo type; quem tem tick + status + cells é observação
  const type = msg.type !== undefined ? msg.type : "obs";
  dispatch(type, msg);
  paint();
}

function dispatch(type, msg) {
  switch (type) {
    case "welcome": return onWelcome(msg);
    case "obs": return onObservation(msg);
    case "ack": return (state.pending = onAck(state.pending, msg.ref));
    case "nack": return onNack(msg);
    case "score":
      state.scores = msg.entries;
      return;
    case "err":
      return logLine(`ERR ${msg.ref}: ${msg.code} ${msg.detail}`);
    case "pong":
      return;
    default:
      return logLine(`mensagem ignorada: ${type}`);
  }
}

function onWelcome(msg) {
  if (msg.role !== "colony") return logLine("welcome de espectador, ignorado");
  state.myId = msg.id;
  state.w = msg.w;
  state.h = msg.h;
  logLine(`entrou como ${msg.name} (id ${msg.id}), spawn ${msg.spawn}`);
}

function onObservation(obs) {
  // tick novo: vence os pendentes antigos antes de agir
  if (obs.tick > state.tick) {
    state.tick = obs.tick;
    const [pending, effects] = onTimeout(state.pending, obs.tick);
    state.pending = pending;
    for (const eff of effects) {
      if (eff.retry) state.conn.sendLine(eff.line);
      else logLine(`acao descartada sem ACK: ${eff.drop}`);
    }
    setStatus(statusText("conectado"), "conectado");
  }

  // células vistas persistem: a névoa de guerra só recua
  for (const c of obs.cells) state.knownCells.set(key(c.x, c.y), c);

  if (obs.status !== "alive") return; // eliminada: só assiste
  sendAction(decide(obs, state.myId));
}

function sendAction(action) {
  const ref = state.refs.next();
  const line = encodeAction(action, ref);
  state.pending = addPending(state.pending, ref, line, state.tick);
  state.conn.sendLine(line);
}

function onNack(msg) {
  if (msg.code === "duplicate_ref") {
    // informacional: o ACK original chega em seguida, mantém o pendente
    return;
  }
  state.pending = onAck(state.pending, msg.ref);
  logLine(`NACK ${msg.ref}: ${msg.code} ${msg.detail}`);
}

// --- arranque ---

els.button.addEventListener("click", () => {
  if (state.conn) state.conn.close();
  start();
});
