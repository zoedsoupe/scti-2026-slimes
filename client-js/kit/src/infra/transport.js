// Transporte: "local" sobe o simulador em processo; qualquer outra url
// abre um WebSocket de verdade. Mesma interface nos dois lados.

import { createSimServer } from "./simulator/server.js";

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
