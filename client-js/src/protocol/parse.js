// Parse das linhas do protocolo para tipos de domínio, na fronteira.
// Regra do PROTOCOL.md: tokens extras no final são ignorados (leitor
// tolerante), linha malformada vira {tag: "error"} e nunca lança exceção.

export const ok = (value) => ({ tag: "ok", value });
export const err = (reason) => ({ tag: "error", reason });

const int = (tok) => {
  // inteiros base-10; qualquer outra coisa torna a linha malformada
  if (!/^-?\d+$/.test(tok)) return null;
  return parseInt(tok, 10);
};

// célula: x,y,terrain,owner,fortified (tokens extras na célula ignorados)
export function parseCell(tok) {
  const f = tok.split(",");
  if (f.length < 5) return null;
  const [x, y, owner, fortified] = [int(f[0]), int(f[1]), int(f[3]), int(f[4])];
  if (x === null || y === null || owner === null || fortified === null) return null;
  return { x, y, terrain: f[2], owner, fortified };
}

const cellList = (tok) => {
  if (tok === undefined || tok === "") return [];
  const cells = tok.split(";").map(parseCell);
  return cells.includes(null) ? null : cells;
};

// E1: uma linha OBS -> observação de domínio
export function parseObservation(line) {
  const t = line.split(" ");
  if (t[0] !== "OBS") return err(`tipo inesperado ${t[0]}`);
  const [tick, scoresTick] = [int(t[2]), int(t[4])];
  if (tick === null || scoresTick === null) return err("tick ausente ou invalido");
  if (t[3] !== "alive" && t[3] !== "dead") return err(`status invalido ${t[3]}`);
  const cells = cellList(t[5]);
  if (cells === null) return err("lista de celulas malformada");
  return ok({ ref: t[1], tick, status: t[3], scoresTick, cells });
}

export function parseLine(line) {
  const t = line.split(" ");
  switch (t[0]) {
    case "OBS":
      return parseObservation(line);

    case "WELCOME": {
      if (t[2] === "spectator") {
        const [w, h, tickMs] = [int(t[3]), int(t[4]), int(t[5])];
        if (w === null || h === null || tickMs === null) return err("welcome de espectador malformado");
        const cells = cellList(t[6]);
        if (cells === null) return err("snapshot malformado");
        return ok({ type: "welcome", role: "spectator", w, h, tickMs, cells });
      }
      const [id, w, h, tickMs, viewRadius] = [int(t[2]), int(t[5]), int(t[6]), int(t[7]), int(t[8])];
      if ([id, w, h, tickMs, viewRadius].includes(null)) return err("welcome malformado");
      const spawn = t[9] ? t[9].split(",").map(int) : null;
      if (!spawn || spawn.includes(null)) return err("spawn malformado");
      return ok({ type: "welcome", role: "colony", id, name: t[3], color: t[4], w, h, tickMs, viewRadius, spawn });
    }

    case "ACK": {
      const tick = int(t[2]);
      if (tick === null) return err("ack sem tick");
      return ok({ type: "ack", ref: t[1], tick });
    }

    case "NACK":
      return ok({ type: "nack", ref: t[1], code: t[2], detail: t.slice(3).join(" ") });

    case "ERR":
      return ok({ type: "err", ref: t[1], code: t[2], detail: t.slice(3).join(" ") });

    case "SCORE": {
      const tick = int(t[2]);
      if (tick === null) return err("score sem tick");
      const entries = (t[3] || "").split(";").filter(Boolean).map((e) => {
        const f = e.split(",");
        return { id: int(f[0]), name: f[1], cells: int(f[2]), status: f[3] };
      });
      if (entries.some((e) => e.id === null || e.cells === null)) return err("score malformado");
      return ok({ type: "score", ref: t[1], tick, entries });
    }

    case "DIFF": {
      const tick = int(t[2]);
      if (tick === null) return err("diff sem tick");
      const changes = (t[3] || "").split(";").filter(Boolean).map((c) => {
        const f = c.split(",");
        return { x: int(f[0]), y: int(f[1]), owner: int(f[2]), fortified: int(f[3]) };
      });
      if (changes.some((c) => [c.x, c.y, c.owner, c.fortified].includes(null))) return err("diff malformado");
      return ok({ type: "diff", ref: t[1], tick, changes });
    }

    case "PONG":
      return ok({ type: "pong", ref: t[1] });

    // lado do simulador: mensagens que chegam do cliente
    case "HELLO": {
      if (t[1] !== "v1") return ok({ type: "hello", ref: t[2], badVersion: true });
      if (t[3] === "spectator") return ok({ type: "hello", ref: t[2], role: "spectator" });
      if (t[3] === "colony" && t[4]) return ok({ type: "hello", ref: t[2], role: "colony", name: t[4] });
      return err("hello malformado");
    }

    case "ACT": {
      const kind = t[2];
      if (kind === "pass") return ok({ type: "act", ref: t[1], kind });
      if (kind !== "expand" && kind !== "attack" && kind !== "fortify") return err(`kind desconhecido ${kind}`);
      const [x, y] = [int(t[3]), int(t[4])];
      if (x === null || y === null) return err("act sem coordenadas");
      return ok({ type: "act", ref: t[1], kind, x, y });
    }

    case "PING":
      return ok({ type: "ping", ref: t[1] });

    default:
      return err(`tipo desconhecido ${t[0]}`);
  }
}
