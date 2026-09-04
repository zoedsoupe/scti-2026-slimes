# Kit do estudante Slimes (Python)

Cliente **não oficial**, sem suporte do instrutor. Uso por conta e risco: dúvidas sobre este código não serão respondidas em aula nem depois dela.

**Regra de dependência:** o domínio puro (`protocol.py`, `observation.py`, `decide.py`, `pending.py`) nunca importa infraestrutura: nada de socket, rede ou asyncio ali dentro. Só `main.py` toca no websocket.

Este é o kit do minicurso. Você escreve **três funções puras** (E1 a E3); toda a infraestrutura (conexão, reconexão, política de retry) já está pronta e não deve ser modificada.

## Setup

```
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

A única dependência é `websockets` (API asyncio).

## Testes

```
python3 -m unittest discover -v
```

Os exercícios começam vermelhos; os testes ficam verdes conforme você implementa.

## Os exercícios

| exercício | arquivo | função |
|---|---|---|
| E1 | `protocol.py` | `parse_observation(line)` |
| E2 | `protocol.py` | `encode_action(action, ref)` |
| E3 | `decide.py` | `decide(obs, my_id)` |

Cada stub tem um comentário TODO com o formato esperado. Os testes de cada exercício vivem em `test_protocol.py` (E1, E2) e `test_strategy.py` (E3).

## O que não modificar

`main.py`, `pending.py` e `observation.py` são infraestrutura pronta: não edite. Em `protocol.py`, mexa só nas duas funções marcadas com TODO. Os helpers de `observation.py` (`own_cells`, `expandable`, `attackable`, `border_cells`) existem para a sua estratégia usar: leia os docstrings, cada um tem um exemplo.

## Conectar ao servidor

O servidor precisa estar rodando (veja o WORKSHOP.md). Depois:

```
SLIMES_URL=ws://<ip-do-instrutor>:4000/ws SLIMES_NAME=<nome> python3 main.py
```

Sem as variáveis de ambiente, o padrão é `ws://localhost:4000/ws` e o nome `pyslime`. Se a conexão cair, o cliente reconecta sozinho após 1 segundo e entra de novo com o mesmo nome; o servidor retoma a colônia se ela ainda estiver viva.

## O pipeline (leia no `run()` de `main.py`)

```
linha do socket
|> parse_line()     (PURO: linha -> mensagem de domínio tagueada)
|> decide()         (PURO: observação -> ação)   <- E3 é aqui
|> encode_action()  (PURO: ação -> linha)
|> ws.send()        (EFEITO: o único passo com efeito)
```

## Protocolo

O contrato do exercício (E1 a E3) está no PROTOCOL.md ao lado deste README. Leia ele antes de mexer em `decide.py`.
