// Helpers puros sobre uma observação (a visão 7x7 que chega a cada tick).
// Nada aqui conhece socket, canvas ou rede.

// key(x, y): chave de mapa para uma coordenada.
//   x, y: coordenadas da célula
// Devolve a string "x,y".
// Exemplo: key(3, 4)  // => "3,4"
export const key = (x, y) => `${x},${y}`;

// cellMap(cells): indexa as células por coordenada, para consulta O(1).
//   cells: array de células { x, y, terrain, owner, fortified }
// Devolve Map "x,y" -> célula.
// Exemplo:
//   const map = cellMap(obs.cells);
//   map.get("3,4");  // => { x: 3, y: 4, terrain: "plain", owner: 0, fortified: 0 }
export function cellMap(cells) {
  return new Map(cells.map((c) => [key(c.x, c.y), c]));
}

// neighbors4(x, y): as 4 coordenadas ortogonalmente adjacentes (a regra
// de bad_cell do servidor usa a mesma adjacência).
//   x, y: coordenadas de origem
// Devolve array de pares [nx, ny], sem filtrar limites do mapa.
// Exemplo: neighbors4(3, 4)  // => [[4,4],[2,4],[3,5],[3,3]]
export const neighbors4 = (x, y) => [
  [x + 1, y],
  [x - 1, y],
  [x, y + 1],
  [x, y - 1],
];

// ownCells(cells, id): só as células da colônia id.
//   cells: array de células
//   id: id da sua colônia (veio no WELCOME)
// Devolve array de células (vazio se a colônia não tem nenhuma na visão).
// Exemplo: ownCells(obs.cells, myId)  // => [{ x: 3, y: 4, owner: 2, ... }, ...]
export const ownCells = (cells, id) => cells.filter((c) => c.owner === id);

// expandable(cells, id): células vazias (owner 0) adjacentes a alguma
// célula da colônia. São os alvos válidos de expand.
//   cells: array de células
//   id: id da sua colônia
// Devolve array de células, sem repetição.
// Exemplo:
//   for (const alvo of expandable(obs.cells, myId)) { /* candidata a expand */ }
export function expandable(cells, id) {
  const map = cellMap(cells);
  const seen = new Set();
  for (const c of ownCells(cells, id)) {
    for (const [nx, ny] of neighbors4(c.x, c.y)) {
      const n = map.get(key(nx, ny));
      if (n && n.owner === 0) seen.add(key(nx, ny));
    }
  }
  return [...seen].map((k) => map.get(k));
}

// attackable(cells, id): células inimigas adjacentes à colônia. São os
// alvos válidos de attack (confira fortified antes: fortificada aguenta).
//   cells: array de células
//   id: id da sua colônia
// Devolve array de células, sem repetição.
// Exemplo:
//   const fracas = attackable(obs.cells, myId).filter((c) => c.fortified === 0);
export function attackable(cells, id) {
  const map = cellMap(cells);
  const seen = new Set();
  for (const c of ownCells(cells, id)) {
    for (const [nx, ny] of neighbors4(c.x, c.y)) {
      const n = map.get(key(nx, ny));
      if (n && n.owner !== 0 && n.owner !== id) seen.add(key(nx, ny));
    }
  }
  return [...seen].map((k) => map.get(k));
}

// borderCells(cells, id): células próprias com pelo menos um vizinho
// inimigo. É a fronteira da colônia, candidata a fortify.
//   cells: array de células
//   id: id da sua colônia
// Devolve array de células (vazio se nenhum inimigo encosta em você).
// Exemplo:
//   for (const c of borderCells(obs.cells, myId)) { /* candidata a fortify */ }
export function borderCells(cells, id) {
  const map = cellMap(cells);
  return ownCells(cells, id).filter((c) =>
    neighbors4(c.x, c.y).some(([nx, ny]) => {
      const n = map.get(key(nx, ny));
      return n && n.owner !== 0 && n.owner !== id;
    })
  );
}
