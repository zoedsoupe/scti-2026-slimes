# Golden fixture format, v1

Shared contract between the server (emits, `priv/golden/*.jsonl`) and the JS simulator (replays, parity tests). This format is **internal tooling**, not the wire protocol: the wire is the text protocol in `PROTOCOL.md`; fixtures are JSONL because they are machine-written and machine-read only.

One file per scenario. One JSON object per line, in this exact order:

## Line 1: config

```json
{
  "kind": "config",
  "base_seed": 42,
  "grid": { "w": 60, "h": 40 },
  "tick_ms": 1000,
  "view_radius": 3,
  "mode": "tournament",
  "terrain": [[11, 5, "forest"]]
}
```

`terrain` lists every non-plain cell. `mode` is `"cooperative"` or `"tournament"`.

## Line 2: spawns

```json
{
  "kind": "spawns",
  "colonies": [
    { "id": 1, "name": "aurora", "cell": [4, 34] },
    { "id": 2, "name": "nova", "cell": [55, 5] }
  ]
}
```

Spawn cells are precomputed with the same seeded RNG the server uses, so replay never calls the spawn logic.

## Lines 3..N-1: one per tick

```json
{
  "kind": "tick",
  "tick": 1,
  "actions": [{ "colony": 1, "kind": "expand", "cell": [4, 33] }],
  "diff": [[4, 33, 1, 0]],
  "scores": [
    { "id": 1, "cells": 2, "alive": true },
    { "id": 2, "cells": 1, "alive": true }
  ]
}
```

| field     | rule                                                                                     |
| --------- | ---------------------------------------------------------------------------------------- |
| `actions` | in the exact seeded resolution order for that tick, already validated; `pass` is omitted |
| `diff`    | cell changes as `[x, y, owner, fortified]`, same shape as the wire `DIFF`                |
| `scores`  | full scoreboard after resolution, ordered by colony id                                   |

A tick with no actions has `"actions": []` and usually an empty `diff`.

## Last line: final

```json
{
  "kind": "final",
  "tick": 3,
  "scores": [
    { "id": 1, "cells": 4, "alive": true },
    { "id": 2, "cells": 1, "alive": true }
  ]
}
```

## Replay contract (what the simulator must do)

1. Build the initial grid from `config.terrain` + `spawns` (each spawn cell owned by its colony).
2. For each `tick` line: apply `actions` through the resolver, collect the resulting cell changes.
3. Assert the computed changes equal `diff` (order-insensitive) and the computed scoreboard equals `scores`.
4. Assert the last computed scoreboard equals `final.scores`.

Any mismatch fails the parity test on the simulator side, and the corresponding golden test on the server side.

## Example (3 ticks)

```json
{"kind": "config", "base_seed": 42, "grid": {"w": 60, "h": 40}, "tick_ms": 1000, "view_radius": 3, "mode": "tournament", "terrain": []}
{"kind": "spawns", "colonies": [{"id": 1, "name": "aurora", "cell": [4, 34]}, {"id": 2, "name": "nova", "cell": [55, 5]}]}
{"kind": "tick", "tick": 1, "actions": [{"colony": 1, "kind": "expand", "cell": [4, 33]}, {"colony": 2, "kind": "expand", "cell": [55, 6]}], "diff": [[4, 33, 1, 0], [55, 6, 2, 0]], "scores": [{"id": 1, "cells": 2, "alive": true}, {"id": 2, "cells": 2, "alive": true}]}
{"kind": "tick", "tick": 2, "actions": [{"colony": 1, "kind": "fortify", "cell": [4, 34]}], "diff": [[4, 34, 1, 1]], "scores": [{"id": 1, "cells": 2, "alive": true}, {"id": 2, "cells": 2, "alive": true}]}
{"kind": "tick", "tick": 3, "actions": [], "diff": [], "scores": [{"id": 1, "cells": 2, "alive": true}, {"id": 2, "cells": 2, "alive": true}]}
{"kind": "final", "tick": 3, "scores": [{"id": 1, "cells": 2, "alive": true}, {"id": 2, "cells": 2, "alive": true}]}
```
