"""Loop do cliente: conecta, cumprimenta, e a cada OBS decide e age.

Uso:
    pip install -r requirements.txt
    SLIMES_URL=ws://localhost:4000/ws SLIMES_NAME=aurora python main.py
"""

import asyncio
import os

from websockets import WebSocketException, connect

from decide import decide
from pending import add_pending, on_ack, on_timeout
from protocol import Refs, encode_action, encode_hello, parse_line


async def run(url, name):
    # refs novos por sessão; o servidor retoma a colônia viva pelo nome
    refs = Refs(name)
    my_id = None
    pending = {}

    async with connect(url) as ws:
        # HELLO é a primeira mensagem do socket, enviada uma vez
        await ws.send(encode_hello(refs.next(), "colony", name))

        async for line in ws:
            tag, msg = parse_line(line)
            if tag == "error":
                print(f"linha malformada: {msg}")
                continue

            kind = msg["type"]
            if kind == "welcome":
                my_id = msg["id"]
                print(f"entrei como {msg['name']} (id {my_id}), cor #{msg['color']}")
            elif kind == "obs":
                pending, effects = on_timeout(pending, msg["tick"])
                for e in effects:
                    if "retry" in e:
                        await ws.send(e["line"])
                if msg["status"] == "alive" and my_id is not None:
                    action = decide(msg, my_id)
                    ref = refs.next()
                    line = encode_action(action, ref)
                    pending = add_pending(pending, ref, line, msg["tick"])
                    await ws.send(line)
            elif kind == "ack":
                pending = on_ack(pending, msg["ref"])
            elif kind == "nack":
                if msg["code"] == "duplicate_ref":
                    # informacional: o ACK original chega em seguida, mantém o pendente
                    continue
                pending = on_ack(pending, msg["ref"])
                print(f"NACK {msg['code']}: {msg['detail']}")
            elif kind == "err":
                print(f"ERR {msg['code']}: {msg['detail']}")


async def main():
    url = os.environ.get("SLIMES_URL", "ws://localhost:4000/ws")
    name = os.environ.get("SLIMES_NAME", "pyslime")

    while True:
        try:
            await run(url, name)
        except (OSError, WebSocketException) as e:
            print(f"conexão caiu: {e}")
        print("conexão fechada; tentando de novo em 1s")
        await asyncio.sleep(1)


if __name__ == "__main__":
    asyncio.run(main())
