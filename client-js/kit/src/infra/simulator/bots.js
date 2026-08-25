// Estratégias dos bots internos do simulador. Assinatura pura:
// (obs, myId, rng) -> [acao, novoRng]. O rng é threaded como no resolve;
// o greedy pode ignorá-lo.

import { ownCells, neighbors4, cellMap, key, expandable } from "../../world/observation.js";
import { uniformInt } from "./rng.js";

// escolhe uma célula própria ao acaso e um vizinho ortogonal ao acaso:
// expand se vazia, attack se inimiga, fortify se própria; senão pass
export function randomWalker(obs, myId, rng) {
  const own = ownCells(obs.cells, myId);
  if (own.length === 0) return [{ kind: "pass" }, rng];
  const [ci, rng1] = uniformInt(rng, own.length);
  const c = own[ci - 1];
  const [ni, rng2] = uniformInt(rng1, 4);
  const [nx, ny] = neighbors4(c.x, c.y)[ni - 1];
  const n = cellMap(obs.cells).get(key(nx, ny));
  if (!n) return [{ kind: "pass" }, rng2];
  if (n.owner === 0) return [{ kind: "expand", x: n.x, y: n.y }, rng2];
  if (n.owner !== myId) return [{ kind: "attack", x: n.x, y: n.y }, rng2];
  return [{ kind: "fortify", x: n.x, y: n.y }, rng2];
}

// primeira célula expansível da visão; senão pass
export function greedyExpander(obs, myId, rng) {
  const targets = expandable(obs.cells, myId);
  if (targets.length > 0) return [{ kind: "expand", x: targets[0].x, y: targets[0].y }, rng];
  return [{ kind: "pass" }, rng];
}

// nomes aceitos em opts.bots do simulador
export const BOTS = { random: randomWalker, greedy: greedyExpander };
