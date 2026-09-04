/* Estratégia de referência. observação -> ação, pura.
 *
 * Prioridade: ataca inimigo desfortificado adjacente; fortifica fronteira
 * sob ameaça; expande na direção do inimigo mais próximo; senão passa.
 */

#include "decide.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "observation.h"

static int dist(const Cell *a, const Cell *b) {
  return abs(a->x - b->x) + abs(a->y - b->y);
}

static void set_action(Action *out, const char *kind, int x, int y) {
  snprintf(out->kind, sizeof out->kind, "%s", kind);
  out->x = x;
  out->y = y;
}

void decide(const Msg *obs, int my_id, Action *out) {
  static Cell enemies[256], border[256], targets[512];
  int n_enemies, n_border, n_targets, i, j;

  n_enemies = attackable(obs->cells, obs->n_cells, my_id, enemies, 256);

  for (i = 0; i < n_enemies; i++) {
    if (enemies[i].fortified == 0) {
      set_action(out, "attack", enemies[i].x, enemies[i].y);
      return;
    }
  }

  n_border = border_cells(obs->cells, obs->n_cells, my_id, border, 256);
  if (n_border > 0 && n_enemies > 0) {
    for (i = 0; i < n_border; i++) {
      if (border[i].fortified == 0) {
        set_action(out, "fortify", border[i].x, border[i].y);
        return;
      }
    }
  }

  n_targets = expandable(obs->cells, obs->n_cells, my_id, targets, 512);
  if (n_targets > 0) {
    /* insertion sort por distância ao inimigo mais próximo conhecido */
    for (i = 1; i < n_targets; i++) {
      Cell tmp = targets[i];
      int d = n_enemies > 0 ? dist(&tmp, &enemies[0]) : 0;
      for (j = i - 1; j >= 0; j--) {
        int dj = n_enemies > 0 ? dist(&targets[j], &enemies[0]) : 0;
        if (dj <= d)
          break;
        targets[j + 1] = targets[j];
      }
      targets[j + 1] = tmp;
    }
    set_action(out, "expand", targets[0].x, targets[0].y);
    return;
  }

  set_action(out, "pass", 0, 0);
}
