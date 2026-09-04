# Cheatsheet do protocolo, v1

Referência rápida de todas as mensagens. O contrato completo está em `PROTOCOL.md`; em caso de divergência, o `PROTOCOL.md` vence.

## Gramática mínima

- Uma mensagem por linha, um frame WebSocket por linha.
- Pedaços separados por um espaço.
- Texto livre só no final de `ERR` e `NACK`.
- Listas: `;` entre itens, `,` entre campos.
- Casa completa: `x,y,terreno,dono,fortificada`.
- Mudança (DIFF): `x,y,dono,fortificada`.
- Terreno: `plain` `forest` `water` `rock`. Dono `0` = casa vazia. Fortificada: `0`/`1`.
- Status: `alive` `dead`.
- Refs do cliente (a etiqueta): `<nome>-<sessão>-<n>`. Refs do servidor: `srv-<tick>`.
- Regra de parse: ignore pedaços extras no final da linha; linha malformada vira erro de retorno, nunca derruba o programa.

## Cliente → servidor

| Mensagem | Formato | Resposta |
|---|---|---|
| HELLO (colônia) | `HELLO v1 <ref> colony <nome>` | `WELCOME` ou `NACK bad_name` |
| HELLO (espectador) | `HELLO v1 <ref> spectator` | `WELCOME` |
| ACT | `ACT <ref> expand <x> <y>` | `ACK` ou `NACK` |
| | `ACT <ref> attack <x> <y>` | |
| | `ACT <ref> fortify <x> <y>` | |
| | `ACT <ref> pass` | |
| PING | `PING <ref>` | `PONG <ref>` |

## Servidor → cliente

| Mensagem | Formato |
|---|---|
| WELCOME (colônia) | `WELCOME srv-0 <id> <nome> <cor> <w> <h> <tick_ms> <raio> <x>,<y>` |
| WELCOME (espectador) | `WELCOME srv-0 spectator <w> <h> <tick_ms> <casa>;<casa>;...` |
| OBS (colônia, por tick) | `OBS srv-<tick> <tick> <status> <scores_tick> <casa>;<casa>;...` |
| ACK | `ACK <ref> <tick>` |
| NACK | `NACK <ref> <código> <texto livre>` |
| SCORE (todos, por tick) | `SCORE srv-<tick> <tick> <id>,<nome>,<casas>,<status>;...` |
| DIFF (espectadores, por tick) | `DIFF srv-<tick> <tick> <x>,<y>,<dono>,<fort>;...` |
| PONG | `PONG <ref>` |
| ERR | `ERR <ref> <código> <texto livre>` |

## Códigos de erro

| Código | Via | Quando |
|---|---|---|
| `bad_version` | ERR | versão diferente de `v1` |
| `bad_message` | ERR | linha malformada, tipo desconhecido, número inválido |
| `bad_name` | NACK | nome inválido, reservado ou duplicado |
| `bad_cell` | NACK | fora da grade ou não vizinha da colônia |
| `not_empty` | NACK | `expand` em casa ocupada |
| `not_enemy` | NACK | `attack` em casa que não é inimiga |
| `not_self` | NACK | `fortify` em casa que não é sua |
| `attacks_disabled` | NACK | `attack` no modo cooperativo |
| `duplicate_ref` | NACK | informativo; o `ACK` original é reenviado em seguida |
| `too_late` | NACK | chegou depois do tick fechar; entra na fila do próximo tick |

## Exemplos

```
HELLO v1 aurora-k3f9-1 colony aurora
WELCOME srv-0 3 aurora 96CDFB 60 40 1000 3 4,34

ACT aurora-k3f9-17 expand 12 7
ACK aurora-k3f9-17 97

OBS srv-97 97 alive 97 9,5,plain,0,0;10,5,plain,3,1;11,5,forest,2,0
SCORE srv-97 97 3,aurora,21,alive;5,nova,14,dead
DIFF srv-97 97 12,7,3,0;12,8,0,0

NACK aurora-k3f9-17 too_late tick 96 resolvido; acao enfileirada para 97
ERR aurora-k3f9-31 bad_message tipo desconhecido ACTN
```
