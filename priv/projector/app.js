// Projetor: cliente espectador do protocolo Slimes.
// Recebe o snapshot completo no WELCOME e depois só DIFF e SCORE por tick.
// As funções de parse são exportadas e puras; a parte de tela só roda no
// navegador (guarda no final do arquivo), então dá para testar o parse no node.

// cor da colônia como função pura do id, mesma regra do servidor
const PALETTE = ["F5C2E7", "96CDFB", "8BD5CA", "ABE9B3", "F8BD96", "F28FAD"];

export function colonyColor(id) {
  if (id <= 6) return PALETTE[id - 1];
  const base = PALETTE[(id - 1) % 6];
  const cycle = Math.floor((id - 1) / 6);
  const factor = cycle % 2 === 1 ? 1.25 : 0.75;
  const ch = (i) => Math.min(255, Math.round(parseInt(base.slice(i, i + 2), 16) * factor));
  return [ch(0), ch(2), ch(4)].map((c) => c.toString(16).padStart(2, "0")).join("");
}

export function parseCell(tok) {
  const f = tok.split(",");
  return { x: +f[0], y: +f[1], terrain: f[2], owner: +f[3], fortified: +f[4] };
}

// leitor tolerante: tokens extras no final são ignorados, linha estranha vira null
export function parseLine(line) {
  const t = line.split(" ");
  switch (t[0]) {
    case "WELCOME":
      if (t[2] !== "spectator") return null;
      return {
        type: "welcome",
        w: +t[3],
        h: +t[4],
        tickMs: +t[5],
        cells: (t[6] || "").split(";").filter(Boolean).map(parseCell),
      };
    case "DIFF":
      return {
        type: "diff",
        tick: +t[2],
        changes: (t[3] || "").split(";").filter(Boolean).map((c) => {
          const f = c.split(",");
          return { x: +f[0], y: +f[1], owner: +f[2], fortified: +f[3] };
        }),
      };
    case "SCORE":
      return {
        type: "score",
        tick: +t[2],
        entries: (t[3] || "").split(";").filter(Boolean).map((e) => {
          const f = e.split(",");
          return { id: +f[0], name: f[1], cells: +f[2], status: f[3] };
        }),
      };
    default:
      return null;
  }
}

const TERRAIN = { plain: "#1E1E2E", forest: "#284A38", water: "#2B3A5E", rock: "#3A3A4A" };

function main() {
  const canvas = document.getElementById("grid");
  const ctx = canvas.getContext("2d");
  const scoreEl = document.getElementById("scoreboard");
  const statusEl = document.getElementById("status");
  const tickEl = document.getElementById("tick");

  // estado local: grade inteira (chega uma vez no welcome) + placar
  let grid = null; // {w, h, cells: Map "x,y" -> cell}
  let scores = [];

  function render() {
    if (!grid) return;
    const size = Math.floor(canvas.width / grid.w);
    canvas.height = size * grid.h;
    // ponytail: repinta a grade inteira a cada diff; 2400 retângulos a 1/s sobra
    for (const cell of grid.cells.values()) {
      ctx.fillStyle =
        cell.owner === 0 ? TERRAIN[cell.terrain] || TERRAIN.plain : `#${colonyColor(cell.owner)}`;
      ctx.fillRect(cell.x * size, cell.y * size, size - 1, size - 1);
      if (cell.fortified === 1) {
        ctx.strokeStyle = "#F5F5FF";
        ctx.strokeRect(cell.x * size + 1, cell.y * size + 1, size - 3, size - 3);
      }
    }
    scoreEl.innerHTML = scores
      .map(
        (e) =>
          `<div class="row${e.status === "dead" ? " dead" : ""}">` +
          `<span class="chip" style="background:#${colonyColor(e.id)}"></span>` +
          `${e.name}: ${e.cells} ${e.status === "dead" ? "(morta)" : ""}</div>`
      )
      .join("");
  }

  function connect() {
    const proto = location.protocol === "https:" ? "wss" : "ws";
    const ws = new WebSocket(`${proto}://${location.host}/ws`);
    statusEl.textContent = "conectando...";

    ws.onopen = () => {
      ws.send("HELLO v1 proj-0000-1 spectator");
      statusEl.textContent = "conectado";
    };

    ws.onmessage = (event) => {
      const msg = parseLine(event.data);
      if (!msg) return;
      if (msg.type === "welcome") {
        // snapshot novo: zera a grade (restart do servidor é partida nova)
        grid = { w: msg.w, h: msg.h, cells: new Map(msg.cells.map((c) => [`${c.x},${c.y}`, c])) };
      } else if (msg.type === "diff" && grid) {
        for (const ch of msg.changes) {
          const cell = grid.cells.get(`${ch.x},${ch.y}`);
          if (cell) Object.assign(cell, { owner: ch.owner, fortified: ch.fortified });
        }
        tickEl.textContent = `tick ${msg.tick}`;
      } else if (msg.type === "score") {
        scores = msg.entries;
        tickEl.textContent = `tick ${msg.tick}`;
      }
      render();
    };

    ws.onclose = () => {
      statusEl.textContent = "desconectado; tentando de novo em 2s";
      setTimeout(connect, 2000);
    };
  }

  connect();
}

if (typeof document !== "undefined") main();
