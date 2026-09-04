// Parse das linhas do protocolo para tipos de domínio, na fronteira.
// Regra do PROTOCOL.md: tokens extras no final são ignorados (leitor
// tolerante), linha malformada vira {tag: "error"} e nunca lança exceção.

// ok(value): embrulha um parse que deu certo no resultado tagueado.
//   value: o valor de domínio (observação, mensagem, etc.)
// Devolve { tag: "ok", value }.
// Exemplo: ok({ tick: 3 })  // => { tag: "ok", value: { tick: 3 } }
export const ok = (value) => ({ tag: "ok", value });

// err(reason): embrulha um parse que falhou.
//   reason: string curta com o motivo (ex: "obs sem tick")
// Devolve { tag: "error", reason }.
// Exemplo: err("obs sem tick")  // => { tag: "error", reason: "obs sem tick" }
export const err = (reason) => ({ tag: "error", reason });

// int: token -> inteiro base-10, ou null se o token não for inteiro.
// Uso interno; qualquer null torna a linha malformada.
const int = (tok) => {
  // inteiros base-10; qualquer outra coisa torna a linha malformada
  if (!/^-?\d+$/.test(tok)) return null;
  return parseInt(tok, 10);
};

// parseCell(tok): uma célula da observação -> objeto de domínio.
//   tok: string "x,y,terrain,owner,fortified" (tokens extras na célula
//        são ignorados)
// Devolve { x, y, terrain, owner, fortified } ou null se malformada.
// Exemplo:
//   parseCell("3,4,forest,2,0")  // => { x: 3, y: 4, terrain: "forest", owner: 2, fortified: 0 }
export function parseCell(tok) {
  const f = tok.split(",");
  if (f.length < 5) return null;
  const [x, y, owner, fortified] = [int(f[0]), int(f[1]), int(f[3]), int(f[4])];
  if (x === null || y === null || owner === null || fortified === null) return null;
  return { x, y, terrain: f[2], owner, fortified };
}

// cellList: token "cel;cel;..." -> array de células, [] se vazio/ausente,
// null se qualquer célula for malformada. Uso interno.
const cellList = (tok) => {
  if (tok === undefined || tok === "") return [];
  const cells = tok.split(";").map(parseCell);
  return cells.includes(null) ? null : cells;
};

// E1: uma linha OBS -> observação de domínio.
// TODO E1: implemente. O formato da linha é:
//   OBS <ref> <tick> <status> <scores_tick> <celulas>
// status é "alive" ou "dead"; celulas é a lista separada por ";"
// (parseCell e cellList acima já existem, use-as). Devolva:
//   ok({ ref, tick, status, scoresTick, cells })  ou  err("motivo")
// Linha malformada vira err(...), nunca exceção. Tokens extras no final
// são ignorados (é o que salva o seu cliente no drill da v2).
export function parseObservation(line) {
  return err("TODO E1: implemente parseObservation");
}

// parseLine(line): despacha uma linha crua do socket para a mensagem de
// domínio correspondente (OBS, WELCOME, ACK, NACK, ERR, SCORE, DIFF, PONG;
// no lado do simulador também HELLO, ACT e PING).
//   line: string crua recebida do servidor (ex: "ACK r-1 12")
// Devolve ok(mensagem) ou err(motivo). Nunca lança exceção; tokens extras
// no final são ignorados.
// Exemplos:
//   parseLine("ACK r-1 12")
//   // => ok({ type: "ack", ref: "r-1", tick: 12 })
//   parseLine("NACK r-1 bad_cell fora do alcance")
//   // => ok({ type: "nack", ref: "r-1", code: "bad_cell", detail: "fora do alcance" })
//   parseLine("linha qualquer")
//   // => err("tipo desconhecido linha")
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
