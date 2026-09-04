#include "transport.h"

#include <netdb.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

/* chave fixa: o RFC só exige um base64 de 16 bytes qualquer, e não
 * validamos o Accept do servidor, então SHA-1/base64 não são necessários */
#define WS_KEY "dGhlIHNhbXBsZSBub25jZQ=="

/* máscara fixa: o RFC exige frames mascarados do cliente, mas o valor da
 * chave é arbitrário */
static const unsigned char MASK[4] = {0x53, 0x6c, 0x69, 0x6d}; /* "Slim" */

static int write_all(int fd, const void *buf, size_t len) {
  const char *p = buf;
  while (len > 0) {
    ssize_t n = send(fd, p, len, 0);
    if (n <= 0)
      return -1;
    p += n;
    len -= (size_t)n;
  }
  return 0;
}

static int read_full(int fd, void *buf, size_t len) {
  char *p = buf;
  while (len > 0) {
    ssize_t n = recv(fd, p, len, 0);
    if (n <= 0)
      return -1;
    p += n;
    len -= (size_t)n;
  }
  return 0;
}

static int tcp_connect(const char *host, const char *port) {
  struct addrinfo hints, *res, *rp;
  int fd = -1;

  memset(&hints, 0, sizeof hints);
  hints.ai_family = AF_UNSPEC;
  hints.ai_socktype = SOCK_STREAM;

  if (getaddrinfo(host, port, &hints, &res) != 0)
    return -1;
  for (rp = res; rp; rp = rp->ai_next) {
    fd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
    if (fd < 0)
      continue;
    if (connect(fd, rp->ai_addr, rp->ai_addrlen) == 0)
      break;
    close(fd);
    fd = -1;
  }
  freeaddrinfo(res);
  return fd;
}

int ws_connect(const char *host, const char *port, const char *path) {
  char req[1024];
  char hdr[8192];
  size_t used = 0;
  int fd = tcp_connect(host, port);

  if (fd < 0)
    return -1;

  snprintf(req, sizeof req,
           "GET %s HTTP/1.1\r\n"
           "Host: %s:%s\r\n"
           "Upgrade: websocket\r\n"
           "Connection: Upgrade\r\n"
           "Sec-WebSocket-Key: %s\r\n"
           "Sec-WebSocket-Version: 13\r\n"
           "\r\n",
           path, host, port, WS_KEY);
  if (write_all(fd, req, strlen(req)) < 0)
    goto fail;

  /* lê os headers um byte por vez até \r\n\r\n, para não engolir o
   * primeiro frame caso ele venha no mesmo segmento TCP */
  while (used + 1 < sizeof hdr) {
    if (read_full(fd, hdr + used, 1) < 0)
      goto fail;
    used++;
    if (used >= 4 && memcmp(hdr + used - 4, "\r\n\r\n", 4) == 0)
      break;
  }
  hdr[used] = '\0';
  if (used < 12 || hdr[8] != ' ' || memcmp(hdr + 9, "101", 3) != 0)
    goto fail; /* upgrade recusado */
  return fd;

fail:
  close(fd);
  return -1;
}

/* monta e envia um frame (opcode dado) já mascarado */
static int send_frame(int fd, int opcode, const void *payload, size_t len) {
  unsigned char header[14];
  size_t hlen = 0, i;

  header[hlen++] = (unsigned char)(0x80 | opcode); /* FIN + opcode */
  if (len < 126) {
    header[hlen++] = (unsigned char)(0x80 | len);
  } else if (len <= 0xFFFF) {
    header[hlen++] = (unsigned char)(0x80 | 126);
    header[hlen++] = (unsigned char)(len >> 8);
    header[hlen++] = (unsigned char)(len & 0xFF);
  } else {
    header[hlen++] = (unsigned char)(0x80 | 127);
    for (i = 0; i < 8; i++)
      header[hlen++] = (unsigned char)((len >> (56 - 8 * i)) & 0xFF);
  }
  memcpy(header + hlen, MASK, 4);
  hlen += 4;

  if (write_all(fd, header, hlen) < 0)
    return -1;

  /* payload pequeno o bastante para mascarar num buffer de pilha por pedaços */
  {
    unsigned char chunk[4096];
    size_t off = 0;
    while (off < len) {
      size_t n = len - off < sizeof chunk ? len - off : sizeof chunk;
      for (i = 0; i < n; i++)
        chunk[i] = ((const unsigned char *)payload)[off + i] ^ MASK[(off + i) % 4];
      if (write_all(fd, chunk, n) < 0)
        return -1;
      off += n;
    }
  }
  return 0;
}

int ws_send_text(int fd, const char *line) {
  return send_frame(fd, 0x1, line, strlen(line));
}

/* descarta `len` bytes do socket (frames que não interessam) */
static int drain(int fd, unsigned long long len) {
  unsigned char buf[4096];
  while (len > 0) {
    size_t n = len < sizeof buf ? (size_t)len : sizeof buf;
    if (read_full(fd, buf, n) < 0)
      return -1;
    len -= n;
  }
  return 0;
}

int ws_recv_text(int fd, char *buf, size_t cap) {
  for (;;) {
    unsigned char h[2];
    unsigned char mask[4] = {0, 0, 0, 0};
    unsigned long long len;
    int opcode, masked, i;

    if (read_full(fd, h, 2) < 0)
      return 0; /* conexão caiu */

    opcode = h[0] & 0x0F;
    masked = h[1] & 0x80;
    len = h[1] & 0x7F;

    if (len == 126) {
      unsigned char ext[2];
      if (read_full(fd, ext, 2) < 0)
        return -1;
      len = ((unsigned long long)ext[0] << 8) | ext[1];
    } else if (len == 127) {
      unsigned char ext[8];
      len = 0;
      if (read_full(fd, ext, 8) < 0)
        return -1;
      for (i = 0; i < 8; i++)
        len = (len << 8) | ext[i];
    }
    if (masked && read_full(fd, mask, 4) < 0)
      return -1;

    if (opcode == 0x8) /* close */
      return 0;

    if (opcode == 0x9) { /* ping -> pong com o mesmo payload */
      unsigned char p[125];
      if (len > sizeof p || read_full(fd, p, (size_t)len) < 0)
        return -1;
      if (masked)
        for (i = 0; i < (int)len; i++)
          p[i] ^= mask[i % 4];
      if (send_frame(fd, 0xA, p, (size_t)len) < 0)
        return -1;
      continue;
    }

    if (opcode == 0x1 || opcode == 0x0) { /* texto (ou continuação) */
      size_t n;
      if (len >= cap) {
        drain(fd, len);
        return -1; /* linha grande demais para o buffer do chamador */
      }
      n = (size_t)len;
      if (read_full(fd, buf, n) < 0)
        return -1;
      if (masked)
        for (i = 0; i < (int)n; i++)
          buf[i] ^= mask[i % 4];
      buf[n] = '\0';
      return (int)n;
    }

    /* pong e opcodes desconhecidos: ignora o payload */
    if (drain(fd, len) < 0)
      return -1;
  }
}

void ws_close(int fd) {
  close(fd);
}
