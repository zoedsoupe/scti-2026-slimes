package main

// Loop do cliente: conecta, cumprimenta, e a cada OBS decide e age.
//
// Uso:
//
//	go mod tidy
//	SLIMES_URL=ws://localhost:4000/ws SLIMES_NAME=aurora go run .

import (
	"fmt"
	"log"
	"os"

	"github.com/gorilla/websocket"
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

	conn, _, err := websocket.DefaultDialer.Dial(url, nil)
	if err != nil {
		log.Fatal(err)
	}
	defer conn.Close()

	send := func(line string) {
		if err := conn.WriteMessage(websocket.TextMessage, []byte(line)); err != nil {
			log.Fatal(err)
		}
	}

	refs := NewRefs(name)
	myID := 0
	pending := map[string]PendingEntry{}

	send(EncodeHello(refs.Next(), "colony", name))

	for {
		_, data, err := conn.ReadMessage()
		if err != nil {
			log.Fatal(err)
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
					send(e.Line)
				}
			}
			if msg.Status == "alive" && myID != 0 {
				action := Decide(msg, myID)
				ref := refs.Next()
				line := EncodeAction(action, ref)
				pending = AddPending(pending, ref, line, msg.Tick)
				send(line)
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
