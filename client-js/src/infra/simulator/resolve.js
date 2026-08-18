// Port puro de Slimes.World.Resolve. Mesma ordem de resolução:
// shuffle seeded -> fase 1 fortify -> fase 2 expand/attack -> órfãos ->
// eliminação. Mesmos argumentos, mesmo resultado, sem efeitos.
//
// Estado: {width, height, cells: Map "x,y" -> {terrain, owner, fortified},
//          colonies: Map id -> {id, name, status, oldest}}
// Eventos: {type: "cell", x, y, owner, fortified} | {type: "eliminated", id}

import { key, neighbors4 } from "../../world/observation.js";
import { uniformInt } from "./rng.js";

const EMPTY = { terrain: "plain", owner: 0, fortified: 0 };

const cellAt = (state, x, y) => state.cells.get(key(x, y)) || EMPTY;

const putCell = (state, x, y, cell) => state.cells.set(key(x, y), cell);

// `order` opcional: replay de fixtures golden passa a ordem seeded já
// gravada; sem ele, embaralha com o rng (partida normal do simulador)
export function resolve(state, actions, rng, order = null) {
  // cópia rasa: o resolver nunca muta o estado do chamador
  state = { ...state, cells: new Map(state.cells), colonies: new Map(state.colonies) };

  let rng2 = rng;
  if (order === null) {
    [order, rng2] = shuffle([...state.colonies.keys()], rng);
  }
  const byColony = new Map(actions.map((a) => [a.colony, a]));

  const events = [];

  // fase 1, defesa: todos os fortify antes de qualquer ataque
  for (const id of order) {
    const a = byColony.get(id);
    if (a && a.kind === "fortify") {
      const cell = cellAt(state, a.cell[0], a.cell[1]);
      if (cell.owner === id && cell.fortified === 0) {
        putCell(state, a.cell[0], a.cell[1], { ...cell, fortified: 1 });
        events.push({ type: "cell", x: a.cell[0], y: a.cell[1], owner: id, fortified: 1 });
      }
    }
  }

  // fase 2, expansão: expand/attack na ordem embaralhada
  let rng3 = rng2;
  for (const id of order) {
    const a = byColony.get(id);
    if (!a || (a.kind !== "expand" && a.kind !== "attack")) continue;
    const [x, y] = a.cell;
    const cell = cellAt(state, x, y);

    if (a.kind === "expand") {
      if (cell.owner === 0) {
        // perdedor do conflito (owner != 0): ação desperdiçada
        putCell(state, x, y, { ...cell, owner: id, fortified: 0 });
        events.push({ type: "cell", x, y, owner: id, fortified: 0 });
      }
    } else {
      if (cell.owner === id) continue;
      if (cell.fortified === 1) {
        // célula fortificada: 50/50 pelo rng do tick
        const [n, next] = uniformInt(rng3, 2);
        rng3 = next;
        if (n !== 1) continue;
      }
      putCell(state, x, y, { ...cell, owner: id, fortified: 0 });
      events.push({ type: "cell", x, y, owner: id, fortified: 0 });
    }
  }

  applyOrphanRule(state, events);
  eliminateEmpty(state, events);

  return [state, events];
}

// Fisher-Yates idêntico ao do Elixir: i do fim ao 1, j = uniform(i+1) - 1
export function shuffle(list, rng) {
  if (list.length < 2) return [list, rng];
  const arr = [...list];
  for (let i = arr.length - 1; i >= 1; i--) {
    const [j1, next] = uniformInt(rng, i + 1);
    rng = next;
    [arr[i], arr[j1 - 1]] = [arr[j1 - 1], arr[i]];
  }
  return [arr, rng];
}

// células fora do maior componente da colônia morrem; no empate de tamanho,
// sobrevive o componente que contém a célula mais antiga
function applyOrphanRule(state, events) {
  for (const [id, colony] of state.colonies) {
    if (colony.status !== "alive") continue;
    const owned = [];
    for (const [k, cell] of state.cells) {
      if (cell.owner === id) owned.push(k);
    }
    const comps = components(owned);
    if (comps.length <= 1) continue;

    const maxSize = Math.max(...comps.map((c) => c.length));
    const largest = comps.filter((c) => c.length === maxSize);
    const oldestKey = key(colony.oldest[0], colony.oldest[1]);
    const survivor = largest.find((c) => c.includes(oldestKey)) || largest[0];

    for (const comp of comps) {
      if (comp === survivor) continue;
      for (const k of comp) {
        const [x, y] = k.split(",").map(Number);
        const cell = cellAt(state, x, y);
        putCell(state, x, y, { ...cell, owner: 0, fortified: 0 });
        events.push({ type: "cell", x, y, owner: 0, fortified: 0 });
      }
    }
  }
}

function components(cells) {
  const remaining = new Set(cells);
  const comps = [];
  for (const start of cells) {
    if (!remaining.has(start)) continue;
    const comp = new Set([start]);
    remaining.delete(start);
    const queue = [start];
    while (queue.length > 0) {
      const [x, y] = queue.shift().split(",").map(Number);
      for (const [nx, ny] of neighbors4(x, y)) {
        const nk = key(nx, ny);
        if (remaining.has(nk) && !comp.has(nk)) {
          comp.add(nk);
          remaining.delete(nk);
          queue.push(nk);
        }
      }
    }
    comps.push([...comp]);
  }
  return comps;
}

function eliminateEmpty(state, events) {
  for (const [id, colony] of state.colonies) {
    if (colony.status !== "alive") continue;
    const ownsAny = [...state.cells.values()].some((c) => c.owner === id);
    if (!ownsAny) {
      state.colonies.set(id, { ...colony, status: "dead" });
      events.push({ type: "eliminated", id });
    }
  }
}
