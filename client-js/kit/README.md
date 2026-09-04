# Kit do estudante Slimes

**Regra de dependências:** `src/protocol/`, `src/world/` e `src/strategy/` nunca importam nada de `src/infra/` (domínio puro não conhece infraestrutura). Só `src/infra/` toca em DOM, canvas e rede.

Este é o kit do minicurso. Você escreve **três funções puras** (E1 a E3); toda a infraestrutura (transporte, reconexão, retry de ações, renderização, simulador local) já está pronta e não deve ser modificada.

## Como rodar

Módulos ES não carregam via `file://`. Na pasta do kit:

```
python3 -m http.server
```

Abra http://localhost:8000/ no navegador.

## Testes

Abra http://localhost:8000/test/ (link "testes" na barra da página). Os exercícios começam vermelhos; recarregue a página a cada edição e os testes ficam verdes conforme você implementa.

## Os exercícios

| exercício | arquivo | função |
|---|---|---|
| E1 | `src/protocol/parse.js` | `parseObservation(line)` |
| E2 | `src/protocol/encode.js` | `encodeAction(action, ref)` |
| E3 | `src/strategy/decide.js` | `decide(obs, myId)` |

Cada stub tem um comentário TODO com o formato esperado. Os testes de cada exercício vivem em `test/protocol_test.js` (E1, E2) e `test/strategy_test.js` (E3).

## Jogar contra o simulador local

Deixe o campo "servidor" em `local`, escolha um nome de colônia (`[a-z0-9-]{1,16}`) e clique em "conectar". O simulador roda no próprio navegador, com dois bots (`z-random` e `z-greedy`), e fala exatamente o protocolo do PROTOCOL.md. Não precisa de rede.

## Apontar para o servidor real

No campo "servidor", use `ws://<ip-do-instrutor>:4000/ws` e clique em "conectar". Se a conexão cair, o cliente tenta de novo após 1 segundo com o mesmo nome; o servidor retoma a colônia se ela ainda estiver viva.

## O pipeline (leia no arranque de `src/infra/app.js`)

```
socket message
|> protocol.parse()      // PURO  (linha -> mensagem de domínio, resultado tagueado)
|> strategy.decide()     // PURO  (observação -> ação)  <- E3 é aqui
|> protocol.encode()     // PURO  (ação -> linha)
|> infra.send()          // EFEITO (o único passo com efeito)
```
