// Transporte: "local" sobe o simulador em processo; qualquer outra url
// abre um WebSocket de verdade. Mesma interface nos dois lados.

import { createSimServer } from "./simulator/server.js";

// connect(url, handlers): abre uma conexão com o servidor do jogo.
//   url: "local" sobe o simulador no próprio navegador; qualquer outra
//        url (ex: "ws://172.20.10.6:4000/ws") abre um WebSocket
//   handlers: { onLine(line), onOpen(), onClose() }, todos opcionais
//     menos onLine; onLine recebe cada linha crua do protocolo
// Devolve { sendLine(line), close() }. sendLine ignora o envio se o
// socket não estiver aberto.
// Exemplo:
//   const conn = connect(url, {
//     onLine: (line) => tratar(parseLine(line)),
//     onOpen: () => conn.sendLine(encodeHello(refs.next(), "colony", nome)),
//     onClose: () => console.log("caiu"),
//   });
export function connect(url, { onLine, onOpen, onClose }) {
  if (url === "local") {
    const sim = createSimServer({});
    const endpoint = sim.connect();
    endpoint.onLine(onLine);
    if (onClose) endpoint.onClose(onClose);
    // assíncrono como um WebSocket, para o chamador prender handlers antes
    queueMicrotask(() => onOpen && onOpen());
    return {
      sendLine: (line) => endpoint.sendLine(line),
      close: () => endpoint.close(),
    };
  }

  const ws = new WebSocket(url);
  ws.onopen = () => onOpen && onOpen();
  ws.onmessage = (event) => onLine(event.data);
  ws.onclose = () => onClose && onClose();
  return {
    sendLine: (line) => {
      if (ws.readyState === WebSocket.OPEN) ws.send(line);
    },
    close: () => ws.close(),
  };
}
