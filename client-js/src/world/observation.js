// Helpers puros sobre uma observação (a visão 7x7 que chega a cada tick).
// Nada aqui conhece socket, canvas ou rede.

export const key = (x, y) => `${x},${y}`;

// mapa "x,y" -> célula, para consulta O(1)
export function cellMap(cells) {
  return new Map(cells.map((c) => [key(c.x, c.y), c]));
}

// adjacência ortogonal (a regra de bad_cell do servidor usa a mesma)
export const neighbors4 = (x, y) => [
  [x + 1, y],
  [x - 1, y],
  [x, y + 1],
  [x, y - 1],
];

export const ownCells = (cells, id) => cells.filter((c) => c.owner === id);

// células vazias adjacentes a alguma célula da colônia: alvos de expand
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

// células inimigas adjacentes à colônia: alvos de attack
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

// células próprias com vizinho inimigo: fronteira, candidatas a fortify
export function borderCells(cells, id) {
  const map = cellMap(cells);
  return ownCells(cells, id).filter((c) =>
    neighbors4(c.x, c.y).some(([nx, ny]) => {
      const n = map.get(key(nx, ny));
      return n && n.owner !== 0 && n.owner !== id;
    })
  );
}
