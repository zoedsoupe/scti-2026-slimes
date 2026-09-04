# Kit do estudante Slimes (Go)

Cliente **não oficial**, sem suporte do instrutor. Uso por conta e risco: dúvidas sobre este código não serão respondidas em aula. O cliente de referência é o JavaScript, em `../../client-js`.

**Regra de dependências:** o domínio é puro e não conhece rede: `protocol.go`, `observation.go`, `decide.go` e `pending.go` nunca importam nada de infraestrutura. Toda a borda (websocket, ambiente, loop de reconexão) fica em `main.go`, que importa o domínio, nunca o contrário.

Este é o kit do minicurso. Você escreve **três funções puras** (E1 a E3); toda a infraestrutura (conexão, reconexão, envio, retry de pendentes) já está pronta e não deve ser modificada.

## Setup

Você precisa de uma toolchain Go instalada (1.23 ou superior). Depois, na pasta do kit:

```
go mod download
```

## Testes

```
go test ./...
```

Os exercícios começam vermelhos; os testes ficam verdes conforme você implementa.

## Os exercícios

| exercício | arquivo | função |
|---|---|---|
| E1 | `protocol.go` | `ParseObservation(line)` |
| E2 | `protocol.go` | `EncodeAction(action, ref)` |
| E3 | `decide.go` | `Decide(obs, myID)` |

Cada stub tem um comentário TODO com o formato esperado. Os testes de cada exercício vivem em `protocol_test.go` (E1, E2) e `decide_test.go` (E3).

## O que não modificar

- `main.go`: loop do cliente, conexão e reconexão.
- `pending.go`: política de retry dos envios pendentes (ACK/NACK/timeout).
- `observation.go`: helpers prontos para a sua estratégia (`Expandable`, `Attackable`, `BorderCells`).
- `protocol.go`: só as funções E1 e E2 são suas; o resto do arquivo é infra pronta.

## Conectar ao servidor

O endereço padrão é `ws://localhost:4000/ws`. Duas variáveis de ambiente controlam a conexão:

- `SLIMES_URL`: endereço do websocket do servidor.
- `SLIMES_NAME`: nome da sua colônia (`[a-z0-9-]{1,16}`).

```
SLIMES_URL=ws://<ip-do-instrutor>:4000/ws SLIMES_NAME=aurora go run .
```

Se a conexão cair, o cliente reconecta após 1 segundo com o mesmo nome. O servidor retoma colônias vivas pelo nome.

## O pipeline (leia no `run` de `main.go`)

```
linha do socket
|> ParseLine()      (PURO: linha -> mensagem de domínio)   <- E1 é aqui
|> Decide()         (PURO: observação -> ação)             <- E3 é aqui
|> EncodeAction()   (PURO: ação -> linha)                  <- E2 é aqui
|> send()           (EFEITO: o único passo com efeito)
```

## Protocolo

O contrato do exercício (E1 a E3) está em `../../docs/PROTOCOL.md`.
