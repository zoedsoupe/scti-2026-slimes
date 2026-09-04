# client-c: scaffold bônus em C

Este cliente **não é suportado**: uso por conta e risco, sem direito a debug do instrutor. O cliente de referência do minicurso é o JavaScript em `client-js/`; este scaffold existe para quem já se vira sozinho em C.

A versão completa e funcional fica nesta pasta. `kit/` é a versão do estudante, com os stubs de E1 a E3 (vai parar no `student-kit.zip`).

## Regra de dependência

O domínio puro (`protocol.c`, `observation.c`, `decide.c`) nunca inclui infraestrutura: nada de socket, rede ou tempo ali dentro. Só `main.c` e `transport.c` tocam no websocket. Se você sentir vontade de incluir `transport.h` dentro de `decide.c`, pare: a decisão é pura, o efeito mora na borda.

Zero dependências externas: stdlib C99 + sockets POSIX. Linux e macOS funcionam direto; no Windows, use o WSL. Só `ws://` (sem TLS), que é o que o minicurso usa.

## Build e testes

```
make        # compila o cliente (./slimes)
make test   # testes do parser (E1, E2) e da estratégia (E3), assert puro
```

## Conectar no servidor real

```
./slimes
```

Por padrão conecta em `ws://localhost:4000/ws` com o nome `cslime`. Para mudar:

```
SLIMES_URL=ws://192.168.0.10:4000/ws SLIMES_NAME=aurora ./slimes
```

O servidor retoma uma colônia viva pelo nome, então reconectar com o mesmo `SLIMES_NAME` continua a partida.

## Notas de implementação

- `transport.c` é um cliente WebSocket mínimo: handshake com chave fixa (não validamos o `Sec-WebSocket-Accept`), frames mascarados com chave fixa, responde pings do servidor. Não é um cliente WS genérico; é o suficiente para o Slimes.
- `Msg` é grande (~100KB): sempre `static`, nunca na pilha.
- Só joga como colônia (sem modo espectador, sem `DIFF`).

## O contrato

O exercício (E1 a E3) está descrito em `../docs/PROTOCOL.md`, que no zip do kit fica ao lado desta pasta. Leia ele antes de mexer em `decide.c`, que é o único arquivo que você precisa editar para jogar.
