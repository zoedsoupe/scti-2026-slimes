# WORKSHOP.md — Slimes, roteiro do minicurso

Roteiro completo do minicurso de **3 horas e meia**. Pré-requisito: cada pessoa (ou dupla — é opcional) tem o kit descompactado e o `PROTOCOL.md` em mãos. Este arquivo mais o kit bastam para acompanhar o dia inteiro.

O minicurso fica completo ao fim do bloco 3 (fase cooperativa). O bloco 4 é profundidade, não é estrutural: se faltar tempo, corte o drill e feche com o torneio.

## Cronograma

| horário | bloco | atividade |
|---|---|---|
| 0:00-0:10 | abertura | o que vamos construir hoje, como vamos aprender (prever → investigar → construir) |
| 0:10-0:25 | 1 | **Prever**: o que o servidor manda a cada tick? Palpites anotados antes de ver o tráfego real |
| 0:25-1:00 | 1 | **Rodar + investigar**: abrir o kit, rodar os testes (vermelhos), explorar a casca com as perguntas-guia. Este bloco carrega todo o risco logístico (baixar o kit, servir a página, apontar o navegador), por isso tem folga; quem for rápido usa a folga como tempo extra de construção no bloco 3 |
| 1:00-1:35 | 2 | **Construir** E1 e E2; testes ficam verdes contra o simulador local |
| 1:35-1:45 | intervalo | |
| 1:45-2:30 | 3 | **Construir** E3 com a dica nível 1; jogar contra os bots do simulador; tarefas extras para quem for rápido |
| 2:30-2:50 | 3 | Conectar no servidor real; fase **cooperativa** (ataques desligados, colônias nos seus cantos) |
| 2:50-3:00 | 4 | **Drill da v2** (ver abaixo), feito pela sala inteira ao mesmo tempo |
| 3:00-3:20 | 4 | rodadas do **torneio** |
| 3:20-3:30 | encerramento | demo final + fechamento |

## Bloco 1 — Prever (0:10-0:25)

O instrutor mostra o cliente de referência jogando contra o simulador no projetor. Antes de abrir qualquer código, a sala responde:

- O que o servidor precisa mandar para o cliente a cada tick? Anotem os palpites.
- O mapa inteiro ou só parte dele? Como o cliente sabe quem é ele no mapa?
- O que acontece quando duas colônias querem a mesma casa?

Depois o instrutor mostra o tráfego de verdade nas devtools (aba Network, frames do WebSocket): uma linha de texto por mensagem, legível a olho nu. Comparem com os palpites.

## Bloco 1 — Rodar + investigar (0:25-1:00)

Cada pessoa abre o kit: baixar em `/kit`, descompactar, `python3 -m http.server` na pasta, abrir a página no navegador, clicar no link "testes". Os testes E1-E3 começam vermelhos — não é bug, é o mapa do que falta construir. A partir daqui vocês só **leem** a casca; ainda não escrevem nada.

Perguntas-guia (estão também nos comentários do kit):

- O que `src/infra/transport.js` faz quando o socket fecha?
- Encontre a única chamada que fala com a rede no pipeline inteiro. Por que ela é a única?
- Por que o parse devolve um resultado com etiqueta (`ok`/`error`) em vez de lançar exceção?
- Onde mora o socket? Por que `src/strategy/decide.js` não sabe que ele existe?
- Abra as devtools no WebSocket: o que o servidor manda a cada tick? Leia uma linha OBS e aponte cada pedaço no PROTOCOL.md.

## Bloco 2 — Construir E1 e E2 (1:00-1:35)

**E1 `parseObservation`** (`src/protocol/parse.js`): o tradutor da entrada. Uma linha OBS vira um dado organizado, com resultado etiquetado (`{tag: "ok", value}` ou `{tag: "error", reason}`). Regras: ignore pedaços extras no final da linha (leitor tolerante), rejeite linha malformada com um motivo, **nunca** lance exceção. Testes: linha válida parseia; pedaço extra é ignorado; falta de tick é erro; terreno e dono parseiam independentes (uma floresta com dono expõe os dois).

**E2 `encodeAction`** (`src/protocol/encode.js`): o tradutor da saída, espelho do E1. Ação vira linha de protocolo com o ref no formato `<nome>-<sessão>-<n>`. Testes: os quatro tipos de ação codificam; `pass` omite as coordenadas; o segmento de sessão é estável na execução e `n` incrementa.

Critério de saída do bloco: testes de E1 e E2 verdes, e a sua colônia aparece no placar do simulador (mesmo só passando a vez, porque E3 ainda é rascunho).

## Bloco 3 — Construir E3 (1:45-2:30)

**E3 `decide`** (`src/strategy/decide.js`): o cérebro. Estratégia livre, `observação -> ação`. Duas dicas graduadas:

1. **Sobrevivência primeiro**: expanda para casas vazias vizinhas (`expandable` em `src/world/observation.js`), nunca ataque casa fortificada.
2. **Expansão + defesa**: fortifique casas de fronteira com inimigo ao lado (`borderCells`), ataque inimigos sem fortificação (`attackable`).

Os testes usam observações fixas e verificam o **tipo** da ação esperada, não a casa exata: a estratégia continua livre. Critério de saída: E3 verde e pelo menos uma partida completa contra os bots do simulador.

## Bloco 3 — fase cooperativa no servidor real (2:30-2:50)

O servidor sobe com ataques desligados: ações `attack` recebem `NACK attacks_disabled` e todo o resto funciona igual. Vocês apontam o campo "servidor" para `ws://<ip-do-instrutor>:4000/ws`. Cada colônia cresce no seu canto. A lição: agora é rede de verdade — latência de verdade, mensagem perdida de verdade, reconexão de verdade. O reenvio com a mesma etiqueta (que já vem na casca do kit) é o que salva o seu cliente aqui.

## Bloco 4 — drill da v2 (2:50-3:00), sala inteira junta

O instrutor reinicia o servidor na **v2**, onde cada casa ganha um sexto campo (um valor de recurso). Protocolo novo não renomeia nem reordena campo: evolução é **adicionar no final**. Clientes cujo parser aceita exatamente 5 campos quebram; a correção é aceitar 5 ou 6 e ignorar o excedente — exatamente a regra do leitor tolerante do E1. Todo mundo quebra do mesmo jeito, todo mundo conserta junto. A lição: para que existe o `v1` no `HELLO`, e por que leitores tolerantes sobrevivem à evolução do protocolo.

## Bloco 4 — torneio (3:00-3:20)

O instrutor reinicia o servidor sem a trava de ataques (restart = partida nova, por decisão de projeto). Rodadas curtas; quem perde assiste pelo projetor.

## Tarefas extras (quem for rápido, bloco 3 em diante)

- Adicione uma heurística ao `decide`: preferir expandir na direção do inimigo mais próximo; nunca fortificar duas vezes a mesma casa; recuar de fronteira fortificada.
- Previsão do placar no cliente: entre um tick e outro, preveja o SCORE a partir das suas ações confirmadas e compare com o placar real quando ele chega.
- O drill da v2 (acima) conta como tarefa extra para quem chegar cedo.

## Demo final (3:20-3:30), instrutor no projetor

1. Abrir o código do servidor: a trava de etiqueta repetida (dedup por ref) em umas 5 linhas de Elixir.
2. Explicar "tentar de novo sem aplicar duas vezes" com a analogia do pagamento: clicar "pagar" de novo não pode cobrar duas vezes; o ref é a trava.
3. Mostrar o log de eventos: exportar via `/debug/log`, rodar `mix replay`, obter o mesmo placar final. O estado é só a soma dos eventos.
4. Derrubar o servidor por 30 segundos no meio de uma partida. Perguntar à sala o que os clientes observaram (socket fechado, reconexão, ticks perdidos, NACKs `too_late`). Reiniciar, aceitar a partida nova, discutir o que sistemas de verdade fazem diferente.

## Notas de logística

- O kit oficial é o de **JavaScript** (`/kit`): único com visualizador e simulador local, e o único com suporte do instrutor. Os kits de **Elixir** (`/kit/elixir`), **Go** (`/kit/golang`), **Python** (`/kit/python`) e **C** (`/kit/c`) são por conta e risco, sem debug do instrutor — escolha pela linguagem que você domina.
- Wi-Fi caiu? Todo mundo desenvolve contra o simulador local e a aula continua; só a fase cooperativa e o torneio dependem de rede.
- Restart do servidor é partida nova, por decisão de projeto. Se um log importar, capture `/debug/log` antes.
