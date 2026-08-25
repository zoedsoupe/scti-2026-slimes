// Renderizador de canvas: desenha a grade e o placar.
// Camada de infra: só desenho, nenhuma rede e nenhuma regra de jogo aqui.

import { key } from "../world/observation.js";
import { colonyColor } from "../world/palette.js";

// matizes de terreno por cima do fundo (só em células vazias)
const TERRAIN = {
  forest: "#26402E",
  water: "#24384E",
  rock: "#3A3A4A",
};

const BG = "#1E1E2E";
const UNKNOWN = "#16161F";
const FG = "#F5F5FF";

export function createRenderer(canvas, scoreboardEl) {
  const ctx = canvas.getContext("2d");

  function render(view) {
    drawGrid(view);
    drawScores(view);
  }

  function drawGrid({ w, h, knownCells }) {
    if (!w || !h) return;
    const size = Math.floor(canvas.width / w);
    canvas.height = size * h; // ajusta a altura à grade

    ctx.fillStyle = BG;
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        const cell = knownCells.get(key(x, y));
        drawCell(x, y, size, cell);
      }
    }
  }

  function drawCell(x, y, size, cell) {
    const px = x * size;
    const py = y * size;

    if (!cell) {
      // névoa de guerra: célula nunca vista fica escura
      ctx.fillStyle = UNKNOWN;
      ctx.fillRect(px, py, size, size);
      return;
    }

    if (cell.owner === 0) {
      ctx.fillStyle = TERRAIN[cell.terrain] || BG;
    } else {
      ctx.fillStyle = `#${colonyColor(cell.owner)}`;
    }
    ctx.fillRect(px, py, size, size);

    if (cell.fortified === 1) {
      // fortificação: borda clara ao redor da célula
      ctx.strokeStyle = FG;
      ctx.lineWidth = 2;
      ctx.strokeRect(px + 1, py + 1, size - 2, size - 2);
    }
  }

  function drawScores({ scores, myId }) {
    scoreboardEl.replaceChildren(...scores.map((e) => scoreRow(e, myId)));
  }

  function scoreRow(entry, myId) {
    const tr = document.createElement("tr");
    if (entry.id === myId) tr.classList.add("eu");
    if (entry.status === "dead") tr.classList.add("morta");

    const chip = document.createElement("span");
    chip.className = "chip";
    chip.style.background = `#${colonyColor(entry.id)}`;

    const status = entry.status === "dead" ? "morta" : "viva";
    tr.append(
      td(chip),
      td(entry.name),
      td(String(entry.cells)),
      td(status),
    );
    return tr;
  }

  const td = (content) => {
    const cell = document.createElement("td");
    if (typeof content === "string") cell.textContent = content;
    else cell.append(content);
    return cell;
  };

  return { render };
}
