/* Testes de E3 (decide). Observações fixas; verificam a CLASSE da ação,
 * não a célula exata: a estratégia continua livre.
 *
 * Rode com `make test`.
 */

#include <stdio.h>
#include <string.h>

#include "../src/decide.h"
#include "../src/protocol.h"

static int checks = 0, failures = 0;

#define CHECK(cond)                                                            \
  do {                                                                         \
    checks++;                                                                  \
    if (!(cond)) {                                                             \
      failures++;                                                              \
      printf("FALHOU %s:%d: %s\n", __FILE__, __LINE__, #cond);                 \
    }                                                                          \
  } while (0)

static Msg obs; /* grande, fora da pilha */

static void set_cells(const Cell *cells, int n) {
  memset(&obs, 0, sizeof obs);
  obs.type = MSG_OBS;
  strcpy(obs.status, "alive");
  memcpy(obs.cells, cells, (size_t)n * sizeof(Cell));
  obs.n_cells = n;
}

static Cell cell(int x, int y, int owner, int fortified) {
  Cell c;
  c.x = x;
  c.y = y;
  strcpy(c.terrain, "plain");
  c.owner = owner;
  c.fortified = fortified;
  return c;
}

static void test_attack_weak_enemy(void) {
  Action a;
  Cell cells[] = {cell(5, 5, 1, 0), cell(6, 5, 2, 0)};
  set_cells(cells, 2);
  decide(&obs, 1, &a);
  CHECK(strcmp(a.kind, "attack") == 0);
}

static void test_expand_when_no_enemy(void) {
  Action a;
  Cell cells[] = {cell(5, 5, 1, 0), cell(6, 5, 0, 0)};
  set_cells(cells, 2);
  decide(&obs, 1, &a);
  CHECK(strcmp(a.kind, "expand") == 0);
}

static void test_fortify_against_fortified_enemy(void) {
  Action a;
  /* há inimigos mas todos fortificados: fortifica uma célula de fronteira */
  Cell cells[] = {cell(5, 5, 1, 0), cell(6, 5, 2, 1)};
  set_cells(cells, 2);
  decide(&obs, 1, &a);
  CHECK(strcmp(a.kind, "fortify") == 0);
}

static void test_pass_when_surrounded(void) {
  Action a;
  Cell cells[] = {cell(5, 5, 1, 0), cell(4, 5, 1, 0), cell(6, 5, 1, 0),
                  cell(5, 4, 1, 0), cell(5, 6, 1, 0)};
  set_cells(cells, 5);
  decide(&obs, 1, &a);
  CHECK(strcmp(a.kind, "pass") == 0);
}

int main(void) {
  test_attack_weak_enemy();
  test_expand_when_no_enemy();
  test_fortify_against_fortified_enemy();
  test_pass_when_surrounded();
  printf("%d verificacoes, %d falhas\n", checks, failures);
  return failures ? 1 : 0;
}
