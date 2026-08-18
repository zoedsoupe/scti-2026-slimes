// Paridade com as fixtures golden (docs/GOLDEN.md): replay pelo resolver e
// comparação do diff e do placar a cada tick.

import { test, assertEqual } from "./runner.js";
import { resolve } from "../src/infra/simulator/resolve.js";
import { key } from "../src/world/observation.js";

const FIXTURES = ["attack_elimination", "expand_and_fortify", "orphan_rule", "terrain"];

const isNode = typeof process !== "undefined" && !!process.versions?.node;

async function loadFixture(name) {
  if (isNode) {
    const { readFile } = await import("node:fs/promises");
    return readFile(new URL(`../../priv/golden/${name}.jsonl`, import.meta.url), "utf8");
  }
  const res = await fetch(`../../priv/golden/${name}.jsonl`);
  return res.text();
}

// placar computado como [id, celulas, vivo], normalizado para comparar
// sem depender da ordem das chaves do JSON
function scoreboard(state) {
  return [...state.colonies.values()]
    .sort((a, b) => a.id - b.id)
    .map((c) => {
      let n = 0;
      for (const cell of state.cells.values()) if (cell.owner === c.id) n++;
      return [c.id, n, c.status === "alive"];
    });
}

const sortRows = (rows) => rows.map((r) => JSON.stringify(r)).sort();

function replay(name, text) {
  const lines = text
    .trim()
    .split("\n")
    .map((l) => JSON.parse(l));
  const [config, spawns] = lines;

  const cells = new Map();
  for (const [x, y, t] of config.terrain) cells.set(key(x, y), { terrain: t, owner: 0, fortified: 0 });
  const colonies = new Map();
  for (const c of spawns.colonies) {
    colonies.set(c.id, { id: c.id, name: c.name, status: "alive", oldest: c.cell });
    const prev = cells.get(key(c.cell[0], c.cell[1])) || { terrain: "plain", owner: 0, fortified: 0 };
    cells.set(key(c.cell[0], c.cell[1]), { ...prev, owner: c.id, fortified: 0 });
  }
  let state = { width: config.grid.w, height: config.grid.h, cells, colonies };

  for (const line of lines.slice(2)) {
    if (line.kind === "final") {
      const expected = line.scores.map((s) => [s.id, s.cells, s.alive]);
      assertEqual(scoreboard(state), expected, `${name}: placar final`);
      continue;
    }
    const actions = line.actions.map((a) => ({ colony: a.colony, kind: a.kind, cell: a.cell }));
    // a ordem gravada na fixture pula o shuffle; as fixtures evitam cara-ou-coroa
    // de ataque a fortificado porque o rng exsss do Elixir não é portado.
    // ponytail: se um golden futuro flippar moedas, essa é a peça que falta.
    const [next, events] = resolve(state, actions, null, actions.map((a) => a.colony));
    state = next;

    const computed = events
      .filter((e) => e.type === "cell")
      .map((e) => [e.x, e.y, e.owner, e.fortified]);
    assertEqual(sortRows(computed), sortRows(line.diff), `${name}: diff do tick ${line.tick}`);

    const expectedScores = line.scores.map((s) => [s.id, s.cells, s.alive]);
    assertEqual(scoreboard(state), expectedScores, `${name}: placar do tick ${line.tick}`);
  }
}

for (const name of FIXTURES) {
  test(`paridade golden: ${name}`, async () => {
    replay(name, await loadFixture(name));
  });
}
