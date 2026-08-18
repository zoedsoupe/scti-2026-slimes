// E1/E2: parse das linhas do servidor e codificação das linhas do cliente.

import { test, assert, assertEqual } from "./runner.js";
import { parseObservation, parseCell } from "../src/protocol/parse.js";
import { encodeAction, createRefs } from "../src/protocol/encode.js";

test("E1: linha OBS valida vira observacao de dominio", () => {
  const r = parseObservation("OBS srv-97 97 alive 97 9,5,plain,0,0;10,5,plain,3,1");
  assert(r.tag === "ok", "parse falhou");
  const obs = r.value;
  assertEqual(obs.tick, 97);
  assertEqual(obs.status, "alive");
  assertEqual(obs.scoresTick, 97);
  assertEqual(obs.cells.length, 2);
  assertEqual(obs.cells[1], { x: 10, y: 5, terrain: "plain", owner: 3, fortified: 1 });
});

test("E1: token extra no final e ignorado", () => {
  const r = parseObservation("OBS srv-1 1 alive 1 1,2,plain,0,0 lixo");
  assert(r.tag === "ok", "token extra derrubou o parse");
  assertEqual(r.value.cells.length, 1);
});

test("E1: OBS sem tick e erro", () => {
  const r = parseObservation("OBS srv-1 alive 1");
  assert(r.tag === "error", "OBS sem tick passou");
});

test("E1: celula forest com dono expoe terreno e owner", () => {
  const c = parseCell("11,5,forest,2,0");
  assertEqual(c.terrain, "forest");
  assertEqual(c.owner, 2);
});

test("E2: encodeAction cobre os quatro kinds", () => {
  assertEqual(encodeAction({ kind: "expand", x: 1, y: 2 }, "r-1"), "ACT r-1 expand 1 2");
  assertEqual(encodeAction({ kind: "attack", x: 3, y: 4 }, "r-2"), "ACT r-2 attack 3 4");
  assertEqual(encodeAction({ kind: "fortify", x: 5, y: 6 }, "r-3"), "ACT r-3 fortify 5 6");
  assertEqual(encodeAction({ kind: "pass" }, "r-4"), "ACT r-4 pass");
});

test("E2: pass omite coordenadas", () => {
  const line = encodeAction({ kind: "pass" }, "r-9");
  assert(!line.includes(","), "pass com coordenada");
  assertEqual(line.split(" ").length, 3);
});

test("E2: createRefs mantem o segmento de sessao e incrementa n", () => {
  const refs = createRefs("aurora", "k3f9");
  assertEqual(refs.next(), "aurora-k3f9-1");
  assertEqual(refs.next(), "aurora-k3f9-2");
  assertEqual(refs.session, "k3f9");
});
