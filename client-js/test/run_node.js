// Entrada node: importa os módulos de teste, roda e imprime o resumo.

import "./protocol_test.js";
import "./strategy_test.js";
import "./resolve_test.js";
import "./parity_test.js";
import { run } from "./runner.js";

const { passed, failed, results } = await run();
for (const r of results) {
  console.log(`${r.ok ? "PASS" : "FAIL"} ${r.name}${r.ok ? "" : " - " + r.error}`);
}
console.log(`${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
