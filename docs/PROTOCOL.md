# Protocolo Slimes, v1

O contrato entre o seu cliente e o servidor. Uma página só: se o seu cliente divergir deste documento, **o documento está certo**.

## Como ler este documento

Cada mensagem é uma linha de texto. A linha começa com o **tipo** em maiúsculas (`HELLO`, `OBS`, `ACT`...) seguido de **pedaços** separados por espaço — os pedaços são os campos da mensagem. Exemplo:

```
ACT aurora-k3f9-17 expand 12 7
│   │              │      │  └ y
│   │              │      └──── x
│   │              └─────────── tipo de ação
│   └────────────────────────── ref (a etiqueta da mensagem)
└────────────────────────────── tipo da mensagem
```

## Gramática

- Uma mensagem por linha. Cada frame WebSocket carrega exatamente uma linha.
- Pedaços separados por um espaço. Texto livre (com espaços) só no último pedaço de `ERR` e `NACK`: o código de erro é pra máquina ler, o texto livre é pra você ler.
- Nomes: `[a-z0-9-]{1,16}`. Sessão: 4 caracteres `[a-z0-9]`, sorteados uma vez por carregamento da página. Com esse alfabeto, nada no protocolo precisa de escape.
- Listas: `;` entre itens, `,` entre os campos de um item. Exemplo de casa: `11,5,forest,2,0`.
- Booleanos: `0`/`1` para fortificação; `alive`/`dead` para status de colônia.
- Versão: viaja só no `HELLO` (`HELLO v1 ...`). O servidor assume v1 nas demais mensagens do socket e responde versão errada com `ERR bad_version`.

**Regra de parse (vale para os dois lados):** transforme cada linha em um dado organizado na entrada do programa; pedaços extras no final da linha são **ignorados** (leitor tolerante); linha malformada vira erro de retorno e **nunca** derruba o programa.

## Refs: as etiquetas das mensagens

Toda mensagem do cliente carrega um **ref**: uma etiqueta única no formato `<nome>-<sessão>-<n>`, com `n` crescente por sessão. É como senha de padaria: quando o servidor responde, ele **repete a etiqueta**, e você sabe qual pedido está sendo respondido.

O segmento de sessão mantém os refs únicos entre reconexões: uma página recarregada nunca colide com a tabela de deduplicação do servidor. Mensagens iniciadas pelo servidor usam `srv-<tick>`.

Por que isso importa: se você reenviar uma mensagem com o **mesmo ref** (porque a resposta se perdeu), o servidor não aplica a ação duas vezes — ele só reenvia a confirmação original. Tentar de novo é seguro.

## Cliente → servidor

### HELLO

Entrar no jogo. Primeira mensagem do socket, enviada uma vez.

```
HELLO v1 aurora-k3f9-1 colony aurora
HELLO v1 proj-a1b2-1 spectator
```

| pedaço | regra                                                                                       |
| ------ | ------------------------------------------------------------------------------------------- |
| versão | `v1`                                                                                        |
| ref    | `<nome>-<sessão>-<n>`                                                                       |
| role   | `colony` ou `spectator`                                                                     |
| nome   | só para colônia. `"spectator"` é nome reservado; inválido ou duplicado leva `NACK bad_name` |

Reconexão: nome de colônia **viva** retoma a colônia (mesmo id, estado intacto). Nome de colônia **eliminada** é entrada nova. Respondido por `WELCOME` ou `NACK`.

### ACT

A única ação da colônia neste tick.

```
ACT aurora-k3f9-17 expand 12 7
ACT aurora-k3f9-18 pass
```

| pedaço | regra                                                |
| ------ | ---------------------------------------------------- |
| ref    | a etiqueta, para casar resposta com pedido           |
| kind   | `expand`, `attack`, `fortify`, `pass`                |
| x y    | coordenadas absolutas; obrigatórias exceto em `pass` |

Respondido por `ACK` (aceita neste tick) ou `NACK` (rejeitada, com código). Reenviar o mesmo ref depois de perder um `ACK` é seguro: o servidor deduplica por `(colony_id, ref)` e reenvia o ack sem reaplicar.

### PING

```
PING aurora-k3f9-30
```

Respondido por `PONG` ecoando o ref.

## Servidor → cliente

### WELCOME (colônia)

```
WELCOME srv-0 3 aurora 96CDFB 60 40 1000 3 4,34
```

| pedaço      | significado                |
| ----------- | -------------------------- |
| colony id   | seu identificador numérico |
| nome        | eco do `HELLO`             |
| cor         | hex sem `#`                |
| w h         | dimensões da grade         |
| tick_ms     | duração do tick            |
| view_radius | raio de visão              |
| spawn       | `x,y` da casa inicial      |

### WELCOME (espectador)

```
WELCOME srv-0 spectator 60 40 1000 0,0,plain,0,0;1,0,plain,0,0;...
```

Foto completa da grade, uma única vez: cada casa como `x,y,terrain,owner,fortified`. O terreno não muda durante a partida, então esta é a única mensagem que o envia por inteiro.

### OBS

Uma por tick, por colônia. Só a sua vizinhança — você nunca vê o mapa inteiro.

```
OBS srv-97 97 alive 97 9,5,plain,0,0;10,5,plain,3,1;11,5,forest,2,0
```

| pedaço      | significado                                                                    |
| ----------- | ------------------------------------------------------------------------------ |
| tick        | o tick que esta observação descreve                                            |
| status      | `alive` ou `dead`; depois da eliminação o socket continua aberto para assistir |
| scores_tick | tick do último placar; permite notar um placar perdido                         |
| casas       | união das vizinhanças 7x7 ao redor de cada casa da colônia                     |

Cada casa é `x,y,terrain,owner,fortified`: `terrain` é `plain`, `forest`, `water` ou `rock` (decorativo na v1); `owner` é `0` (casa vazia) ou id de colônia; `fortified` é `0`/`1` e visível para qualquer um, então dá para ver um forte inimigo antes de atacar.

Não existe mensagem de tick separada: o número viaja dentro de `OBS` e `SCORE`.

### ACK / NACK

```
ACK aurora-k3f9-17 97
NACK aurora-k3f9-17 too_late tick 96 resolvido; acao enfileirada para 97
```

`NACK` traz um código da tabela fixa e depois texto livre até o fim da linha. Erro não derruba nada: é só informação para o seu cliente decidir o que fazer.

### SCORE

Broadcast para todos, uma por tick. Nomes e contagens, **sem posições**.

```
SCORE srv-97 97 3,aurora,21,alive;5,nova,14,dead
```

### DIFF (só espectadores)

```
DIFF srv-97 97 12,7,3,0;12,8,0,0
```

Mudanças como `x,y,owner,fortified`; dono `0` é casa vazia.

### PONG / ERR

```
PONG aurora-k3f9-30
ERR aurora-k3f9-31 bad_message tipo desconhecido ACTN
```

## Códigos de erro (tabela fixa)

| código             | significado                                                                            |
| ------------------ | -------------------------------------------------------------------------------------- |
| `bad_version`      | versão diferente da do servidor                                                        |
| `bad_message`      | linha malformada ou tipo desconhecido                                                  |
| `bad_name`         | nome inválido, duplicado ou reservado                                                  |
| `bad_cell`         | fora da grade ou não vizinha da colônia                                                |
| `not_empty`        | `expand` para casa ocupada                                                             |
| `not_enemy`        | `attack` para casa que não é inimiga                                                   |
| `not_self`         | `fortify` em casa que a colônia não possui                                             |
| `attacks_disabled` | `attack` no modo cooperativo                                                           |
| `duplicate_ref`    | informacional; o `ACK` original é reenviado em seguida                                 |
| `too_late`         | chegou após o tick fechar; entra na fila do próximo tick, nunca descartada em silêncio |
