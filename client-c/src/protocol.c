#include "protocol.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

/* buffer de tokenização: parse_* destroem uma cópia da linha.
 * ponytail: static, o cliente é single-thread */
#define SCRATCH (256 * 1024)

static const char ALPHA[] = "abcdefghijklmnopqrstuvwxyz0123456789";

/* --- encode --------------------------------------------------------------- */

void refs_init_session(Refs *refs, const char *name, const char *session) {
  snprintf(refs->name, sizeof refs->name, "%s", name);
  snprintf(refs->session, sizeof refs->session, "%s", session);
  refs->n = 0;
}

void refs_init(Refs *refs, const char *name) {
  char session[5];
  int i;
  srand((unsigned)(time(NULL) ^ ((long)getpid() << 16)));
  for (i = 0; i < 4; i++)
    session[i] = ALPHA[rand() % (sizeof ALPHA - 1)];
  session[4] = '\0';
  refs_init_session(refs, name, session);
}

void refs_next(Refs *refs, char out[MAX_REF]) {
  snprintf(out, MAX_REF, "%s-%s-%ld", refs->name, refs->session, ++refs->n);
}

void encode_hello(char *out, size_t cap, const char *ref, const char *name) {
  snprintf(out, cap, "HELLO v1 %s colony %s", ref, name);
}

void encode_action(char *out, size_t cap, const Action *action, const char *ref) {
  if (strcmp(action->kind, "pass") == 0) {
    snprintf(out, cap, "ACT %s pass", ref);
  } else {
    snprintf(out, cap, "ACT %s %s %d %d", ref, action->kind, action->x, action->y);
  }
}

void encode_ping(char *out, size_t cap, const char *ref) {
  snprintf(out, cap, "PING %s", ref);
}

/* --- parse ---------------------------------------------------------------- */

static int err(Msg *out, const char *reason) {
  out->type = MSG_ERROR;
  snprintf(out->error, sizeof out->error, "%s", reason);
  return -1;
}

/* inteiros base-10; qualquer outra coisa torna a linha malformada.
 * Rejeita "+5" e lixo depois do número, como os outros clientes. */
static int to_int(const char *s, long *out) {
  char *end;
  long v;
  if (!s || !*s || *s == '+')
    return -1;
  v = strtol(s, &end, 10);
  if (end == s || *end != '\0')
    return -1;
  *out = v;
  return 0;
}

/* divide `s` in-place por `delim`; devolve quantos tokens couberam em `toks` */
static int split(char *s, char delim, char *toks[], int max) {
  int n = 0;
  toks[n++] = s;
  for (; *s && n < max; s++) {
    if (*s == delim) {
      *s = '\0';
      toks[n++] = s + 1;
    }
  }
  return n;
}

/* célula: x,y,terrain,owner,fortified (campos extras na célula ignorados) */
int parse_cell(const char *tok, Cell *out) {
  char buf[64];
  char *f[8];
  long x, y, owner, fortified;

  if (strlen(tok) >= sizeof buf)
    return -1;
  strcpy(buf, tok);
  if (split(buf, ',', f, 8) < 5)
    return -1;
  if (to_int(f[0], &x) || to_int(f[1], &y) || to_int(f[3], &owner) ||
      to_int(f[4], &fortified))
    return -1;

  out->x = (int)x;
  out->y = (int)y;
  snprintf(out->terrain, sizeof out->terrain, "%s", f[2]);
  out->owner = (int)owner;
  out->fortified = (int)fortified;
  return 0;
}

/* tok já tokenizado in-place; NULL ou "" = lista vazia */
static int parse_cells(char *tok, Msg *out) {
  char *items[MAX_CELLS];
  int n, i;

  if (!tok || !*tok) {
    out->n_cells = 0;
    return 0;
  }
  n = split(tok, ';', items, MAX_CELLS);
  for (i = 0; i < n; i++) {
    if (parse_cell(items[i], &out->cells[i]))
      return -1;
  }
  out->n_cells = n;
  return 0;
}

/* E1: uma linha OBS crua -> observação de domínio. */
int parse_observation(const char *line, Msg *out) {
  static char buf[SCRATCH];
  char *t[8];
  long tick, scores_tick;
  int n;

  if (strlen(line) >= sizeof buf)
    return err(out, "linha longa demais");
  strcpy(buf, line);

  n = split(buf, ' ', t, 8);
  if (n < 5 || strcmp(t[0], "OBS") != 0)
    return err(out, "nao e uma linha OBS");
  if (to_int(t[2], &tick) || to_int(t[4], &scores_tick))
    return err(out, "tick ausente ou invalido");
  if (strcmp(t[3], "alive") != 0 && strcmp(t[3], "dead") != 0)
    return err(out, "status invalido");

  out->type = MSG_OBS;
  snprintf(out->ref, sizeof out->ref, "%s", t[1]);
  out->tick = tick;
  snprintf(out->status, sizeof out->status, "%s", t[3]);
  out->scores_tick = scores_tick;
  /* n >= 6 ? t[5] : lista vazia; tokens além de t[5] ignorados (leitor
   * tolerante: é o que salva o cliente no drill da v2) */
  if (parse_cells(n >= 6 ? t[5] : NULL, out))
    return err(out, "lista de celulas malformada");
  return 0;
}

/* WELCOME srv-0 3 aurora 96CDFB 60 40 1000 3 4,34 (só colônia) */
static int parse_welcome(char *buf, Msg *out) {
  char *t[12];
  char *spawn[4];
  long id, w, h, tick_ms, view_radius, sx, sy;

  if (split(buf, ' ', t, 12) < 10)
    return err(out, "welcome malformado");
  if (strcmp(t[2], "spectator") == 0)
    return err(out, "este cliente so joga como colonia");
  if (to_int(t[2], &id) || to_int(t[5], &w) || to_int(t[6], &h) ||
      to_int(t[7], &tick_ms) || to_int(t[8], &view_radius))
    return err(out, "welcome malformado");
  if (split(t[9], ',', spawn, 4) < 2 || to_int(spawn[0], &sx) || to_int(spawn[1], &sy))
    return err(out, "spawn malformado");

  out->type = MSG_WELCOME;
  out->id = (int)id;
  snprintf(out->name, sizeof out->name, "%s", t[3]);
  snprintf(out->color, sizeof out->color, "%s", t[4]);
  out->w = (int)w;
  out->h = (int)h;
  out->tick_ms = (int)tick_ms;
  out->view_radius = (int)view_radius;
  out->spawn_x = (int)sx;
  out->spawn_y = (int)sy;
  return 0;
}

static int parse_ack(char *buf, Msg *out) {
  char *t[4];
  long tick;

  if (split(buf, ' ', t, 4) < 3 || to_int(t[2], &tick))
    return err(out, "ack sem tick");

  out->type = MSG_ACK;
  snprintf(out->ref, sizeof out->ref, "%s", t[1]);
  out->tick = tick;
  return 0;
}

/* NACK/ERR <ref> <code> <texto livre até o fim da linha> */
static int parse_nack(char *buf, Msg *out, MsgType type) {
  char *t[16];
  int n, i;
  size_t len = 0;

  n = split(buf, ' ', t, 16);
  if (n < 3)
    return err(out, "nack/err malformado");

  out->type = type;
  snprintf(out->ref, sizeof out->ref, "%s", t[1]);
  snprintf(out->code, sizeof out->code, "%s", t[2]);
  out->detail[0] = '\0';
  for (i = 3; i < n && len + 1 < sizeof out->detail; i++) {
    int wrote = snprintf(out->detail + len, sizeof out->detail - len, "%s%s",
                         i > 3 ? " " : "", t[i]);
    if (wrote < 0)
      break;
    len += (size_t)wrote < sizeof out->detail - len ? (size_t)wrote
                                                    : sizeof out->detail - len - 1;
  }
  return 0;
}

static int parse_score(char *buf, Msg *out) {
  char *t[4];
  char *entries[MAX_SCORE_ENTRIES];
  long tick;
  int n, i;

  if (split(buf, ' ', t, 4) < 3 || to_int(t[2], &tick))
    return err(out, "score sem tick");

  out->type = MSG_SCORE;
  snprintf(out->ref, sizeof out->ref, "%s", t[1]);
  out->tick = tick;
  out->n_entries = 0;

  n = t[3] ? split(t[3], ';', entries, MAX_SCORE_ENTRIES) : 0;
  for (i = 0; i < n; i++) {
    char *f[5];
    long id, cells;
    if (!*entries[i])
      continue;
    if (split(entries[i], ',', f, 5) < 4 || to_int(f[0], &id) || to_int(f[2], &cells))
      return err(out, "score malformado");
    out->entries[out->n_entries].id = (int)id;
    snprintf(out->entries[out->n_entries].name, MAX_NAME, "%s", f[1]);
    out->entries[out->n_entries].cells = (int)cells;
    snprintf(out->entries[out->n_entries].status, 8, "%s", f[3]);
    out->n_entries++;
  }
  return 0;
}

int parse_line(const char *line, Msg *out) {
  static char buf[SCRATCH];

  if (strlen(line) >= sizeof buf)
    return err(out, "linha longa demais");
  strcpy(buf, line);

  if (strncmp(buf, "OBS ", 4) == 0)
    return parse_observation(line, out);
  if (strncmp(buf, "WELCOME ", 8) == 0)
    return parse_welcome(buf, out);
  if (strncmp(buf, "ACK ", 4) == 0)
    return parse_ack(buf, out);
  if (strncmp(buf, "NACK ", 5) == 0)
    return parse_nack(buf, out, MSG_NACK);
  if (strncmp(buf, "ERR ", 4) == 0)
    return parse_nack(buf, out, MSG_ERR);
  if (strncmp(buf, "SCORE ", 6) == 0)
    return parse_score(buf, out);
  if (strncmp(buf, "PONG", 4) == 0) {
    char *t[3];
    out->type = MSG_PONG;
    if (split(buf, ' ', t, 3) >= 2)
      snprintf(out->ref, sizeof out->ref, "%s", t[1]);
    return 0;
  }
  return err(out, "tipo desconhecido");
}
