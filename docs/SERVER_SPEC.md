# Slimes server protocol implementation spec, v1

Implementer-facing spec for the Elixir server (SLI-201 to SLI-205). It restates the frozen contract from the server's side of the socket: what arrives, what you must send back, in which order, and which decisions are yours to make.

**Authorities, in order:**

1. `docs/PROTOCOL.md`: the wire contract. If this spec and PROTOCOL.md diverge, PROTOCOL.md wins and this spec is wrong.
2. `../SCRIPT.md` Section 2: the world rules (tick resolution, RNG, spawn, modes).
3. `docs/GOLDEN.md`: the fixture format your ExUnit suite emits.

Contract rule from TASKS.md: no improvisation on the protocol. Anything wire-visible that is not pinned here goes back to SCRIPT.md Section 1 before you invent it.

---

## 1. Transport and process model

- Bandit + Plug + WebSockAdapter. No Phoenix. Deps: `bandit`, `plug`, `websock_adapter`, built-in `JSON` (JSON only for `/debug/log` and golden fixtures, never on the wire).
- Plug router: one WebSocket endpoint, `GET /debug/log`, `GET /kit.zip`, `Plug.Static` for `projector/`.
- One WebSock handler process per socket. The handler owns the socket and parses text lines into domain messages at the boundary. World never sees a raw line or a socket.
- One `Slimes.World` GenServer: grid state, tick loop via `Process.send_after/3`, `colony_id => handler_pid` map, spectator pid list, dedup table, event log.
- Outbound path: `World -> Process.send/2 -> handler handle_info -> WebSock frame`. One frame carries exactly one line.

## 2. Inbound parsing rules (per socket handler)

- Each frame is one line. Split on single spaces. Ignore unknown trailing tokens (tolerant reader).
- Parse the line into a domain type at the boundary. A malformed line or unknown message type answers `ERR <ref> bad_message <detail>` and never crashes the handler or closes the socket by itself.
- If the line cannot yield a ref (garbage from token one), still answer `ERR` with the best-effort ref token or a placeholder; never stay silent.
- The version token exists only in `HELLO`. Every later message on that socket is assumed v1. A `HELLO` with any other version answers `ERR <ref> bad_version` and the socket is not joined.
- Numbers: coordinates, ids, ticks and dimensions are base-10 integers. A token that fails integer conversion makes the line malformed (`bad_message`), not a domain error.

## 3. Connection lifecycle

State machine per socket: `connected -> awaiting_hello -> joined`. `HELLO` is valid only as the first message, sent once.

### 3.1 HELLO as colony

`HELLO v1 <ref> colony <name>`

Validation order:

1. Version = `v1`, else `ERR bad_version`.
2. Name matches `[a-z0-9-]{1,16}`, is not `spectator`, and is not the name of a currently live colony, else `NACK <ref> bad_name`.
3. Rejoin policy:
   - Name owned by a **live** colony: resume it. Same colony id, same color, state intact. Answer `WELCOME` with the original spawn. Point the `colony_id => handler_pid` entry at the new handler.
   - Name owned by an **eliminated** colony: fresh join. New id, new spawn, new color.
   - New name: fresh join.

On join, answer:

```
WELCOME srv-0 <colony_id> <name> <color-hex-no-#> <w> <h> <tick_ms> <view_radius> <x,y>
```

Note: the frozen examples show `WELCOME` carrying `srv-0`, not the HELLO ref. Follow the examples: `srv-0` for every WELCOME.

Colony ids: numeric, assigned in join order starting at 1. Colors: assigned in join order from the palette pink `#F5C2E7`, blue `#96CDFB`, cyan `#8BD5CA`, green `#ABE9B3`, orange `#F8BD96`, red `#F28FAD`, then deterministic lighter/darker shades for colonies 7-15. Keep `id -> color` a pure function of join order so spectator clients (which never receive colors) can derive the same palette from colony ids.

From the next tick after joining, the colony receives `OBS`.

### 3.2 HELLO as spectator

`HELLO v1 <ref> spectator`

Answer once:

```
WELCOME srv-0 spectator <w> <h> <tick_ms> <cell>;<cell>;...
```

Every cell of the grid as `x,y,terrain,owner,fortified`. This is the only message that carries terrain in full. Add the pid to the spectator list: it receives `DIFF` and `SCORE` per tick, never `OBS`.

## 4. Actions (ACT)

`ACT <ref> <kind> [x y]`, kinds `expand | attack | fortify | pass`. Coordinates absolute, required unless `pass`.

Handle in this exact order:

1. **Dedup.** Look up `(colony_id, ref)` in the dedup table. Hit: send `NACK <ref> duplicate_ref` (informational) followed by the recorded original `ACK`, resend verbatim, do not reapply. Miss: continue.
2. **Arity and kind.** Unknown kind, missing coords on non-`pass`, non-integer coords: `ERR bad_message` (line malformed) or `NACK` with the closest table code; prefer `ERR bad_message` for shape errors.
3. **Mode.** `attack` in cooperative mode: `NACK <ref> attacks_disabled`. Check this before cell validity so cooperative-phase students get one consistent answer.
4. **Cell validity.** Out of grid or not adjacent to any cell the colony owns: `NACK bad_cell`.
5. **Kind-specific ownership.**
   - `expand` into an owned cell: `NACK not_empty`.
   - `attack` into a cell that is not enemy-owned (empty or own): `NACK not_enemy`.
   - `fortify` a cell the colony does not own: `NACK not_self`.
   - `fortify` an already-fortified own cell: normal `ACK`, action wasted. Deliberate; do not add an error code.
6. **Timing.** If the current tick window is still open: record the action as the colony's queued action for this tick, answer `ACK <ref> <tick>` with the tick it was accepted for, and store `(colony_id, ref) -> ack_payload` in the dedup table. If resolution already ran: `NACK <ref> too_late <detail>` and queue the action for the next tick. Late actions are never dropped silently.

At most one queued action per colony per tick: the **last valid action received during the window wins**. Earlier acked actions in the same window are simply overwritten in the queue; their ACKs already went out and stay valid history (ack means accepted, not applied).

`pass` is always valid and queues "no action" for the tick (useful to keep the dedup and ack flow uniform).

## 5. Tick loop and outbound streams

Tick = `tick_ms` (1000), server-authoritative, via `send_after`. Per tick, in order (SCRIPT.md Section 2):

1. Take each colony's queued action (at most one).
2. Shuffle colonies into resolution order with the tick-seeded RNG.
3. Phase 1, defense: apply all `fortify`.
4. Phase 2, expansion: apply `expand` and `attack` in seeded order. Conflicts resolve by that order; the losing action is wasted, not requeued. Unfortified enemy cell: taken. Fortified enemy cell: 50/50 by the tick-seeded RNG.
5. Orphan rule: per colony, flood fill; cells outside the largest component die. Ties keep the component containing the colony's oldest cell.
6. Colonies at 0 cells are eliminated.
7. Append all events to the in-memory event log, then broadcast.

Then send, all with ref `srv-<tick>`:

- **OBS** to each colony socket, alive or dead (dead colonies keep the socket open to watch):

  ```
  OBS srv-97 97 alive 97 <cell>;<cell>;...
  ```

  Tokens: tick, status, `scores_tick` (tick of the last scoreboard), cells. Cells are the union of the 7x7 neighborhoods (view radius 3) around every cell the colony owns, in-bounds cells only, each `x,y,terrain,owner,fortified`. `fortified` is included for every owner.

- **SCORE** to every socket (colonies and spectators), once per tick, including eliminated colonies:

  ```
  SCORE srv-97 97 3,aurora,21,alive;5,nova,14,dead
  ```

  Entries `id,name,cell_count,status`. Names and counts only, never positions.

- **DIFF** to spectator sockets only, once per tick:

  ```
  DIFF srv-97 97 12,7,3,0;12,8,0,0
  ```

  Changes as `x,y,owner,fortified` (no terrain; it is static). Must include cells that became empty (owner `0`), which is how eliminations and orphan deaths reach the projector.

There is no standalone tick message. The tick number rides inside `OBS` and `SCORE`.

## 6. PING, PONG, ERR

- `PING <ref>` answers `PONG <ref>` at any time after join.
- `ERR <ref> <code> <free text to end of line>` is for protocol-level faults: `bad_version`, `bad_message`.
- `NACK <ref> <code> <free text>` is for domain rejections of well-formed messages: everything else in the table.
- Keep free text ASCII (the frozen examples write `acao`, not `ação`). The grammar needs no escaping precisely because nothing forces it; do not be the thing that forces it.

Error code routing:

| code               | via  | when                                                         |
| ------------------ | ---- | ------------------------------------------------------------ |
| `bad_version`      | ERR  | HELLO with version other than `v1`                           |
| `bad_message`      | ERR  | malformed line, unknown type, bad arity, non-integer number  |
| `bad_name`         | NACK | invalid, reserved (`spectator`), or duplicate-of-live name   |
| `bad_cell`         | NACK | out of grid or not adjacent to the colony                    |
| `not_empty`        | NACK | expand into an owned cell                                    |
| `not_enemy`        | NACK | attack into empty or own cell                                |
| `not_self`         | NACK | fortify a cell the colony does not own                       |
| `attacks_disabled` | NACK | attack in cooperative mode                                   |
| `duplicate_ref`    | NACK | informational; the recorded original ACK follows immediately |
| `too_late`         | NACK | arrived after resolution; queued for next tick               |

## 7. Determinism and RNG

- Base seed chosen at boot. Per tick: `:rand.seed(:exsss, {base_seed, tick, 0})`. The same seed drives the resolution-order shuffle and fortified-attack coin flips.
- Spawn placement: seeded RNG, free cells maximizing distance to existing colonies, corners first. Seeded from the base seed plus join order so a match is reproducible from `{base_seed, join sequence, action log}`.
- The resolver is pure: `Slimes.World.Resolve.resolve(state, actions, rng) :: {new_state, events}`. Same inputs, same outputs, across runs. ExUnit covers each rule in isolation plus a determinism test.

## 8. Match modes

Boot flag `--no-attacks` selects cooperative mode; default is tournament. In cooperative mode `attack` NACKs `attacks_disabled` and every other rule is unchanged. A restart is a new match: accept state loss, no recovery.

## 9. Event log, replay, goldens

- Event log in memory only. `GET /debug/log` exports it as JSONL (built-in `JSON`).
- `mix replay path/to/log.jsonl` folds the log from the initial state and prints the final scoreboard. Replay of a real match log must reproduce its final scoreboard exactly.
- ExUnit emits `priv/golden/*.jsonl` on demand via `mix test --include golden`, in the format of `docs/GOLDEN.md`: line 1 config, line 2 precomputed spawns, one line per tick (actions in seeded resolution order, diff, full scoreboard), last line final scoreboard. The JS simulator replays these for parity; drift turns tests red on both sides.
- Load test: 20 concurrent scripted clients hold 1 tick/s without message loss.

## 10. Underspecified points (your call as server owner; decide once, keep consistent)

These are not pinned by PROTOCOL.md or SCRIPT.md. Recommended defaults, but they are decisions, not contract:

1. **WebSocket path.** TASKS.md says "WS endpoint" without a path. Pick `/ws` and tell the client side; it is wire-visible.
2. **Traffic before HELLO** (PING or ACT on an unjoined socket): answer `ERR bad_message` and keep the socket open. Never crash.
3. **Second HELLO on a joined socket:** `ERR bad_message`, ignore.
4. **OBS for an eliminated colony:** keep sending per tick with status `dead` and an empty cell list. The status token is what the client needs; the union of neighborhoods around zero cells is empty.
5. **Spawn RNG seed material:** goldens precompute spawns, so replay never re-runs spawn logic. Still make spawn deterministic from `{base_seed, join order}` for reproducible matches.
6. **NACK/ERR free text content:** free-form, but keep it short, factual, ASCII.
