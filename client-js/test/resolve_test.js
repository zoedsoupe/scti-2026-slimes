// Regras do resolver em isolamento. A ordem explícita (4o argumento)
// elimina a dependência do rng no shuffle.

import { test, assert, assertEqual } from "./runner.js";
import { resolve } from "../src/infra/simulator/resolve.js";

const cell = (owner, fortified = 0, terrain = "plain") => ({ terrain, owner, fortified });
const colony = (id, oldest) => ({ id, name: `c${id}`, status: "alive", oldest });

function mkState(w, h, cells, colonies) {
  return { width: w, height: h, cells: new Map(cells), colonies: new Map(colonies) };
}

test("resolver: fortify vale na fase 1, antes de ataques do mesmo tick", () => {
  // atacar uma célula recém-fortificada exigiria cara-ou-coroa; aqui o
  // atacante expande para outro lugar e só verificamos que o fortify valeu
  const state = mkState(
    5,
    5,
    [
      ["2,2", cell(1)],
      ["0,0", cell(2)],
    ],
    [
      [1, colony(1, [2, 2])],
      [2, colony(2, [0, 0])],
    ]
  );
  const actions = [
    { colony: 2, kind: "expand", cell: [0, 1] },
    { colony: 1, kind: "fortify", cell: [2, 2] },
  ];
  const [next, events] = resolve(state, actions, null, [2, 1]);
  assertEqual(next.cells.get("2,2").fortified, 1);
  assert(
    events.some((e) => e.type === "cell" && e.x === 2 && e.y === 2 && e.fortified === 1),
    "sem evento de fortify"
  );
  assertEqual(next.cells.get("0,1").owner, 2);
});

test("resolver: conflito de expand, o primeiro da ordem vence e o outro desperdiça", () => {
  const state = mkState(
    3,
    1,
    [
      ["0,0", cell(1)],
      ["2,0", cell(2)],
    ],
    [
      [1, colony(1, [0, 0])],
      [2, colony(2, [2, 0])],
    ]
  );
  const actions = [
    { colony: 1, kind: "expand", cell: [1, 0] },
    { colony: 2, kind: "expand", cell: [1, 0] },
  ];
  const [next, events] = resolve(state, actions, null, [1, 2]);
  assertEqual(next.cells.get("1,0").owner, 1);
  const evs = events.filter((e) => e.type === "cell" && e.x === 1 && e.y === 0);
  assertEqual(evs.length, 1);
  assertEqual(evs[0].owner, 1);
});

test("resolver: attack toma celula inimiga desfortificada", () => {
  const state = mkState(
    3,
    1,
    [
      ["0,0", cell(1)],
      ["1,0", cell(2)],
      ["2,0", cell(2)],
    ],
    [
      [1, colony(1, [0, 0])],
      [2, colony(2, [1, 0])],
    ]
  );
  const actions = [{ colony: 1, kind: "attack", cell: [1, 0] }];
  const [next, events] = resolve(state, actions, null, [1]);
  assertEqual(next.cells.get("1,0").owner, 1);
  assert(events.some((e) => e.type === "cell" && e.x === 1 && e.y === 0 && e.owner === 1));
});

test("resolver: expand em celula ocupada e desperdicado", () => {
  const state = mkState(
    2,
    1,
    [
      ["0,0", cell(1)],
      ["1,0", cell(2)],
    ],
    [
      [1, colony(1, [0, 0])],
      [2, colony(2, [1, 0])],
    ]
  );
  const actions = [{ colony: 1, kind: "expand", cell: [1, 0] }];
  const [next, events] = resolve(state, actions, null, [1]);
  assertEqual(next.cells.get("1,0").owner, 2);
  assertEqual(events.filter((e) => e.type === "cell").length, 0);
});

test("resolver: regra dos orfaos mata celulas desconectadas, empate salva a mais antiga", () => {
  const state = mkState(
    3,
    1,
    [
      ["0,0", cell(1)],
      ["2,0", cell(1)],
    ],
    [[1, colony(1, [0, 0])]]
  );
  const [next, events] = resolve(state, [], null, [1]);
  assertEqual(next.cells.get("0,0").owner, 1);
  assertEqual(next.cells.get("2,0").owner, 0);
  assert(events.some((e) => e.type === "cell" && e.x === 2 && e.y === 0 && e.owner === 0));
});

test("resolver: colonia sem celulas e eliminada", () => {
  const state = mkState(
    3,
    1,
    [
      ["0,0", cell(1)],
      ["1,0", cell(2)],
    ],
    [
      [1, colony(1, [0, 0])],
      [2, colony(2, [1, 0])],
    ]
  );
  const actions = [{ colony: 2, kind: "attack", cell: [0, 0] }];
  const [next, events] = resolve(state, actions, null, [2]);
  assertEqual(next.colonies.get(1).status, "dead");
  assert(events.some((e) => e.type === "eliminated" && e.id === 1), "sem evento de eliminacao");
});
