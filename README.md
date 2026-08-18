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
- `GET /kit.zip`: kit do cliente.
- arquivos estáticos do projetor em `projector/`.

Modo cooperativo (ataques desabilitados): rode com a flag `--no-attacks`. O padrão é o modo torneio.

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
