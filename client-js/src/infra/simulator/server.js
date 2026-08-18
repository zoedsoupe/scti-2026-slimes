// Servidor falso em processo: fala exatamente o protocolo da Seção 1 do
// PROTOCOL.md, espelhando lib/slimes/world.ex (a autoridade de comportamento).
// Um "endpoint" é o espelho de um WebSocket em nível de linha:
// { sendLine(line), close(), onLine(cb), onClose(cb) }.

import { parseLine } from "../../protocol/parse.js";
import { encodeAction, encodeHello, createRefs } from "../../protocol/encode.js";
import { colonyColor } from "../../world/palette.js";
import { seedRng, uniform } from "./rng.js";
import { resolve } from "./resolve.js";
import { BOTS } from "./bots.js";

const NAME_RE = /^[a-z0-9-]{1,16}$/;
const VIEW_RADIUS = 3;
const EMPTY = { terrain: "plain", owner: 0, fortified: 0 };

const key = (x, y) => `${x},${y}`;
const fmtCell = (x, y, c) => `${x},${y},${c.terrain},${c.owner},${c.fortified}`;

export function createSimServer(opts = {}) {
  const {
    baseSeed = 42,
    width = 60,
    height = 40,
    tickMs = 1000,
    mode = "tournament",
    bots = ["random", "greedy"],
    terrain = [],
  } = opts;

  const cells = new Map();
  for (const [x, y, t] of terrain) cells.set(key(x, y), { terrain: t, owner: 0, fortified: 0 });

  const world = {
    cells,
    colonies: new Map(), // id -> {id, name, color, status, oldest, endpoint}
    nextId: 1,
    spectators: [],   // endpoints
    queue: new Map(), // colonyId -> {colony, kind, cell}
    dedup: new Map(), // "colonyId|ref" -> tick do ACK original
    tick: 0,
  };

  const cellAt = (x, y) => world.cells.get(key(x, y)) || EMPTY;

  const timer = setInterval(runTick, tickMs);
  timer.unref?.(); // não segura o processo node aberto por causa do simulador

  for (const botName of bots) bootBot(botName);

  function emit(endpoint, line) {
    if (endpoint && endpoint._onLine) endpoint._onLine(line);
  }

  const nack = (endpoint, ref, code, detail) => emit(endpoint, `NACK ${ref} ${code} ${detail}`);

  // melhor ref possível para uma linha que não deu parse, como no
  // socket_handler.ex: terceiro token no HELLO, segundo nas demais
  function bestRef(line) {
    const t = line.split(" ").filter(Boolean);
    if (t[0] === "HELLO" && t.length >= 3) return t[2];
    if (t.length >= 2) return t[1];
    return "unknown";
  }

  function connect() {
    const endpoint = {
      _onLine: null,
      _onClose: null,
      status: "awaiting_hello",
      role: null,
      colonyId: null,
      sendLine(line) {
        handleLine(endpoint, line);
      },
      close() {
        closeEndpoint(endpoint);
      },
      onLine(cb) {
        endpoint._onLine = cb;
      },
      onClose(cb) {
        endpoint._onClose = cb;
      },
    };
    return endpoint;
  }

  function handleLine(endpoint, line) {
    const parsed = parseLine(line);
    if (parsed.tag === "error") {
      return emit(endpoint, `ERR ${bestRef(line)} bad_message ${parsed.reason}`);
    }
    const msg = parsed.value;
    switch (msg.type) {
      case "hello":
        return handleHello(endpoint, msg);
      case "act":
        return handleAct(endpoint, msg);
      case "ping":
        if (endpoint.status !== "joined") {
          return emit(endpoint, `ERR ${msg.ref} bad_message ping antes do hello`);
        }
        return emit(endpoint, `PONG ${msg.ref}`);
      default:
        // mensagens de servidor (OBS, SCORE, ...) nunca chegam do cliente
        return emit(endpoint, `ERR ${bestRef(line)} bad_message tipo desconhecido ${line.split(" ")[0]}`);
    }
  }

  function handleHello(endpoint, msg) {
    if (msg.badVersion) return emit(endpoint, `ERR ${msg.ref} bad_version`);
    if (endpoint.status === "joined") {
      return emit(endpoint, `ERR ${msg.ref} bad_message hello ja enviado`);
    }
    if (msg.role === "spectator") return joinSpectator(endpoint);
    return joinColony(endpoint, msg);
  }

  function joinSpectator(endpoint) {
    world.spectators.push(endpoint);
    endpoint.status = "joined";
    endpoint.role = "spectator";
    // snapshot completo da grade, x por fora e y por dentro, como full_grid
    const snapshot = [];
    for (let x = 0; x < width; x++) {
      for (let y = 0; y < height; y++) snapshot.push(fmtCell(x, y, cellAt(x, y)));
    }
    emit(endpoint, `WELCOME srv-0 spectator ${width} ${height} ${tickMs} ${snapshot.join(";")}`);
  }

  function joinColony(endpoint, msg) {
    const name = msg.name;
    if (name === "spectator") return nack(endpoint, msg.ref, "bad_name", "nome reservado");
    if (!NAME_RE.test(name)) return nack(endpoint, msg.ref, "bad_name", "nome invalido");

    const existing = [...world.colonies.values()].find((c) => c.name === name);
    let colony;
    if (existing && existing.status === "alive") {
      // reconexão: retoma a colônia (world.ex resume; não existe NACK por
      // duplicado para colônia viva)
      colony = existing;
    } else {
      // nome novo ou de colônia eliminada: entrada nova
      colony = freshJoin(name);
    }
    colony.endpoint = endpoint;

    endpoint.status = "joined";
    endpoint.role = "colony";
    endpoint.colonyId = colony.id;
    emit(
      endpoint,
      `WELCOME srv-0 ${colony.id} ${colony.name} ${colony.color} ${width} ${height} ${tickMs} ${VIEW_RADIUS} ${colony.oldest[0]},${colony.oldest[1]}`
    );
  }

  function freshJoin(name) {
    const id = world.nextId;
    const spawn = spawnCell(); // usa nextId como seed, antes do incremento
    const colony = { id, name, color: colonyColor(id), status: "alive", oldest: spawn, endpoint: null };
    world.colonies.set(id, colony);
    const prev = cellAt(spawn[0], spawn[1]);
    world.cells.set(key(spawn[0], spawn[1]), { ...prev, owner: id, fortified: 0 });
    world.nextId = id + 1;
    return colony;
  }

  // cantos primeiro, maximizando a distância mínima para células tomadas;
  // empates pelo rng seedRng(baseSeed, nextId, 1), como spawn_cell do world.ex
  function spawnCell() {
    const taken = [];
    for (const [k, c] of world.cells) {
      if (c.owner !== 0) taken.push(k.split(",").map(Number));
    }
    const corners = [
      [0, 0],
      [width - 1, 0],
      [0, height - 1],
      [width - 1, height - 1],
    ];
    let candidates = corners.filter(([x, y]) => cellAt(x, y).owner === 0);
    if (candidates.length === 0) {
      candidates = [];
      for (let x = 0; x < width; x++) {
        for (let y = 0; y < height; y++) {
          if (cellAt(x, y).owner === 0) candidates.push([x, y]);
        }
      }
    }
    let rng = seedRng(baseSeed, world.nextId, 1);
    const scored = candidates.map((pos) => {
      const [tiebreak, next] = uniform(rng);
      rng = next;
      return { pos, dist: -minDistance(pos, taken), tiebreak };
    });
    scored.sort((a, b) => a.dist - b.dist || a.tiebreak - b.tiebreak);
    return scored[0].pos;
  }

  function minDistance([x, y], taken) {
    if (taken.length === 0) return 0;
    return Math.min(...taken.map(([tx, ty]) => Math.abs(x - tx) + Math.abs(y - ty)));
  }

  // validação na ordem exata do SERVER_SPEC seção 4
  function handleAct(endpoint, msg) {
    if (endpoint.status !== "joined" || endpoint.role !== "colony") {
      return emit(endpoint, `ERR ${msg.ref} bad_message acao fora de uma colonia`);
    }
    const id = endpoint.colonyId;
    const dedupKey = `${id}|${msg.ref}`;
    if (world.dedup.has(dedupKey)) {
      nack(endpoint, msg.ref, "duplicate_ref", "ref ja processado");
      return emit(endpoint, `ACK ${msg.ref} ${world.dedup.get(dedupKey)}`);
    }

    if (msg.kind !== "pass") {
      // modo antes de validade de célula: resposta consistente no cooperativo
      if (msg.kind === "attack" && mode === "cooperative") {
        return nack(endpoint, msg.ref, "attacks_disabled", "ataques desabilitados no modo cooperativo");
      }
      const { x, y } = msg;
      if (x < 0 || y < 0 || x >= width || y >= height) {
        return nack(endpoint, msg.ref, "bad_cell", "fora da grade");
      }
      if (!reachable(id, x, y)) {
        return nack(endpoint, msg.ref, "bad_cell", "celula nao adjacente a colonia");
      }
      const cell = cellAt(x, y);
      if (msg.kind === "expand" && cell.owner !== 0) {
        return nack(endpoint, msg.ref, "not_empty", "celula ocupada");
      }
      if (msg.kind === "attack" && (cell.owner === 0 || cell.owner === id)) {
        return nack(endpoint, msg.ref, "not_enemy", "celula nao e inimiga");
      }
      if (msg.kind === "fortify" && cell.owner !== id) {
        return nack(endpoint, msg.ref, "not_self", "celula nao pertence a colonia");
      }
      // fortify de célula própria já fortificada: ACK normal, ação desperdiçada
    }

    // ponytail: o loop em processo nunca emite too_late; JS é single-threaded,
    // então um ACT sempre cai dentro da janela do tick corrente.
    world.queue.set(id, { colony: id, kind: msg.kind, cell: msg.kind === "pass" ? null : [msg.x, msg.y] });
    world.dedup.set(dedupKey, world.tick);
    emit(endpoint, `ACK ${msg.ref} ${world.tick}`);
  }

  // alcançável: célula da própria colônia ou adjacente ortogonal a uma delas
  function reachable(id, x, y) {
    for (const [k, c] of world.cells) {
      if (c.owner !== id) continue;
      const [cx, cy] = k.split(",").map(Number);
      if ((cx === x && cy === y) || Math.abs(cx - x) + Math.abs(cy - y) === 1) return true;
    }
    return false;
  }

  function runTick() {
    const next = world.tick + 1;
    const rng = seedRng(baseSeed, next, 0);
    const actions = [...world.queue.values()].filter(
      (a) => world.colonies.get(a.colony)?.status === "alive"
    );
    const [newState, events] = resolve({ width, height, cells: world.cells, colonies: world.colonies }, actions, rng);
    world.cells = newState.cells;
    world.colonies = newState.colonies;
    world.tick = next;
    world.queue.clear();
    broadcast(events);
  }

  function broadcast(events) {
    const tick = world.tick;
    const ref = `srv-${tick}`;

    const diff = events
      .filter((e) => e.type === "cell")
      .map((e) => `${e.x},${e.y},${e.owner},${e.fortified}`)
      .join(";");
    for (const ep of world.spectators) emit(ep, `DIFF ${ref} ${tick} ${diff}`);

    const score = [...world.colonies.values()]
      .sort((a, b) => a.id - b.id)
      .map((c) => `${c.id},${c.name},${cellCount(c.id)},${c.status}`)
      .join(";");
    const everyone = [...world.spectators, ...[...world.colonies.values()].map((c) => c.endpoint)];
    for (const ep of everyone) emit(ep, `SCORE ${ref} ${tick} ${score}`);

    for (const colony of world.colonies.values()) {
      // colônia eliminada: status dead e lista vazia, socket continua aberto
      const obs = colony.status === "alive" ? observableCells(colony.id) : [];
      emit(colony.endpoint, `OBS ${ref} ${tick} ${colony.status} ${tick} ${obs.join(";")}`);
    }
  }

  function cellCount(id) {
    let n = 0;
    for (const c of world.cells.values()) if (c.owner === id) n++;
    return n;
  }

  // união das vizinhanças 7x7 ao redor de cada célula da colônia,
  // ordenadas por x depois y, só células dentro da grade
  function observableCells(id) {
    const seen = new Set();
    for (const [k, c] of world.cells) {
      if (c.owner !== id) continue;
      const [cx, cy] = k.split(",").map(Number);
      for (let x = cx - VIEW_RADIUS; x <= cx + VIEW_RADIUS; x++) {
        for (let y = cy - VIEW_RADIUS; y <= cy + VIEW_RADIUS; y++) {
          if (x >= 0 && y >= 0 && x < width && y < height) seen.add(key(x, y));
        }
      }
    }
    return [...seen]
      .map((k) => k.split(",").map(Number))
      .sort((a, b) => a[0] - b[0] || a[1] - b[1])
      .map(([x, y]) => fmtCell(x, y, cellAt(x, y)));
  }

  function closeEndpoint(endpoint) {
    if (endpoint.role === "spectator") {
      world.spectators = world.spectators.filter((e) => e !== endpoint);
    } else if (endpoint.role === "colony") {
      // a colônia fica no mundo; um rejoin com o mesmo nome a retoma
      const colony = world.colonies.get(endpoint.colonyId);
      if (colony && colony.endpoint === endpoint) colony.endpoint = null;
    }
    const cb = endpoint._onClose;
    endpoint._onLine = null;
    endpoint._onClose = null;
    if (cb) queueMicrotask(cb);
  }

  // bot interno: entra como um cliente qualquer (regra de spawn incluída) e
  // responde a cada OBS com a ação da sua estratégia. Nunca fala no close.
  function bootBot(botName) {
    const strategy = BOTS[botName];
    if (!strategy) return;
    const name = `z-${botName}`;
    const refs = createRefs(name);
    let myId = null;
    let rng = seedRng(baseSeed, world.nextId + 100, 7); // rng próprio, determinístico
    const endpoint = connect();
    endpoint.onLine((line) => {
      const parsed = parseLine(line);
      if (parsed.tag !== "ok") return;
      const msg = parsed.value;
      if (msg.type === "welcome" && msg.role === "colony") {
        myId = msg.id;
        return;
      }
      if (!line.startsWith("OBS ") || myId === null || msg.status !== "alive") return;
      const [action, nextRng] = strategy(msg, myId, rng);
      rng = nextRng;
      endpoint.sendLine(encodeAction(action, refs.next()));
    });
    endpoint.sendLine(encodeHello(refs.next(), "colony", name));
  }

  return { connect, stop: () => clearInterval(timer) };
}
