# Kit do estudante Slimes (C)

Cliente **não oficial**, sem suporte do instrutor. Uso por conta e risco: dúvidas sobre este código não serão respondidas em aula nem depois dela.

**Regra de dependências:** o domínio (`protocol.c`, `observation.c`, `decide.c`) é puro e nunca conhece rede. Só a casca (`main.c`, `transport.c`) toca em socket.

Este é o kit do minicurso. Você escreve **três funções puras** (E1 a E3); toda a infraestrutura (conexão WebSocket, reconexão, envio) já está pronta e não deve ser modificada.

## Setup

Precisa de um compilador C (`cc`/`gcc`/`clang`) e `make`. Linux e macOS funcionam direto; no Windows, use o WSL.

```
make
```

## Testes

```
make test
```

Os exercícios começam vermelhos; os testes ficam verdes conforme você implementa.

## Os exercícios

| exercício | arquivo | função |
|---|---|---|
| E1 | `src/protocol.c` | `parse_observation` |
| E2 | `src/protocol.c` | `encode_action` |
| E3 | `src/decide.c` | `decide` |

Cada stub tem um comentário TODO com o formato esperado. Os testes de cada exercício vivem em `test/test_protocol.c` (E1, E2) e `test/test_decide.c` (E3).

Duas pegadinhas de C para quem vem de outras linguagens:

- `Msg` é grande (~100KB por causa do array de células): declare como `static` ou global, nunca na pilha.
- Tokenizar destrói a string (`split` escreve `'\0'` no lugar dos delimitadores). Copie a linha para um buffer próprio antes de tokenizar — veja como `parse_line` faz.

## Conectar ao servidor

O servidor precisa estar rodando (veja o WORKSHOP.md). Depois:

```
SLIMES_URL=ws://<ip-do-instrutor>:4000/ws SLIMES_NAME=aurora ./slimes
```

Sem as variáveis de ambiente, o padrão é `ws://localhost:4000/ws` e o nome `cslime`. Se a conexão cair, o cliente reconecta sozinho e entra de novo com o mesmo nome; o servidor retoma a colônia se ela ainda estiver viva.

## O pipeline (leia o `run` de `src/main.c`)

```
linha do socket
-> parse_line     (PURO: linha -> mensagem de domínio)
-> decide         (PURO: observação -> ação)   <- E3 é aqui
-> encode_action  (PURO: ação -> linha)
-> ws_send_text   (EFEITO: o único passo com efeito)
```

## Protocolo

O contrato do exercício (E1 a E3) está no PROTOCOL.md ao lado deste README. Este cliente só joga como colônia (sem modo espectador).
