/* Helpers puros sobre uma observação (a visão que chega a cada tick).
 * Nada aqui conhece socket ou rede.
 *
 * Todos devolvem quantas células escreveram em `out` (no máximo `max`).
 * A visão é pequena, então a busca é linear mesmo.
 */
#ifndef SLIMES_OBSERVATION_H
#define SLIMES_OBSERVATION_H

#include "protocol.h"

/* célula em (x, y) ou NULL se fora da visão */
const Cell *cell_at(const Cell cells[], int n, int x, int y);

int own_cells(const Cell cells[], int n, int my_id, Cell out[], int max);

/* células vazias adjacentes a alguma célula da colônia: alvos de expand */
int expandable(const Cell cells[], int n, int my_id, Cell out[], int max);

/* células inimigas adjacentes à colônia: alvos de attack */
int attackable(const Cell cells[], int n, int my_id, Cell out[], int max);

/* células próprias com vizinho inimigo: fronteira, candidatas a fortify */
int border_cells(const Cell cells[], int n, int my_id, Cell out[], int max);

#endif
