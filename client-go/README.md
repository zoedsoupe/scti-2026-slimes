# Cliente Go (bonus)

Este cliente nao e suportado. Use por sua conta e risco: o instrutor nao depura codigo Go durante o minicurso. O cliente de referencia e o JavaScript, em `../client-js`.

## Regra de dependencias

O dominio e puro e nao conhece rede: `protocol.go`, `observation.go`, `decide.go` e `pending.go` nunca importam nada de infraestrutura. Toda a borda (websocket, ambiente, loop de reconexao) fica em `main.go`, que importa o dominio, nunca o contrario.

## Setup

Voce precisa de uma toolchain Go instalada (1.23 ou superior). Depois:

```
go mod download
```

## Testes

```
go test ./...
```

## Conectar no servidor real

O endereco padrao e `ws://localhost:4000/ws`. Duas variaveis de ambiente controlam a conexao:

- `SLIMES_URL`: endereco do websocket do servidor.
- `SLIMES_NAME`: nome da sua colonia.

```
SLIMES_URL=ws://localhost:4000/ws SLIMES_NAME=aurora go run .
```

Se a conexao cair, o cliente reconecta apos 1 segundo com o mesmo nome. O servidor retoma colonias vivas pelo nome.

## Contrato do exercicio

O protocolo de linhas e as etapas E1 a E4 estao em `../docs/PROTOCOL.md`. Para jogar, o unico arquivo que voce precisa editar e `decide.go`.
