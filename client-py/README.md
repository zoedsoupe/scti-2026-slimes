# client-py: scaffold bônus em Python

Este cliente **não é suportado**: uso por conta e risco, sem direito a debug do instrutor. O cliente de referência do minicurso é o JavaScript em `client-js/`; este scaffold existe para quem já se vira sozinho em Python.

## Regra de dependência

O domínio puro (`protocol.py`, `observation.py`, `decide.py`, `pending.py`) nunca importa infraestrutura: nada de socket, rede ou tempo ali dentro. Só `main.py` toca no websocket e no asyncio. Se você sentir vontade de importar `websockets` dentro de `decide.py`, pare: a decisão é pura, o efeito mora na borda.

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

Os testes cobrem o parser e o encode (E1, E2), a estratégia (E3) e a política de retry (E4).

## Conectar no servidor real

```
python3 main.py
```

Por padrão conecta em `ws://localhost:4000/ws` com o nome `pyslime`. Para mudar:

```
SLIMES_URL=ws://192.168.0.10:4000/ws SLIMES_NAME=aurora python3 main.py
```

O servidor retoma uma colônia viva pelo nome, então reconectar com o mesmo `SLIMES_NAME` continua a partida.

## O contrato

O exercício (E1 a E4) está descrito em `../docs/PROTOCOL.md`, que no zip do kit fica ao lado desta pasta. Leia ele antes de mexer em `decide.py`, que é o único arquivo que você precisa editar para jogar.
