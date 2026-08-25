// E3: a sua estratégia. observação -> ação, pura.
//
// TODO E3: implemente decide(). A observação é o que o seu parse do E1
// devolveu: { ref, tick, status, scoresTick, cells }, onde cada célula é
// { x, y, terrain, owner, fortified }. myId é o id da sua colônia (veio no
// WELCOME). Devolva uma ação: { kind: "expand" | "attack" | "fortify", x, y }
// ou { kind: "pass" }.
//
// Os helpers de src/world/observation.js já estão prontos e testados:
// ownCells, expandable (vazias adjacentes), attackable (inimigas
// adjacentes), borderCells (suas células na fronteira). Use-os.
//
// Dica nível 1 (sobrevivência): expanda para células vazias, nunca ataque
// célula fortificada. Dica nível 2 (expansão + defesa): fortifique
// fronteiras com inimigo ao lado, ataque inimigos desfortificados.
//
// Enquanto o stub estiver aqui a sua colônia só passa a vez.

import { expandable, attackable, borderCells } from "../world/observation.js";

export function decide(obs, myId) {
  return { kind: "pass" };
}
