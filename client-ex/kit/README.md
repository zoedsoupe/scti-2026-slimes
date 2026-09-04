# Kit do estudante Slimes (Elixir)

Cliente **não oficial**, sem suporte do instrutor. Uso por conta e risco: dúvidas sobre este código não serão respondidas em aula nem depois dela.

**Regra de dependências:** o domínio (`Protocol`, `Observation`, `Decide`, `Pending`) é puro e nunca conhece rede. Só a casca (`Client`, o processo WebSockex) toca em socket.

Este é o kit do minicurso. Você escreve **três funções puras** (E1 a E3); toda a infraestrutura (conexão, reconexão, envio, retry) já está pronta e não deve ser modificada.

## Setup

```
mix deps.get
```

## Testes

```
mix test
```

Os exercícios começam vermelhos; os testes ficam verdes conforme você implementa.

## Os exercícios

| exercício | arquivo | função |
|---|---|---|
| E1 | `lib/slimes_client/protocol.ex` | `parse_observation/1` |
| E2 | `lib/slimes_client/protocol.ex` | `encode_action/2` |
| E3 | `lib/slimes_client/decide.ex` | `decide/2` |

Cada stub tem um comentário TODO com o formato esperado. Os testes de cada exercício vivem em `test/protocol_test.exs` (E1, E2) e `test/decide_test.exs` (E3).

## Conectar ao servidor

O servidor precisa estar rodando (veja o WORKSHOP.md). Depois:

```
SLIMES_URL=ws://<ip-do-instrutor>:4000/ws SLIMES_NAME=aurora mix run --no-halt -e SlimesClient.Client.main
```

Sem as variáveis de ambiente, o padrão é `ws://localhost:4000/ws` e o nome `exslime`. Se a conexão cair, o cliente reconecta sozinho e entra de novo com o mesmo nome; o servidor retoma a colônia se ela ainda estiver viva.

## O pipeline (leia no `dispatch` de `lib/slimes_client/client.ex`)

```
linha do socket
|> Protocol.parse_line()   (PURO: linha -> mensagem de domínio tagueada)
|> Decide.decide()         (PURO: observação -> ação)   <- E3 é aqui
|> Protocol.encode_action() (PURO: ação -> linha)
|> WebSockex reply          (EFEITO: o único passo com efeito)
```

## Protocolo

O contrato do exercício (E1 a E3) está no PROTOCOL.md ao lado deste README.
