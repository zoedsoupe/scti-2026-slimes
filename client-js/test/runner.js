// Runner mínimo de asserts, sem framework: funciona no browser e no node.

const tests = [];

export const test = (name, fn) => tests.push({ name, fn });

export function assert(cond, msg) {
  if (!cond) throw new Error(msg || "assertion failed");
}

export function assertEqual(a, b, msg) {
  const [ja, jb] = [JSON.stringify(a), JSON.stringify(b)];
  if (ja !== jb) throw new Error(`${msg || "assertEqual"}: ${ja} !== ${jb}`);
}

export async function run() {
  const results = [];
  let passed = 0;
  let failed = 0;
  const el = typeof document !== "undefined" ? document.getElementById("results") : null;
  for (const { name, fn } of tests) {
    const r = { name, ok: true, error: null };
    try {
      await fn();
      passed++;
    } catch (e) {
      failed++;
      r.ok = false;
      r.error = String((e && e.message) || e);
    }
    results.push(r);
    if (el) {
      const div = document.createElement("div");
      div.textContent = `${r.ok ? "PASS" : "FAIL"} ${name}${r.ok ? "" : " - " + r.error}`;
      div.style.color = r.ok ? "green" : "red";
      el.appendChild(div);
    }
  }
  return { passed, failed, results };
}
