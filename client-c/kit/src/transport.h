/* Transporte WebSocket mínimo, POSIX only (Linux, macOS, WSL).
 *
 * O protocolo Slimes é uma linha de texto por frame, ws:// sem TLS, então
 * isto aqui é: TCP + handshake HTTP Upgrade + frames RFC 6455. Não valide
 * o Sec-WebSocket-Accept nem fragmentação: o servidor é o nosso.
 *
 * Nada aqui conhece o protocolo Slimes; só move linhas de texto.
 */
#ifndef SLIMES_TRANSPORT_H
#define SLIMES_TRANSPORT_H

#include <stddef.h>

/* conecta e faz o handshake; devolve o fd (>= 0) ou -1 */
int ws_connect(const char *host, const char *port, const char *path);

/* envia uma linha como frame de texto; 0 ok, -1 erro */
int ws_send_text(int fd, const char *line);

/* recebe a próxima linha de texto em `buf` (terminada em '\0').
 * >0 tamanho, 0 conexão fechada, -1 erro. Responde pings do servidor. */
int ws_recv_text(int fd, char *buf, size_t cap);

void ws_close(int fd);

#endif
