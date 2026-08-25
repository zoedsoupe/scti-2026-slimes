package main

// Parse e encode das linhas do protocolo, na fronteira.
// Regra do PROTOCOL.md: tokens extras no final são ignorados (leitor
// tolerante), linha malformada devolve erro e nunca panica.
// Refs: <nome>-<sessão>-<n>, sessão de 4 chars gerada uma vez por processo.

import (
	"fmt"
	"math/rand"
	"strconv"
	"strings"
)

// --- tipos de domínio ------------------------------------------------------

type Cell struct {
	X, Y      int
	Terrain   string
	Owner     int
	Fortified int
}

type ScoreEntry struct {
	ID     int
	Name   string
	Cells  int
	Status string
}

type Change struct {
	X, Y, Owner, Fortified int
}

// Message carrega qualquer mensagem servidor -> cliente; Type discrimina.
type Message struct {
	Type string // "welcome", "obs", "ack", "nack", "err", "score", "diff", "pong"
	Ref  string

	// welcome
	Role       string // "colony" ou "spectator"
	ID         int
	Name       string
	Color      string
	W, H       int
	TickMs     int
	ViewRadius int
	SpawnX     int
	SpawnY     int

	// obs / score / diff
	Tick       int
	Status     string
	ScoresTick int
	Cells      []Cell
	Entries    []ScoreEntry
	Changes    []Change

	// nack / err
	Code   string
	Detail string
}

// Action é a decisão da estratégia, antes do encode.
type Action struct {
	Kind string // "expand", "attack", "fortify", "pass"
	X, Y int
}

// --- encode ----------------------------------------------------------------

type Refs struct {
	name, session string
	n             int
}

func NewRefs(name string) *Refs {
	return &Refs{name: name, session: newSession()}
}

func (r *Refs) Next() string {
	r.n++
	return fmt.Sprintf("%s-%s-%d", r.name, r.session, r.n)
}

func newSession() string {
	const alpha = "abcdefghijklmnopqrstuvwxyz0123456789"
	b := make([]byte, 4)
	for i := range b {
		b[i] = alpha[rand.Intn(len(alpha))]
	}
	return string(b)
}

func EncodeHello(ref, role, name string) string {
	if role == "spectator" {
		return fmt.Sprintf("HELLO v1 %s spectator", ref)
	}
	return fmt.Sprintf("HELLO v1 %s colony %s", ref, name)
}

func EncodeAction(a Action, ref string) string {
	if a.Kind == "pass" {
		return fmt.Sprintf("ACT %s pass", ref)
	}
	return fmt.Sprintf("ACT %s %s %d %d", ref, a.Kind, a.X, a.Y)
}

func EncodePing(ref string) string {
	return fmt.Sprintf("PING %s", ref)
}

// --- parse -----------------------------------------------------------------

func atoi(tok string) (int, bool) {
	n, err := strconv.Atoi(tok)
	return n, err == nil
}

func tok(t []string, i int) string {
	if i < len(t) {
		return t[i]
	}
	return ""
}

// célula: x,y,terrain,owner,fortified (tokens extras na célula ignorados)
func ParseCell(tok string) (Cell, bool) {
	f := strings.Split(tok, ",")
	if len(f) < 5 {
		return Cell{}, false
	}
	x, ok1 := atoi(f[0])
	y, ok2 := atoi(f[1])
	owner, ok3 := atoi(f[3])
	fortified, ok4 := atoi(f[4])
	if !ok1 || !ok2 || !ok3 || !ok4 {
		return Cell{}, false
	}
	return Cell{X: x, Y: y, Terrain: f[2], Owner: owner, Fortified: fortified}, true
}

func parseCellList(tok string) ([]Cell, bool) {
	if tok == "" {
		return nil, true
	}
	parts := strings.Split(tok, ";")
	cells := make([]Cell, 0, len(parts))
	for _, p := range parts {
		c, ok := ParseCell(p)
		if !ok {
			return nil, false
		}
		cells = append(cells, c)
	}
	return cells, true
}

// E1: uma linha OBS crua -> observação de domínio.
func ParseObservation(line string) (Message, error) {
	t := strings.Split(line, " ")
	if t[0] != "OBS" {
		return Message{}, fmt.Errorf("tipo inesperado %s", t[0])
	}
	return parseObservation(t)
}

func parseObservation(t []string) (Message, error) {
	tick, ok1 := atoi(tok(t, 2))
	scoresTick, ok2 := atoi(tok(t, 4))
	if !ok1 || !ok2 {
		return Message{}, fmt.Errorf("tick ausente ou invalido")
	}
	status := tok(t, 3)
	if status != "alive" && status != "dead" {
		return Message{}, fmt.Errorf("status invalido %s", status)
	}
	cells, ok := parseCellList(tok(t, 5))
	if !ok {
		return Message{}, fmt.Errorf("lista de celulas malformada")
	}
	return Message{
		Type: "obs", Ref: tok(t, 1), Tick: tick,
		Status: status, ScoresTick: scoresTick, Cells: cells,
	}, nil
}

func parseWelcome(t []string) (Message, error) {
	if tok(t, 2) == "spectator" {
		w, ok1 := atoi(tok(t, 3))
		h, ok2 := atoi(tok(t, 4))
		tickMs, ok3 := atoi(tok(t, 5))
		if !ok1 || !ok2 || !ok3 {
			return Message{}, fmt.Errorf("welcome de espectador malformado")
		}
		cells, ok := parseCellList(tok(t, 6))
		if !ok {
			return Message{}, fmt.Errorf("snapshot malformado")
		}
		return Message{
			Type: "welcome", Role: "spectator", W: w, H: h, TickMs: tickMs, Cells: cells,
		}, nil
	}
	id, ok1 := atoi(tok(t, 2))
	w, ok2 := atoi(tok(t, 5))
	h, ok3 := atoi(tok(t, 6))
	tickMs, ok4 := atoi(tok(t, 7))
	viewRadius, ok5 := atoi(tok(t, 8))
	if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 {
		return Message{}, fmt.Errorf("welcome malformado")
	}
	spawn := strings.Split(tok(t, 9), ",")
	if len(spawn) < 2 {
		return Message{}, fmt.Errorf("spawn malformado")
	}
	sx, ok6 := atoi(spawn[0])
	sy, ok7 := atoi(spawn[1])
	if !ok6 || !ok7 {
		return Message{}, fmt.Errorf("spawn malformado")
	}
	return Message{
		Type: "welcome", Role: "colony", ID: id, Name: tok(t, 3), Color: tok(t, 4),
		W: w, H: h, TickMs: tickMs, ViewRadius: viewRadius, SpawnX: sx, SpawnY: sy,
	}, nil
}

func parseScore(t []string) (Message, error) {
	tick, ok := atoi(tok(t, 2))
	if !ok {
		return Message{}, fmt.Errorf("score sem tick")
	}
	var entries []ScoreEntry
	for _, e := range strings.Split(tok(t, 3), ";") {
		if e == "" {
			continue
		}
		f := strings.Split(e, ",")
		id, ok1 := atoi(tok(f, 0))
		cells, ok2 := atoi(tok(f, 2))
		if !ok1 || !ok2 {
			return Message{}, fmt.Errorf("score malformado")
		}
		entries = append(entries, ScoreEntry{
			ID: id, Name: tok(f, 1), Cells: cells, Status: tok(f, 3),
		})
	}
	return Message{Type: "score", Ref: tok(t, 1), Tick: tick, Entries: entries}, nil
}

func parseDiff(t []string) (Message, error) {
	tick, ok := atoi(tok(t, 2))
	if !ok {
		return Message{}, fmt.Errorf("diff sem tick")
	}
	var changes []Change
	for _, c := range strings.Split(tok(t, 3), ";") {
		if c == "" {
			continue
		}
		f := strings.Split(c, ",")
		x, ok1 := atoi(tok(f, 0))
		y, ok2 := atoi(tok(f, 1))
		owner, ok3 := atoi(tok(f, 2))
		fortified, ok4 := atoi(tok(f, 3))
		if !ok1 || !ok2 || !ok3 || !ok4 {
			return Message{}, fmt.Errorf("diff malformado")
		}
		changes = append(changes, Change{X: x, Y: y, Owner: owner, Fortified: fortified})
	}
	return Message{Type: "diff", Ref: tok(t, 1), Tick: tick, Changes: changes}, nil
}

func ParseLine(line string) (Message, error) {
	t := strings.Split(line, " ")
	switch t[0] {
	case "OBS":
		return ParseObservation(line)
	case "WELCOME":
		return parseWelcome(t)
	case "ACK":
		tick, ok := atoi(tok(t, 2))
		if !ok {
			return Message{}, fmt.Errorf("ack sem tick")
		}
		return Message{Type: "ack", Ref: tok(t, 1), Tick: tick}, nil
	case "NACK":
		if len(t) < 3 {
			return Message{}, fmt.Errorf("nack malformado")
		}
		return Message{
			Type: "nack", Ref: t[1], Code: t[2], Detail: strings.Join(t[3:], " "),
		}, nil
	case "ERR":
		if len(t) < 3 {
			return Message{}, fmt.Errorf("err malformado")
		}
		return Message{
			Type: "err", Ref: t[1], Code: t[2], Detail: strings.Join(t[3:], " "),
		}, nil
	case "SCORE":
		return parseScore(t)
	case "DIFF":
		return parseDiff(t)
	case "PONG":
		return Message{Type: "pong", Ref: tok(t, 1)}, nil
	default:
		return Message{}, fmt.Errorf("tipo desconhecido %s", t[0])
	}
}
