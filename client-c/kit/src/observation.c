#include "observation.h"

/* adjacência ortogonal (a regra de bad_cell do servidor usa a mesma) */
static const int DX[4] = {1, -1, 0, 0};
static const int DY[4] = {0, 0, 1, -1};

const Cell *cell_at(const Cell cells[], int n, int x, int y) {
  int i;
  for (i = 0; i < n; i++) {
    if (cells[i].x == x && cells[i].y == y)
      return &cells[i];
  }
  return NULL;
}

int own_cells(const Cell cells[], int n, int my_id, Cell out[], int max) {
  int i, m = 0;
  for (i = 0; i < n && m < max; i++) {
    if (cells[i].owner == my_id)
      out[m++] = cells[i];
  }
  return m;
}

static int contains(const Cell out[], int m, int x, int y) {
  int i;
  for (i = 0; i < m; i++) {
    if (out[i].x == x && out[i].y == y)
      return 1;
  }
  return 0;
}

/* células adjacentes à colônia que passam no predicado `target`, sem repetir */
static int adjacent(const Cell cells[], int n, int my_id, Cell out[], int max,
                    int (*target)(const Cell *, int my_id)) {
  int i, k, m = 0;
  for (i = 0; i < n; i++) {
    if (cells[i].owner != my_id)
      continue;
    for (k = 0; k < 4; k++) {
      int x = cells[i].x + DX[k];
      int y = cells[i].y + DY[k];
      const Cell *nb = cell_at(cells, n, x, y);
      if (nb && target(nb, my_id) && !contains(out, m, x, y) && m < max)
        out[m++] = *nb;
    }
  }
  return m;
}

static int is_empty(const Cell *c, int my_id) {
  (void)my_id;
  return c->owner == 0;
}

static int is_enemy(const Cell *c, int my_id) {
  return c->owner != 0 && c->owner != my_id;
}

int expandable(const Cell cells[], int n, int my_id, Cell out[], int max) {
  return adjacent(cells, n, my_id, out, max, is_empty);
}

int attackable(const Cell cells[], int n, int my_id, Cell out[], int max) {
  return adjacent(cells, n, my_id, out, max, is_enemy);
}

int border_cells(const Cell cells[], int n, int my_id, Cell out[], int max) {
  int i, k, m = 0;
  for (i = 0; i < n && m < max; i++) {
    if (cells[i].owner != my_id)
      continue;
    for (k = 0; k < 4; k++) {
      const Cell *nb = cell_at(cells, n, cells[i].x + DX[k], cells[i].y + DY[k]);
      if (nb && is_enemy(nb, my_id)) {
        out[m++] = cells[i];
        break;
      }
    }
  }
  return m;
}
