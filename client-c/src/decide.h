/* Estratégia: observação -> ação, pura.
 *
 * É O ÚNICO ARQUIVO QUE VOCÊ PRECISA EDITAR para jogar (depois do E1 e E2).
 */
#ifndef SLIMES_DECIDE_H
#define SLIMES_DECIDE_H

#include "protocol.h"

void decide(const Msg *obs, int my_id, Action *out);

#endif
