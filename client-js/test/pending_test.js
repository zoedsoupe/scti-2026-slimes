// Política de retry pura sobre o mapa de pendentes (at-least-once +
// idempotência). ack remove; timeout dentro do orçamento reenvia; no
// limite do orçamento descarta.

import { test, assert, assertEqual } from "./runner.js";
import { addPending, onAck, onTimeout, BUDGET, TIMEOUT } from "../src/protocol/pending.js";

test("pending: ack remove o ref dos pendentes", () => {
  let pending = addPending(new Map(), "r-1", "ACT r-1 pass", 10);
  pending = onAck(pending, "r-1");
  assert(!pending.has("r-1"), "ack nao removeu o pendente");
});

test("pending: timeout dentro do orcamento gera retry", () => {
  const pending = addPending(new Map(), "r-1", "ACT r-1 expand 3 4", 10);
  const [next, effects] = onTimeout(pending, 10 + TIMEOUT);
  assertEqual(effects, [{ retry: "r-1", line: "ACT r-1 expand 3 4" }]);
  assertEqual(next.get("r-1").retries, 1);
});

test("pending: timeout no limite do orcamento descarta", () => {
  let pending = addPending(new Map(), "r-1", "ACT r-1 pass", 0);
  // estoura o orçamento: BUDGET retries, o timeout seguinte derruba
  for (let i = 0; i < BUDGET; i++) {
    const [next, effects] = onTimeout(pending, (i + 1) * TIMEOUT);
    assertEqual(effects.length, 1, `timeout ${i} devia gerar retry`);
    assert(effects[0].retry !== undefined, `timeout ${i} devia ser retry`);
    pending = next;
  }
  const [next, effects] = onTimeout(pending, (BUDGET + 1) * TIMEOUT);
  assertEqual(effects, [{ drop: "r-1" }]);
  assert(!next.has("r-1"), "drop nao removeu o pendente");
});

test("pending: ref recente nao vence", () => {
  const pending = addPending(new Map(), "r-1", "ACT r-1 pass", 10);
  const [next, effects] = onTimeout(pending, 10 + TIMEOUT - 1);
  assertEqual(effects, []);
  assertEqual(next.get("r-1").retries, 0);
});
