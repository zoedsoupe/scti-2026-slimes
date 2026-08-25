# CHECKLIST.md — véspera e dia do minicurso

Lista do responsável. Execute de cima para baixo; cada item tem o comando exato. Rode tudo na raiz do repositório `slimes/`, no Mac do instrutor.

## Véspera

- [ ] Regenerar as fixtures golden: `mix test --include golden` e commitar o que mudar em `priv/golden/`.
- [ ] Rodar a suíte do servidor: `mix test`.
- [ ] Rodar os testes do cliente JS, incluindo a paridade com os goldens: `node client-js/test/run_node.js` (25 testes verdes).
- [ ] Teste de carga com 20 clientes: `mix test test/slimes/world_load_test.exs`.
- [ ] Regenerar o kit: `./scripts/build_kit.sh`. Verificar que `GET /kit.zip` devolve o zip (subir o servidor e baixar uma vez).
- [ ] Copiar `priv/student-kit.zip` para os dois pendrives. Testar um: máquina limpa, descompactar, `python3 -m http.server` na pasta `student-kit/`, página abre, testes aparecem vermelhos. Meta: menos de 2 minutos.
- [ ] Testar o hotspot do celular: Mac e mais uma máquina conectados, uma partida inteira no simulador apontando para o servidor real pelo IP do hotspot.
- [ ] Carregar o laptop reserva e conferir o carregador do Mac na mochila.

## Dia, antes da sala

- [ ] Subir o servidor na fase cooperativa: `iex -S mix` (boot com ataques desligados, ver README).
- [ ] Projetor em `http://<ip-do-mac>:4000`. URL do servidor WS (`ws://<ip-do-mac>:4000/ws`) escrita no quadro.
- [ ] Conferir que o projetor renderiza uma partida (dois clientes de simulador contra o servidor, ou bots).
- [ ] Wi-Fi da universidade instável? Trocar tudo para o hotspot antes da sala chegar.
- [ ] Pendrives na mesa da frente.

## Durante

- [ ] Antes de qualquer restart que importe: capturar `curl http://localhost:4000/debug/log > partida.jsonl`. Restart é partida nova, sem recuperação.
- [ ] 3:10: restart na v2 para o drill de versionamento (ver WORKSHOP.md).
- [ ] 3:20: restart sem `--no-attacks` para o torneio.

## Fechamento

- [ ] Capturar o `/debug/log` da última partida do torneio.
- [ ] Demo final conforme WORKSHOP.md: dedup por ref, replay com `mix replay`, derrubada de 30 segundos do servidor.
