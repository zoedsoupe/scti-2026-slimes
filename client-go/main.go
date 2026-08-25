package main

// Loop do cliente: conecta, cumprimenta, e a cada OBS decide e age.
// Em erro de leitura ou fechamento, reconecta com o mesmo nome apos 1s
// (o servidor retoma colonias vivas pelo nome).
//
// Uso:
//
//	go mod tidy
//	SLIMES_URL=ws://localhost:4000/ws SLIMES_NAME=aurora go run .

import (
	"context"
	"fmt"
	"os"
	"time"

	"github.com/coder/websocket"
)

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func main() {
	url := getenv("SLIMES_URL", "ws://localhost:4000/ws")
	name := getenv("SLIMES_NAME", "goslime")

	for {
		if err := run(url, name); err != nil {
			fmt.Printf("conexao caiu: %v\n", err)
		}
		time.Sleep(1 * time.Second)
	}
}

func run(url, name string) error {
	ctx := context.Background()

	conn, _, err := websocket.Dial(ctx, url, nil)
	if err != nil {
		return err
	}
	defer conn.Close(websocket.StatusNormalClosure, "fim")

	send := func(line string) error {
		return conn.Write(ctx, websocket.MessageText, []byte(line))
	}

	refs := NewRefs(name)
	myID := 0
	pending := map[string]PendingEntry{}

	if err := send(EncodeHello(refs.Next(), "colony", name)); err != nil {
		return err
	}

	for {
		_, data, err := conn.Read(ctx)
		if err != nil {
			return err
		}
		msg, err := ParseLine(string(data))
		if err != nil {
			fmt.Printf("linha malformada: %v\n", err)
			continue
		}

		switch msg.Type {
		case "welcome":
			myID = msg.ID
			fmt.Printf("entrei como %s (id %d), cor #%s\n", msg.Name, myID, msg.Color)
		case "obs":
			var effects []Effect
			pending, effects = OnTimeout(pending, msg.Tick)
			for _, e := range effects {
				if !e.Drop {
					if err := send(e.Line); err != nil {
						return err
					}
				}
			}
			if msg.Status == "alive" && myID != 0 {
				action := Decide(msg, myID)
				ref := refs.Next()
				line := EncodeAction(action, ref)
				pending = AddPending(pending, ref, line, msg.Tick)
				if err := send(line); err != nil {
					return err
				}
			}
		case "ack":
			pending = OnAck(pending, msg.Ref)
		case "nack":
			fmt.Printf("NACK %s: %s\n", msg.Code, msg.Detail)
		case "err":
			fmt.Printf("ERR %s: %s\n", msg.Code, msg.Detail)
		}
	}
}
