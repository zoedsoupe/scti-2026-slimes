package main

// Política de retry pura sobre o mapa de pendentes.
// Nada aqui toca no socket: OnTimeout devolve o que fazer
// (retry ou drop) e a borda executa.
//
// INFRA: não edite este arquivo.

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

// AddPending registra uma linha enviada que ainda espera ACK.
//
// Parâmetros:
//   - pending: mapa ref -> entrada pendente (tratado como imutável)
//   - ref: ref da linha enviada
//   - line: a linha completa enviada ao servidor (guardada para reenvio)
//   - tick: tick em que a linha foi enviada
//
// Devolve um NOVO mapa com a entrada adicionada (Retries começa em 0).
//
// Exemplo:
//
//	pending = AddPending(pending, ref, line, msg.Tick)
func AddPending(pending map[string]PendingEntry, ref, line string, tick int) map[string]PendingEntry {
	next := make(map[string]PendingEntry, len(pending)+1)
	for k, v := range pending {
		next[k] = v
	}
	next[ref] = PendingEntry{Line: line, Tick: tick}
	return next
}

// OnAck confirma um pendente: o ACK chegou, o ref sai do mapa.
//
// Parâmetros:
//   - pending: mapa ref -> entrada pendente
//   - ref: ref confirmado pelo servidor
//
// Devolve um NOVO mapa sem o ref confirmado.
//
// Exemplo:
//
//	pending = OnAck(pending, msg.Ref)
func OnAck(pending map[string]PendingEntry, ref string) map[string]PendingEntry {
	next := make(map[string]PendingEntry, len(pending))
	for k, v := range pending {
		if k != ref {
			next[k] = v
		}
	}
	return next
}

// OnTimeout vence os pendentes antigos e decide o que fazer com cada um.
//
// Para cada ref com now - Tick >= Timeout:
//   - se Retries < Budget: agenda reenvio (Effect com Line preenchida),
//     incrementa Retries e atualiza Tick para now
//   - se Retries esgotou Budget: desiste (Effect com Drop: true),
//     o ref some do mapa
//
// Refs recentes ficam intactos. Devolve o NOVO mapa e a lista de efeitos;
// quem chama executa os efeitos (reenvia a linha ou descarta o ref).
//
// Exemplo:
//
//	pending, effects = OnTimeout(pending, msg.Tick)
//	for _, e := range effects {
//		if !e.Drop {
//			send(e.Line)
//		}
//	}
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
