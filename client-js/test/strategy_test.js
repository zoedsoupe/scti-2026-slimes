// E3: classe da ação esperada para observações fixas (não a célula exata).

import { test, assertEqual } from "./runner.js";
import { decide } from "../src/strategy/decide.js";

const cell = (x, y, owner, fortified = 0) => ({ x, y, terrain: "plain", owner, fortified });

test("E3: inimigo desfortificado adjacente leva attack", () => {
  const obs = { cells: [cell(5, 5, 1), cell(6, 5, 2, 0)] };
  assertEqual(decide(obs, 1).kind, "attack");
});

test("E3: sem inimigos e com vazia adjacente leva expand", () => {
  const obs = { cells: [cell(5, 5, 1), cell(6, 5, 0)] };
  assertEqual(decide(obs, 1).kind, "expand");
});

test("E3: so inimigo fortificado adjacente leva fortify", () => {
  // decide() fortifica uma célula de fronteira quando há inimigos mas
  // todos estão fortificados
  const obs = { cells: [cell(5, 5, 1), cell(6, 5, 2, 1)] };
  assertEqual(decide(obs, 1).kind, "fortify");
});

test("E3: sem para onde ir leva pass", () => {
  const obs = {
    cells: [cell(5, 5, 1), cell(4, 5, 1), cell(6, 5, 1), cell(5, 4, 1), cell(5, 6, 1)],
  };
  assertEqual(decide(obs, 1).kind, "pass");
});
