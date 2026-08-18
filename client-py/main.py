"""Loop do cliente: conecta, cumprimenta, e a cada OBS decide e age.

Uso:
    pip install -r requirements.txt
    SLIMES_URL=ws://localhost:4000/ws SLIMES_NAME=aurora python main.py
"""

import os

from websocket import create_connection

from decide import decide
from pending import add_pending, on_ack, on_timeout
from protocol import Refs, encode_action, encode_hello, parse_line


def main():
    url = os.environ.get("SLIMES_URL", "ws://localhost:4000/ws")
    name = os.environ.get("SLIMES_NAME", "pyslime")

    refs = Refs(name)
    my_id = None
    pending = {}

    ws = create_connection(url)
    ws.send(encode_hello(refs.next(), "colony", name))

    while True:
        tag, msg = parse_line(ws.recv())
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
                    ws.send(e["line"])
            if msg["status"] == "alive" and my_id is not None:
                action = decide(msg, my_id)
                ref = refs.next()
                line = encode_action(action, ref)
                pending = add_pending(pending, ref, line, msg["tick"])
                ws.send(line)
        elif kind == "ack":
            pending = on_ack(pending, msg["ref"])
        elif kind == "nack":
            print(f"NACK {msg['code']}: {msg['detail']}")
        elif kind == "err":
            print(f"ERR {msg['code']}: {msg['detail']}")


if __name__ == "__main__":
    main()
