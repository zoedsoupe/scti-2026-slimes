# WORKSHOP.md — Slimes, roteiro do instrutor

Roteiro PRIMM (Predict, Run, Investigate, Modify, Make) para o minicurso de 4 horas. Pré-requisito: cada dupla tem o `student-kit.zip` descompactado e o `PROTOCOL.md` em mãos. Este arquivo mais o kit bastam para conduzir o minicurso.

O minicurso fica completo ao fim do bloco 3. O bloco 4 é profundidade, não é estrutural: se faltar tempo, corte o bloco 4 e feche com o torneio.

## Cronograma

| horário | bloco | atividade |
|---|---|---|
| 0:00-0:10 | abertura | conexão com a palestra: o slide "puro → efeito → puro"; o que vamos construir hoje |
| 0:10-0:25 | 1 | Predict: mostrar o cliente pronto jogando; duplas preveem o que o servidor manda a cada tick |
| 0:25-1:05 | 1 | Run + Investigate: abrir o kit, rodar os testes (vermelhos), traçar a casca em duplas com as perguntas-guia. Este bloco carrega todo o risco logístico (abrir arquivos, servir a página, apontar o navegador), por isso tem folga; duplas rápidas recuperam a folga como tempo de Modify no bloco 3 |
| 1:05-1:45 | 2 | Make E1 e E2; testes ficam verdes contra o simulador local |
| 1:45-1:55 | intervalo | |
| 1:55-2:45 | 3 | Make E3 com a dica nível 1; jogar contra os bots do simulador; tarefas Modify para duplas rápidas |
| 2:45-3:10 | 3 | Conectar no servidor real; fase cooperativa (ataques desligados, colônias nos seus cantos) |
| 3:10-3:20 | 4 | Drill da v2 (ver abaixo), feito pela sala inteira ao mesmo tempo |
| 3:20-3:45 | 4 | E4 para as duplas desbloqueadas; rodadas do torneio para todos |
| 3:45-4:00 | encerramento | demo final + fechamento |

## Bloco 1 — Predict (0:10-0:25)

Mostre o cliente de referência jogando contra o simulador no projetor. Antes de abrir qualquer código, pergunte à sala:

- O que o servidor precisa mandar para o cliente a cada tick? Anotem os palpites.
- O mapa inteiro ou só parte dele? Como o cliente sabe quem é ele no mapa?
- O que acontece quando duas colônias querem a mesma célula?

Depois mostre o wire de verdade nas devtools (aba Network, frames do WebSocket): uma linha de texto por mensagem, legível a olho nu. Compare com os palpites.

## Bloco 1 — Run + Investigate (0:25-1:05)

Cada dupla abre o kit (`python3 -m http.server` na pasta, página no navegador, link "testes" para a página de testes). Os testes E1-E4 começam vermelhos. A partir daqui as duplas só leem a casca; ainda não escrevem nada.

Perguntas-guia para circular pela sala (estão também nos comentários do kit):

- O que `src/infra/transport.js` faz quando o socket fecha?
- Encontre a única chamada com efeito no pipeline. Por que ela é a única?
- Por que o parse devolve um resultado tagueado em vez de lançar exceção?
- Onde mora o socket? Por que `src/strategy/decide.js` não sabe que ele existe?
- Abra as devtools no WebSocket: o que o servidor manda a cada tick? Leia uma linha OBS e aponte cada token no PROTOCOL.md.

## Bloco 2 — Make E1 e E2 (1:05-1:45)

**E1 `parseObservation`** (`src/protocol/parse.js`): uma linha OBS vira uma observação de domínio, resultado tagueado (`{tag: "ok", value}` ou `{tag: "error", reason}`). Parse-don't-validate: ignore tokens extras no final, rejeite linha malformada com um motivo, nunca lance exceção. Testes: linha válida parseia; token extra é ignorado; falta de tick é erro; terreno e dono parseiam independentes (uma floresta com dono expõe os dois).

**E2 `encodeAction`** (`src/protocol/encode.js`): ação de domínio vira linha de protocolo com ref no formato `<nome>-<sessão>-<n>`. Testes: os quatro kinds codificam; `pass` omite a célula; o segmento de sessão é estável na execução e `n` incrementa.

Critério de saída do bloco: testes de E1 e E2 verdes, e a colônia da dupla aparece no placar do simulador (mesmo só passando a vez, porque E3 ainda é stub).

## Bloco 3 — Make E3 (1:55-2:45)

**E3 `decide`** (`src/strategy/decide.js`): estratégia livre, `observação -> ação`. Duas dicas graduadas:

1. **Sobrevivência primeiro**: expanda para células vazias adjacentes (`expandable` em `src/world/observation.js`), nunca ataque célula fortificada.
2. **Expansão + defesa**: fortifique células de fronteira com inimigo ao lado (`borderCells`), ataque inimigos desfortificados (`attackable`).

Os testes usam observações fixas e verificam a **classe** da ação esperada, não a célula exata: a estratégia continua livre. Critério de saída: E3 verde e pelo menos uma partida completa contra os bots do simulador.

## Bloco 3 — fase cooperativa no servidor real (2:45-3:10)

O servidor sobe com `--no-attacks`: ações `attack` recebem `NACK attacks_disabled` e todo o resto funciona igual. As duplas apontam o campo "servidor" para `ws://<ip-do-instrutor>:4000/ws`. Cada colônia cresce no seu canto. A lição: o servidor é a autoridade e nunca confia que os clientes serão educados.

## Bloco 4 — drill da v2 (3:10-3:20), sala inteira junta

O instrutor reinicia o servidor na **v2**, onde a tupla de célula ganha um sexto campo (um valor de recurso). Formatos posicionais não renomeiam campos, então o drill é sobre **adicionar** campos: clientes cujo parser aceita exatamente 5 campos quebram; a correção é aceitar 5 ou 6 e ignorar o excedente, que é exatamente a regra do leitor tolerante do E1. Todo mundo quebra do mesmo jeito, todo mundo conserta junto. A lição: para que existe o token de versão no HELLO, e por que leitores tolerantes sobrevivem à evolução do protocolo.

## Bloco 4 — E4 e torneio (3:20-3:45)

**Regra de desbloqueio do E4:** E1-E3 verdes mais pelo menos uma vitória contra um bot do simulador. Regra binária, para o instrutor não triar 15 duplas no feeling sob pressão de tempo. Duplas que não desbloqueiam o E4 jogam todas as rodadas do torneio mesmo assim; o bloco 4 é profundidade, não é estrutural.

**E4** (`src/protocol/pending.js`): política de retry pura sobre o mapa de pendentes. `onAck(pending, ref)` remove o ref confirmado. `onTimeout(pending, now)` devolve `[novoMapa, efeitos]` com orçamento de 3 tentativas e timeout de 2 ticks: dentro do orçamento, efeito `{retry, ref, line}`; no limite, `{drop, ref}`. Testes: ack remove; timeout dentro do orçamento reenvia; timeout no limite descarta. É a lição de at-least-once + idempotência, escrita como funções puras.

**Torneio**: o instrutor reinicia o servidor sem `--no-attacks` (restart = partida nova). Rodadas curtas; quem perde assiste pelo projetor.

## Tarefas Modify (duplas rápidas, bloco 3 em diante)

- Mude o orçamento de retry do E4 de 3 para 5 (`BUDGET` em `src/protocol/pending.js`) e observe o efeito no torneio.
- Adicione uma heurística ao `decide`: preferir expandir na direção do inimigo mais próximo; nunca fortificar duas vezes a mesma célula; recuar de fronteira fortificada.
- Previsão do placar no cliente: entre um tick e outro, preveja o SCORE a partir das suas ações confirmadas e compare com o placar real quando ele chega.
- Drill da v2 (acima) conta como tarefa Modify para quem chegar cedo.

## Demo final (3:45-4:00), instrutor no projetor

1. Abra o código do servidor. Mostre a dedup por ref em umas 5 linhas de Elixir (a consulta à tabela de dedup no handler de ação).
2. Explique entrega at-least-once + idempotência com a analogia do pagamento: tentar o pagamento de novo não pode cobrar duas vezes; o ref é a chave de idempotência.
3. Mostre o log de eventos: exporte via `/debug/log`, rode `mix replay`, obtenha o mesmo placar final. Estado como fold de eventos.
4. Derrube o servidor por 30 segundos no meio de uma partida. Pergunte à sala o que os clientes observaram (socket fechado, reconexão, ticks perdidos, NACKs `too_late`). Reinicie, aceite a partida nova, discuta o que sistemas de verdade fazem diferente.

## Notas de logística

- Os scaffolds Python e Go são **não suportados**: uso por conta e risco, sem debug do instrutor. Apontam para o servidor real ou para o simulador de um colega.
- Wi-Fi caiu? As duplas desenvolvem contra o simulador local e a aula continua; só o torneio depende de rede.
- Restart do servidor é partida nova, por decisão de projeto. Se um log importar, capture `/debug/log` antes.
