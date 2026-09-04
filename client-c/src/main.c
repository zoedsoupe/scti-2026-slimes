/* Loop do cliente: conecta, cumprimenta, e a cada OBS decide e age.
 *
 * Uso:
 *     make
 *     SLIMES_URL=ws://localhost:4000/ws SLIMES_NAME=aurora ./slimes
 *
 * Este arquivo é a casca: é o único lugar que toca em socket. O pipeline é
 * linha -> parse_line (puro) -> decide (puro) -> encode_action (puro) ->
 * ws_send_text (efeito).
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "decide.h"
#include "protocol.h"
#include "transport.h"

static Msg msg;                  /* grande demais para a pilha */
static char buf[256 * 1024];     /* uma linha do protocolo */

static int run(const char *host, const char *port, const char *path, const char *name) {
  Refs refs;
  char ref[MAX_REF];
  char line[512];
  int fd, my_id = -1, len;

  fd = ws_connect(host, port, path);
  if (fd < 0) {
    printf("falha ao conectar em %s:%s%s\n", host, port, path);
    return -1;
  }

  /* HELLO é a primeira mensagem do socket, enviada uma vez */
  refs_init(&refs, name);
  refs_next(&refs, ref);
  encode_hello(line, sizeof line, ref, name);
  if (ws_send_text(fd, line) < 0) {
    ws_close(fd);
    return -1;
  }

  while ((len = ws_recv_text(fd, buf, sizeof buf - 1)) > 0) {
    if (parse_line(buf, &msg) != 0) {
      printf("linha malformada: %s\n", msg.error);
      continue;
    }

    switch (msg.type) {
    case MSG_WELCOME:
      my_id = msg.id;
      printf("entrei como %s (id %d), cor #%s\n", msg.name, msg.id, msg.color);
      break;
    case MSG_OBS:
      if (strcmp(msg.status, "alive") == 0 && my_id > 0) {
        Action action;
        decide(&msg, my_id, &action);
        refs_next(&refs, ref);
        encode_action(line, sizeof line, &action, ref);
        if (ws_send_text(fd, line) < 0)
          goto out;
      }
      break;
    case MSG_NACK:
      printf("NACK %s: %s\n", msg.code, msg.detail);
      break;
    case MSG_ERR:
      printf("ERR %s: %s\n", msg.code, msg.detail);
      break;
    default:
      break; /* ACK, SCORE, PONG: só constam */
    }
  }

out:
  ws_close(fd);
  return 0;
}

/* ws://host:porta/caminho -> partes; defaults do minicurso */
static void parse_url(const char *url, char *host, size_t hcap, char *port,
                      size_t pcap, char *path, size_t tcap) {
  const char *p = url, *slash, *colon;

  if (strncmp(p, "ws://", 5) == 0)
    p += 5;
  slash = strchr(p, '/');
  colon = strchr(p, ':');

  if (colon && (!slash || colon < slash)) {
    snprintf(host, hcap, "%.*s", (int)(colon - p), p);
    snprintf(port, pcap, "%.*s",
             slash ? (int)(slash - colon - 1) : (int)strlen(colon + 1), colon + 1);
  } else {
    snprintf(host, hcap, "%.*s", slash ? (int)(slash - p) : (int)strlen(p), p);
    snprintf(port, pcap, "4000");
  }
  snprintf(path, tcap, "%s", slash ? slash : "/ws");
}

int main(void) {
  const char *url = getenv("SLIMES_URL");
  const char *name = getenv("SLIMES_NAME");
  char host[128], port[8], path[128];

  if (!url)
    url = "ws://localhost:4000/ws";
  if (!name)
    name = "cslime";

  parse_url(url, host, sizeof host, port, sizeof port, path, sizeof path);

  /* o servidor retoma a colônia viva pelo nome, então reconectar com o
   * mesmo SLIMES_NAME continua a partida */
  for (;;) {
    run(host, port, path, name);
    printf("conexão fechada; tentando de novo em 1s\n");
    sleep(1);
  }
  return 0;
}
