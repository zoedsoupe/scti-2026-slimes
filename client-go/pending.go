package main

// Política de retry pura sobre o mapa de pendentes.
// Nada aqui toca no socket: OnTimeout devolve o que fazer
// (retry ou drop) e a borda executa.

const (
	Budget  = 3 // tentativas máximas por ref
	Timeout = 2 // ticks sem ACK antes de reenviar
)

type PendingEntry struct {
	Line    string
	Tick    int
	Retries int
}

type Effect struct {
	Ref  string
	Line string // preenchida em retry
	Drop bool
}

func AddPending(pending map[string]PendingEntry, ref, line string, tick int) map[string]PendingEntry {
	next := make(map[string]PendingEntry, len(pending)+1)
	for k, v := range pending {
		next[k] = v
	}
	next[ref] = PendingEntry{Line: line, Tick: tick}
	return next
}

func OnAck(pending map[string]PendingEntry, ref string) map[string]PendingEntry {
	next := make(map[string]PendingEntry, len(pending))
	for k, v := range pending {
		if k != ref {
			next[k] = v
		}
	}
	return next
}

// refs vencidos: retry enquanto couber no orçamento, drop no limite.
func OnTimeout(pending map[string]PendingEntry, now int) (map[string]PendingEntry, []Effect) {
	var effects []Effect
	next := make(map[string]PendingEntry, len(pending))
	for ref, entry := range pending {
		switch {
		case now-entry.Tick < Timeout:
			next[ref] = entry
		case entry.Retries < Budget:
			entry.Tick = now
			entry.Retries++
			next[ref] = entry
			effects = append(effects, Effect{Ref: ref, Line: entry.Line})
		default:
			effects = append(effects, Effect{Ref: ref, Drop: true})
		}
	}
	return next, effects
}
