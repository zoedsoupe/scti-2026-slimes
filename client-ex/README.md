# SlimesClient (Elixir)

Cliente não oficial, sem suporte do instrutor. Uso por conta e risco: dúvidas sobre este código não serão respondidas em aula nem depois dela.

## Estrutura

O domínio é puro e não conhece rede: `Protocol` (parse e encode das linhas), `Observation` (consultas sobre a visão), `Decide` (estratégia) e `Pending` (política de retry) nunca importam a casca. A casca é `Client`, o processo WebSockex que conecta, cumprimenta e a cada OBS decide e age. A dependência aponta só numa direção: `Client` usa o domínio, nunca o contrário.

Para jogar, o único módulo que você precisa editar é `SlimesClient.Decide`.

## Setup

```
mix deps.get
```

## Testes

```
mix test
```

## Conectar ao servidor

O servidor precisa estar rodando (veja o README da raiz do repositório). Depois:

```
SLIMES_URL=ws://localhost:4000/ws SLIMES_NAME=aurora mix run --no-halt -e SlimesClient.Client.main
```

Sem as variáveis de ambiente, o padrão é `ws://localhost:4000/ws` e o nome `exslime`. Se a conexão cair, o cliente reconecta sozinho e entra de novo com o mesmo nome.

## Protocolo

O contrato do exercício (E1 a E4) está em `../docs/PROTOCOL.md`.
