/* Testes de E1 (parse_observation) e E2 (encode_action), mais os parses
 * prontos. Sem framework: CHECK conta e imprime, main devolve != 0 se falhar.
 *
 * Rode com `make test`.
 */

#include <stdio.h>
#include <string.h>

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

static Msg msg; /* grande, fora da pilha */

static void test_welcome(void) {
  CHECK(parse_line("WELCOME srv-0 3 aurora 96CDFB 60 40 1000 3 4,34", &msg) == 0);
  CHECK(msg.type == MSG_WELCOME);
  CHECK(msg.id == 3 && strcmp(msg.name, "aurora") == 0);
  CHECK(strcmp(msg.color, "96CDFB") == 0);
  CHECK(msg.w == 60 && msg.h == 40 && msg.tick_ms == 1000 && msg.view_radius == 3);
  CHECK(msg.spawn_x == 4 && msg.spawn_y == 34);
}

/* E1: estes testes ficam verdes quando parse_observation estiver pronta */
static void test_observation(void) {
  CHECK(parse_line("OBS srv-97 97 alive 97 9,5,plain,0,0;10,5,plain,3,1", &msg) == 0);
  CHECK(msg.type == MSG_OBS);
  CHECK(msg.tick == 97 && strcmp(msg.status, "alive") == 0 && msg.scores_tick == 97);
  CHECK(msg.n_cells == 2);
  if (msg.n_cells == 2) {
    CHECK(msg.cells[0].x == 9 && msg.cells[0].y == 5 && msg.cells[0].owner == 0);
    CHECK(msg.cells[1].owner == 3 && msg.cells[1].fortified == 1);
    CHECK(strcmp(msg.cells[1].terrain, "plain") == 0);
  }

  /* token extra no final é ignorado (drill da v2) */
  CHECK(parse_line("OBS srv-97 97 alive 97 9,5,plain,0,0 campo_extra", &msg) == 0);

  /* célula com sexto campo (v2) também parseia */
  CHECK(parse_cell("9,5,plain,0,0,42", &msg.cells[0]) == 0);

  /* colônia morta, visão vazia */
  CHECK(parse_line("OBS srv-98 98 dead 97", &msg) == 0);
  CHECK(strcmp(msg.status, "dead") == 0 && msg.n_cells == 0);

  /* malformadas viram erro, nunca crash */
  CHECK(parse_line("OBS srv-97 x alive 97", &msg) != 0);
  CHECK(parse_line("OBS srv-97 97 undead 97", &msg) != 0);
  CHECK(parse_line("OBS srv-97 97 alive 97 9,5,plain,0", &msg) != 0);
  CHECK(parse_cell("9,5,plain,0", &msg.cells[0]) != 0);
}

static void test_tolerant_and_malformed(void) {
  CHECK(parse_line("ACK aurora-k3f9-17 97 extra tokens", &msg) == 0);
  CHECK(msg.type == MSG_ACK && msg.tick == 97);
  CHECK(strcmp(msg.ref, "aurora-k3f9-17") == 0);

  CHECK(parse_line("ACTN foo bar", &msg) != 0);
  CHECK(parse_line("WELCOME srv-0 3 aurora 96CDFB 60 40 1000 3", &msg) != 0);
  CHECK(parse_line("ACK ref notanumber", &msg) != 0);
}

static void test_nack_score(void) {
  CHECK(parse_line("NACK aurora-k3f9-17 too_late tick 96 resolvido", &msg) == 0);
  CHECK(msg.type == MSG_NACK && strcmp(msg.code, "too_late") == 0);
  CHECK(strcmp(msg.detail, "tick 96 resolvido") == 0);

  CHECK(parse_line("SCORE srv-97 97 3,aurora,21,alive;5,nova,14,dead", &msg) == 0);
  CHECK(msg.type == MSG_SCORE && msg.tick == 97 && msg.n_entries == 2);
  if (msg.n_entries == 2) {
    CHECK(msg.entries[1].id == 5 && msg.entries[1].cells == 14);
    CHECK(strcmp(msg.entries[1].name, "nova") == 0);
    CHECK(strcmp(msg.entries[1].status, "dead") == 0);
  }
}

/* E2: estes testes ficam verdes quando encode_action estiver pronta */
static void test_encode(void) {
  Refs refs;
  char ref[MAX_REF];
  char line[128];
  Action expand = {"expand", 12, 7};
  Action pass = {"pass", 0, 0};

  refs_init_session(&refs, "aurora", "k3f9");

  refs_next(&refs, ref);
  CHECK(strcmp(ref, "aurora-k3f9-1") == 0);
  encode_hello(line, sizeof line, ref, "aurora");
  CHECK(strcmp(line, "HELLO v1 aurora-k3f9-1 colony aurora") == 0);

  refs_next(&refs, ref);
  CHECK(strcmp(ref, "aurora-k3f9-2") == 0);
  encode_action(line, sizeof line, &expand, ref);
  CHECK(strcmp(line, "ACT aurora-k3f9-2 expand 12 7") == 0);

  /* pass omite as coordenadas */
  refs_next(&refs, ref);
  encode_action(line, sizeof line, &pass, ref);
  CHECK(strcmp(line, "ACT aurora-k3f9-3 pass") == 0);
}

int main(void) {
  test_welcome();
  test_observation();
  test_tolerant_and_malformed();
  test_nack_score();
  test_encode();
  printf("%d verificacoes, %d falhas\n", checks, failures);
  return failures ? 1 : 0;
}
