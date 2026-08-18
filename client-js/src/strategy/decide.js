// E3: estratégia de referência. observação -> ação, pura.
// Prioridade: ataca inimigo desfortificado adjacente; fortifica fronteira
// sob ameaça; expande para a célula vazia mais próxima do centro da visão;
// senão passa.

import { expandable, attackable, borderCells } from "../world/observation.js";

export function decide(obs, myId) {
  const enemies = attackable(obs.cells, myId);
  const weak = enemies.filter((c) => c.fortified === 0);
  if (weak.length > 0) return { kind: "attack", x: weak[0].x, y: weak[0].y };

  const border = borderCells(obs.cells, myId).filter((c) => c.fortified === 0);
  if (border.length > 0 && enemies.length > 0) {
    return { kind: "fortify", x: border[0].x, y: border[0].y };
  }

  const targets = expandable(obs.cells, myId);
  if (targets.length > 0) {
    // expande na direção do inimigo mais próximo, se houver; senão qualquer uma
    targets.sort((a, b) => dist(a, enemies[0]) - dist(b, enemies[0]));
    return { kind: "expand", x: targets[0].x, y: targets[0].y };
  }

  return { kind: "pass" };
}

const dist = (a, b) => (b ? Math.abs(a.x - b.x) + Math.abs(a.y - b.y) : 0);
