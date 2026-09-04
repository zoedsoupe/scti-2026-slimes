package main

// E3: a sua estratégia. observação -> ação, pura.
//
// TODO E3: implemente Decide. A observação é o que o seu parse do E1
// devolveu: Message{Type: "obs", Ref: ..., Tick: ..., Status: ...,
// ScoresTick: ..., Cells: ...}, onde cada célula é
// Cell{X, Y, Terrain, Owner, Fortified}. myID é o id da sua colônia
// (veio no WELCOME). Devolva uma Action:
//
//	Action{Kind: "expand" | "attack" | "fortify", X: x, Y: y}
//	ou Action{Kind: "pass"}
//
// Os helpers de observation.go já estão prontos e testados:
// Expandable (vazias adjacentes), Attackable (inimigas adjacentes),
// BorderCells (suas células na fronteira). Use-os.
//
// Dica nível 1 (sobrevivência): expanda para células vazias, nunca ataque
// célula fortificada. Dica nível 2 (expansão + defesa): fortifique
// fronteiras com inimigo ao lado, ataque inimigos desfortificados.
//
// Enquanto o stub estiver aqui a sua colônia só passa a vez.
func Decide(obs Message, myID int) Action {
	return Action{Kind: "pass"}
}
