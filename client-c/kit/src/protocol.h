/* Parse e encode das linhas do protocolo, na fronteira.
 *
 * Regra do PROTOCOL.md: tokens extras no final são ignorados (leitor
 * tolerante), linha malformada devolve -1 com motivo em Msg.error e nunca
 * derruba o cliente. Refs: <nome>-<sessão>-<n>, sessão de 4 chars gerada
 * uma vez por processo.
 *
 * Este cliente só joga como colônia (sem modo espectador).
 */
#ifndef SLIMES_PROTOCOL_H
#define SLIMES_PROTOCOL_H

#include <stddef.h>

#define MAX_CELLS 4096
#define MAX_REF 64
#define MAX_NAME 32
#define MAX_SCORE_ENTRIES 64

/* célula da grade: x,y,terrain,owner,fortified */
typedef struct {
  int x, y;
  char terrain[8];
  int owner;
  int fortified;
} Cell;

/* ação de domínio: kind é "expand", "attack", "fortify" ou "pass" */
typedef struct {
  char kind[8];
  int x, y; /* ignorados em pass */
} Action;

typedef struct {
  int id;
  char name[MAX_NAME];
  int cells;
  char status[8];
} ScoreEntry;

typedef enum {
  MSG_ERROR = 0, /* linha malformada; motivo em `error` */
  MSG_OBS,
  MSG_WELCOME,
  MSG_ACK,
  MSG_NACK,
  MSG_ERR,
  MSG_SCORE,
  MSG_PONG
} MsgType;

/* Struct grande (~100KB por causa de cells): declare como static ou global,
 * nunca na pilha. */
typedef struct {
  MsgType type;
  char error[160];   /* MSG_ERROR: motivo */
  char ref[MAX_REF]; /* ref ecoado pelo servidor */

  /* OBS */
  long tick;
  char status[8]; /* "alive" | "dead" */
  long scores_tick;
  Cell cells[MAX_CELLS];
  int n_cells;

  /* WELCOME (colônia) */
  int id;
  char name[MAX_NAME];
  char color[8];
  int w, h, tick_ms, view_radius;
  int spawn_x, spawn_y;

  /* NACK / ERR (ACK usa só ref + tick) */
  char code[32];
  char detail[256];

  /* SCORE */
  ScoreEntry entries[MAX_SCORE_ENTRIES];
  int n_entries;
} Msg;

/* gerador de refs estável por sessão; n cresce a cada refs_next */
typedef struct {
  char name[MAX_NAME];
  char session[5];
  long n;
} Refs;

void refs_init(Refs *refs, const char *name); /* sessão aleatória */
void refs_init_session(Refs *refs, const char *name, const char *session);
void refs_next(Refs *refs, char out[MAX_REF]);

void encode_hello(char *out, size_t cap, const char *ref, const char *name);
void encode_action(char *out, size_t cap, const Action *action, const char *ref);
void encode_ping(char *out, size_t cap, const char *ref);

/* 0 = ok, -1 = malformada (motivo em out->error quando houver Msg) */
int parse_cell(const char *tok, Cell *out);
int parse_observation(const char *line, Msg *out); /* E1 */
int parse_line(const char *line, Msg *out);

#endif
