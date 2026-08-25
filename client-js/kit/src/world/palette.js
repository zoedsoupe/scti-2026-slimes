// Cor da colônia como função pura do id (ordem de entrada), para que o
// cliente derive a mesma paleta do servidor sem recebê-la no SCORE.
// Espelha Slimes.World.color/1.

const PALETTE = ["F5C2E7", "96CDFB", "8BD5CA", "ABE9B3", "F8BD96", "F28FAD"];

function shade(hex, factor) {
  const ch = (i) => Math.min(255, Math.round(parseInt(hex.slice(i, i + 2), 16) * factor));
  return [ch(0), ch(2), ch(4)].map((c) => c.toString(16).padStart(2, "0")).join("").toUpperCase();
}

export function colonyColor(id) {
  if (id <= 6) return PALETTE[id - 1];
  const base = PALETTE[(id - 1) % 6];
  const cycle = Math.floor((id - 1) / 6);
  return shade(base, cycle % 2 === 1 ? 1.25 : 0.75);
}
