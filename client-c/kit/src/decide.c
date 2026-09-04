/* E3: a sua estratégia. observação -> ação, pura.
 *
 * É O ÚNICO ARQUIVO QUE VOCÊ PRECISA EDITAR para jogar depois do E1 e E2.
 *
 * TODO E3: implemente decide. A observação é o que o seu parse do E1
 * devolveu: obs->cells é um array de Cell ({x, y, terrain, owner,
 * fortified}) com obs->n_cells elementos. my_id é o id da sua colônia
 * (veio no WELCOME). Escreva a ação em `out`: out->kind é "expand",
 * "attack", "fortify" ou "pass", e out->x/out->y as coordenadas
 * (exceto em pass). Dica: snprintf(out->kind, sizeof out->kind, "expand").
 *
 * Os helpers de observation.h já estão prontos e testados:
 * own_cells, expandable (vazias adjacentes), attackable (inimigas
 * adjacentes), border_cells (suas células na fronteira). Use-os.
 *
 * Dica nível 1 (sobrevivência): expanda para células vazias, nunca ataque
 * célula fortificada. Dica nível 2 (expansão + defesa): fortifique
 * fronteiras com inimigo ao lado, ataque inimigos desfortificados.
 *
 * Enquanto o stub estiver aqui a sua colônia só passa a vez.
 */

#include "decide.h"

#include <stdio.h>

#include "observation.h"

void decide(const Msg *obs, int my_id, Action *out) {
  (void)obs;
  (void)my_id;
  snprintf(out->kind, sizeof out->kind, "pass");
  out->x = 0;
  out->y = 0;
}
