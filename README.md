# Slimes

**Slimes** é uma arena de colônias competitiva/cooperativa criada para o minicurso da **SCTI 2026** (Semana de Ciência da Computação e Tecnologia da Informação, UENF), em setembro de 2026.

Cada participante escreve um **cliente** que controla uma colônia de slime se espalhando por uma grade: expandir, atacar, fortificar ou passar a vez. Este repositório contém o jogo inteiro:

- o **servidor** (Elixir, Bandit + WebSocket), que mantém o estado do mundo e resolve os ticks;
- o **cliente oficial** em JavaScript puro no navegador, sem build (a única runtime garantida no laboratório);
- **clientes não oficiais** em Elixir, Python e Go, para quem quiser ir além.

O desenho do projeto é a aplicação prática da tese **Functional Core, Imperative Shell**: a resolução de ticks é uma função pura, e todos os efeitos (sockets, timers, broadcasts) ficam na borda. O minicurso também exercita parse-don't-validate, desenho de API pública e semântica de RPC (refs, acks, retry, idempotência).

## Como rodar o servidor

Requer Elixir 1.20+ e Erlang/OTP 28.

```sh
mix deps.get
mix run --no-halt
```

O servidor sobe com Bandit e expõe:

- `GET /ws`: endpoint WebSocket do protocolo do jogo.
- `GET /debug/log`: log de eventos da partida em JSONL.
- `GET /kit.zip`: kit do cliente (`client-js/kit/` mais `docs/PROTOCOL.md` e `docs/WORKSHOP.md`, empacotado por `./scripts/build_kit.sh`).
- arquivos estáticos do projetor em `projector/`.

Modo cooperativo (ataques desabilitados): `mix run --no-halt -- --no-attacks` (a flag vai depois do `--`). O padrão é o modo torneio.

## Protocolo

O fio entre cliente e servidor é um protocolo de texto, uma mensagem por linha, um frame WebSocket por linha. Nada de JSON na conexão: o aluno escreve um parser de verdade, e o tráfego fica legível nas devtools do navegador. Exemplos:

```
HELLO v1 aurora-k3f9-1 colony aurora
ACT aurora-k3f9-17 expand 12 7
OBS srv-97 97 alive 97 9,5,plain,0,0;10,5,plain,3,1
SCORE srv-97 97 3,aurora,21,alive;5,nova,14,dead
```

O contrato completo está em [`docs/PROTOCOL.md`](docs/PROTOCOL.md) (em português, é o documento que os participantes leem). Se qualquer outro material divergir dele, o `PROTOCOL.md` está certo.

## Documentos

- [`docs/PROTOCOL.md`](docs/PROTOCOL.md): contrato público do protocolo, v1.
- [`docs/SERVER_SPEC.md`](docs/SERVER_SPEC.md): especificação de implementação do servidor.
- [`docs/GOLDEN.md`](docs/GOLDEN.md): formato das fixtures douradas usadas nos testes de paridade entre servidor e simulador JS.

## Testes

```sh
mix test                      # suíte normal
mix test --include golden     # emite priv/golden/*.jsonl para paridade com o simulador
mix replay caminho/log.jsonl  # reexecuta um log de partida e imprime o placar final
```

## Como rodar o cliente JavaScript

Não precisa de Node nem de build. Da raiz do repositório:

```sh
python3 -m http.server
```

Abra `http://localhost:8000/client-js/`. No campo "servidor", `local` usa o simulador em processo (funciona sem rede nenhuma, com dois bots); para jogar contra o servidor de verdade, use `ws://<ip-do-mac>:4000/ws`. Módulos ES não carregam via `file://`, por isso o `http.server`.

Os testes do cliente rodam na página `http://localhost:8000/client-js/test/` ou, se houver Node instalado, com `node client-js/test/run_node.js` (a mesma suíte, incluindo a paridade com `priv/golden/`).

O projetor (visão de espectador para a sala) é servido pelo próprio servidor em `http://<ip-do-mac>:4000/`.

## Runbook do dia

Para quem for operar a sala, sem precisar de contexto do projeto:

1. **Antes de tudo**: no Mac do instrutor, `mix deps.get && iex -S mix`. O shell fica aberto de propósito: na demo final dá para inspecionar o estado ao vivo (`:sys.get_state(Slimes.World)` mostra a tabela de deduplicação).
2. Anote o IP do Mac (`ipconfig getifaddr en0`) e escreva no quadro: `ws://<ip>:4000/ws` para os clientes e `http://<ip>:4000/` para o projetor. Abra o projetor na TV/projetor da sala.
3. **Fase cooperativa**: suba o servidor com `iex -S mix run --no-halt -- --no-attacks` (a flag vai depois do `--`). Nesse modo o servidor rejeita `attack` com `NACK attacks_disabled`. Para o torneio, reinicie sem a flag, com `iex -S mix`.
4. **Reiniciar é partida nova.** Não existe recuperação de estado e isso é deliberado: partidas são curtas e o formato de torneio espera várias rodadas. Se um log importar, salve `curl http://localhost:4000/debug/log > partida.jsonl` **antes** de reiniciar. Depois dá para reexecutar com `mix replay partida.jsonl`.
5. **Wifi da universidade falhou?** Ligue o hotspot do celular e conecte o Mac e as máquinas da sala nele. Se a rede inteira morrer, o minicurso continua: cada dupla desenvolve contra o simulador local (`local` no campo servidor), e só o torneio é afetado.
6. **Para reproduzir uma partida** (mesma seed, mesmos spawns): suba com `SLIMES_SEED=42 iex -S mix`. Sem a variável, a seed é sorteada a cada boot.
7. O kit dos alunos (`student-kit.zip`) é servido em `http://<ip>:4000/kit.zip`, para distribuição não depender de internet.

Antes do evento, siga o checklist em `docs/CHECKLIST.md` (regenerar goldens, teste de carga com 20 clientes, zip do kit, teste do hotspot).
