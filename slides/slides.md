---
theme: default
title: "Slimes: protocolos, parsers e funções puras na prática"
info: |
  ## Slimes
  Minicurso prático: protocolos, parsers e funções puras.
  SCTI / UENF, 2026. Zoey de Souza Pessanha (@zoedsoupe).
author: Zoey de Souza Pessanha
colorSchema: dark
highlighter: shiki
lineNumbers: false
drawings:
  enabled: true
transition: slide-left
mdc: true
fonts:
  sans: 'Inter'
  serif: 'Inter'
  mono: 'JetBrains Mono'
  local: 'Space Grotesk'
  provider: google
  fallbacks: true
addons: []
download: true
favicon: ''
record: dev
selectable: true
defaults:
  layout: default
---

<style>
.autocomplete-list {
  display: none !important;
}

:global(#slidev-goto-dialog) {
  display: none !important;
}

.slidev-drawer {
  display: none !important;
}
</style>

# Slimes

### protocolos, parsers e funções puras - na prática

<div class="muted" style="margin-top:2.5em">

**Zoey de Souza Pessanha** - `@zoedsoupe`

SCTI - UENF - 2026

</div>

<!--
Abertura (0:00-0:10). Se a plateia veio da palestra, conectar em uma frase: "de manhã a gente viu a teoria, agora a gente escreve o código". Avisar o formato: 3 horas e meia, dá pra trabalhar sozinho ou em dupla (cada um escolhe), intervalo no meio, torneio no fim. Tempo: ~1 min.
-->

---
layout: statement
---

# Seu código vai jogar contra o de todo mundo aqui.

<div class="muted" style="margin-top:1em">

numa rede que perde mensagens. de propósito.

</div>

<!--
O gancho. Ler o slide em voz alta e deixar no ar uns 10 segundos. Depois explicar: até o fim do dia, cada pessoa (ou dupla) vai ter um programa jogando de verdade, contra os outros, num servidor de verdade. E a rede vai falhar, o servidor vai reiniciar, as regras vão mudar no meio do caminho. Tudo planejado - porque é assim que sistemas de verdade se comportam. Tempo: ~1 min.
-->

---

# O que hoje **é** (e o que **não é**)

<div style="margin-top:2em; font-size:1.1em">

<v-clicks>

- <span class="muted">não é</span> aula de JavaScript - JS é só a ferramenta que todo computador do lab já tem
- <span class="muted">não é</span> competição de algoritmo - o torneio é a desculpa, não o objetivo
- <span class="muted">é</span> construir um programa que conversa com um servidor pela rede
- <span class="muted">é</span> aprender, na prática, como programas trocam mensagens sem se perder
- <span class="muted">é</span> 3 horas e meia, sozinho ou em dupla (vocês escolhem), com intervalo e torneio no fim

</v-clicks>

</div>

<!--
Calibrar expectativa. Ponto importante: quem nunca programou em JavaScript não precisa ir embora. Os exercícios são pequenos, o kit tem comentários guiando cada passo, e trabalhar em dupla ajuda (mas é opcional). Tempo: ~1 min 30 s.
-->

---

# Como a gente vai aprender

<div style="margin-top:2em; font-size:1.1em">

<v-clicks>

1. **Prever**: antes de ver qualquer código, vocês chutam como funciona
2. **Rodar e investigar**: abrem o código pronto e comparam com o palpite
3. **Modificar e construir**: só então escrevem o código de vocês

</v-clicks>

</div>

<div class="muted" style="margin-top:2em">

sempre nessa ordem: primeiro entender, depois escrever.

</div>

<!--
Esse método tem nome (PRIMM), mas o nome não importa - o que importa é a ordem. Ninguém vai escrever código do zero no escuro: primeiro a gente entende o problema juntos, slide por slide, e só depois cada pessoa escreve a sua parte. Tempo: ~1 min.
-->

---

# O dia

| horário | o que acontece |
|---|---|
| 0:10-0:25 | **prever**: o que o servidor manda a cada segundo? |
| 0:25-1:00 | **rodar + investigar**: kit aberto, testes vermelhos, só leitura |
| 1:00-1:35 | **construir** E1 e E2: testes verdes no simulador |
| 1:35-1:45 | intervalo |
| 1:45-2:30 | **construir** E3: sua estratégia contra os bots |
| 2:30-2:50 | servidor real, fase **cooperativa** |
| 2:50-3:00 | as regras mudam: a sala inteira conserta junto |
| 3:00-3:20 | rodadas do **torneio** |
| 3:20-3:30 | demo final + fechamento |

<!--
Duas coisas pra cravar: (1) o minicurso está completo no fim do bloco das 2:30 - o resto é aprofundamento, não requisito; (2) quem travar levanta a mão, circular pela sala é o trabalho do instrutor. Tempo: ~1 min.
-->

---
layout: section
---

# PARTE 1

## O problema

<div class="muted" style="margin-top:1em">antes de qualquer código: o que estamos construindo?</div>

<!--
Transição. Tempo: ~15 s.
-->

---

# Pergunta pra sala

<div style="margin-top:2em; font-size:1.3em">

20 computadores querem jogar **o mesmo jogo**, ao mesmo tempo, cada um na sua máquina.

**Como eles combinam as regras e sabem o que aconteceu?**

</div>

<!--
PARE AQUI. De verdade: pergunte e espere respostas. Alguém vai dizer "um servidor", "um computador central", "a nuvem". A partir das respostas, conduzir: exato, a gente precisa de um juiz central - um computador que conhece o jogo inteiro, aplica as regras e conta pra cada jogador o que aconteceu. Esse juiz é o servidor. Tempo: ~2 min.
-->

---

# O juiz: o servidor

<v-clicks>

- o servidor é o **único** que conhece o jogo inteiro
- cada jogador roda um programa: o **cliente** - é ele que vocês vão escrever
- o cliente **pergunta** e **obedece**: quem decide se a jogada vale é o servidor
- servidor e cliente conversam trocando **mensagens de texto** pela rede

</v-clicks>

<v-click>

<div style="margin-top:1.5em">

> hoje, o jogo é o **Slimes**. mas esse desenho - um servidor, muitos clientes - é o mesmo de um banco, de um chat, de uma loja online.

</div>

</v-click>

<!--
A lição escondida: o jogo é a desculpa, o desenho é universal. Não precisa martelar isso agora - ele volta no fechamento. Tempo: ~2 min.
-->

---

# As regras do Slimes

<div class="muted">cinco regras. é tudo que vocês precisam saber.</div>

<!--
Só o título na tela: avisar que as regras vêm uma por vez nos próximos slides. Tempo: ~10 s.
-->

---

# Regra 1: o mundo é uma grade

<v-clicks>

- o mundo é uma grade de **60 por 40** casas
- cada pessoa (ou dupla) controla uma **colônia** de slime: um conjunto de casas na grade
- sua colônia começa pequena, num canto do mapa

</v-clicks>

<!--
Simples de propósito. Se ajudar, desenhar uma grade no quadro com duas colônias em cantos opostos. Tempo: ~1 min.
-->

---

# Regra 2: o tempo anda em ticks

<v-clicks>

- o jogo avança **um tick por segundo** - como os segundos de um relógio
- a cada tick, cada colônia faz **uma ação**
- o servidor junta as ações de todo mundo, aplica as regras e conta o resultado

</v-clicks>

<!--
Por que ticks e não tempo corrido: assim todo mundo joga o mesmo número de vezes, e a ordem dos eventos fica clara. É como um jogo de tabuleiro por correspondência, só que a rodada dura 1 segundo. Tempo: ~1 min 30 s.
-->

---

# Regra 3: quatro ações possíveis

<v-clicks>

- `expand` - crescer pra uma casa vizinha vazia
- `attack` - tomar uma casa vizinha do inimigo
- `fortify` - proteger uma casa sua: ela passa a resistir a ataque
- `pass` - não fazer nada nesse tick

</v-clicks>

<v-click>

<div style="margin-top:1.5em" class="muted">

uma ação por tick. escolher bem **qual** ação é o coração do jogo - e é o exercício 3.

</div>

</v-click>

<!--
Não decorar detalhe: o cheatsheet no kit tem tudo. O importante é que são só quatro verbos. Tempo: ~2 min.
-->

---

# Regra 4: você não vê o jogo inteiro

<v-clicks>

- seu cliente só enxerga a **vizinhança 7x7** ao redor das suas casas
- o resto do mapa é escuridão: você joga com informação parcial
- é como dirigir à noite: você só vê o que o farol ilumina

</v-clicks>

<v-click>

<div style="margin-top:1.5em" class="muted">

sistemas de verdade são assim: nenhum programa vê o mundo inteiro, só a parte que chega até ele.

</div>

</v-click>

<!--
Ponto pedagógico central: o cliente trabalha com informação incompleta, como todo sistema distribuído real. A consequência prática: a estratégia de vocês só pode usar o que está na vizinhança. Tempo: ~2 min.
-->

---

# Regra 5: sem casas, fim de jogo

<v-clicks>

- se a sua colônia perder todas as casas, ela **morre**
- mas ninguém sai da sala: eliminado vira **espectador** e assiste pelo projetor

</v-clicks>

<v-click>

<div style="margin-top:1.5em">

dois modos de jogo: **cooperativo** (ataques desligados, todo mundo cresce no seu canto) e **torneio** (vale tudo).

</div>

</v-click>

<!--
Fechar as regras. Perguntar se ficou dúvida antes de seguir - as regras são a base de tudo que vem depois. Tempo: ~1 min 30 s.
-->

---
layout: statement
---

# O servidor é a autoridade.

<div class="muted" style="margin-top:1em">

ele nunca confia que o seu cliente é educado.<br>
o seu cliente nunca confia que a rede é confiável.

</div>

<!--
As duas desconfianças que organizam o dia inteiro. Explicar devagar: o servidor valida tudo, porque um cliente pode mandar qualquer coisa - por bug ou de propósito. E o cliente trata mensagem perdida e mensagem quebrada, porque a rede falha. Guardar esse slide: cada exercício de hoje é uma dessas desconfianças virando código. Tempo: ~1 min.
-->

---
layout: section
---

# PARTE 2

## A conversa

<div class="muted" style="margin-top:1em">como cliente e servidor trocam mensagens</div>

<!--
Transição. Tempo: ~15 s.
-->

---

# Pergunta pra sala

<div style="margin-top:2em; font-size:1.3em">

Seu programa e o servidor estão em máquinas diferentes.

**Como um fala com o outro?**

</div>

<!--
Espere respostas: "internet", "wifi", "rede". Conduzir: sim, mas como exatamente? Um programa não pode gritar pela rede - os dois lados precisam combinar um jeito de conversar. Esse combinado tem duas partes, e os próximos slides mostram cada uma. Tempo: ~2 min.
-->

---

# Parte 1: a linha telefônica (WebSocket)

<v-clicks>

- o cliente **liga** pro servidor e a linha **fica aberta** o jogo inteiro
- os dois lados podem falar a qualquer momento, sem desligar e ligar de novo
- o nome dessa "linha" é **WebSocket** - o navegador já sabe fazer isso, vocês não escrevem essa parte

</v-clicks>

<v-click>

<div style="margin-top:1.5em" class="muted">

diferente de uma carta (manda, espera, manda outra): é uma ligação que não desliga.

</div>

</v-click>

<!--
Só o conceito importa: canal aberto, mão dupla. Detalhe técnico fica no kit, pronto. Tempo: ~2 min.
-->

---

# Parte 2: o idioma combinado (protocolo)

<v-clicks>

- a linha estar aberta não basta: os dois lados precisam falar **o mesmo idioma**
- esse idioma combinado é o **protocolo**: uma lista de mensagens, cada uma com um formato exato
- o nosso protocolo é **texto puro**: uma mensagem por linha, legível a olho nu, zero JSON

</v-clicks>

<v-click>

<div style="margin-top:1.5em">

por que texto e não JSON? porque vocês vão **escrever o tradutor** com as próprias mãos - e vão conseguir ler o tráfego inteiro nas ferramentas do navegador.

</div>

</v-click>

<!--
Analogia que funciona bem: protocolo é como o combinado de uma partida de xadrez por correspondência - todo mundo sabe o que "Cf3" significa, na mesma posição da carta. Se um lado escreve fora do combinado, o outro não entende. Tempo: ~2 min 30 s.
-->

---

# Como é uma conversa de verdade

<div class="muted">uma mensagem por linha. andar linha por linha no clique.</div>

```text {all|1|3|4|6|7|8|all}
HELLO v1 aurora-k3f9-1 colony aurora
WELCOME srv-0 3 aurora 96CDFB 60 40 1000 3 4,34

ACT aurora-k3f9-17 expand 12 7
ACK aurora-k3f9-17 97

OBS srv-97 97 alive 97 9,5,plain,0,0;10,5,plain,3,1
SCORE srv-97 97 3,aurora,21,alive;5,nova,14,dead
NACK aurora-k3f9-18 too_late tick 96 resolvido
```

<!--
Andar linha por linha, com calma: (1) o cliente se apresenta: "oi, sou a colônia aurora"; (2) o servidor dá boas-vindas e conta o tamanho do mundo; (3) o cliente manda uma ação: "expandir pra casa 12,7"; (4) o servidor confirma: "recebi"; (5) a cada tick o servidor conta o que o cliente enxerga e o placar; (6) e quando algo dá errado, ele avisa com um erro. Não decorar formato agora - só sentir que dá pra ler. Tempo: ~4 min.
-->

---

# Lendo a primeira mensagem

```text
HELLO v1 aurora-k3f9-1 colony aurora
```

<v-clicks>

- `HELLO`: **o tipo** da mensagem - toda linha começa assim, com um nome em maiúsculas
- `v1`: **a versão** do protocolo que o cliente fala (guarde esse `v1`, ele volta às 2:50)
- `aurora-k3f9-1`: uma **etiqueta única** dessa mensagem - a gente já chega nela
- `colony aurora`: o **conteúdo** - aqui, o nome da colônia

</v-clicks>

<v-click>

<div style="margin-top:1.5em">

toda mensagem é assim: **tipo** primeiro, depois os **campos**, separados por espaço.

</div>

</v-click>

<!--
Esse formato - tipo + campos - é o corpo inteiro do protocolo. Se a sala entender esse slide, o resto é repetição com outros tipos. Tempo: ~2 min 30 s.
-->

---

# Anatomia de uma OBS

<div class="muted">a mensagem que conta o que você enxerga, a cada tick</div>

```text
OBS srv-97 97 alive 97 9,5,plain,0,0;10,5,plain,3,1
```

<v-clicks>

- `srv-97`: a etiqueta do servidor - sempre `srv-` seguido do tick
- `97`: o tick que essa visão descreve
- `alive`: sua colônia está viva; depois de eliminado, vira `dead` e você só assiste
- o resto: as **casas** da sua vizinhança, separadas por `;`

</v-clicks>

<!--
Não mergulhar nas casas ainda - o próximo slide abre uma. Tempo: ~2 min.
-->

---

# Anatomia de uma casa

```text
9,5,plain,0,0
```

<v-clicks>

- `9,5`: a posição - coluna 9, linha 5
- `plain`: o terreno
- `0`: o dono - `0` significa **casa vazia**; qualquer outro número é o dono
- `0`: fortificada ou não - `1` significa fortificada

</v-clicks>

<v-click>

<div style="margin-top:1.5em">

a fortificação é **visível pra todo mundo**: dá pra ver o forte do inimigo antes de atacar. isso vira estratégia no exercício 3.

</div>

</v-click>

<v-click>

<div style="margin-top:1em">

> o contrato completo é o `PROTOCOL.md`, uma página, dentro do kit. em caso de dúvida, ele é a lei.

</div>

</v-click>

<!--
Ler a casa token por token, apontando. É exatamente essa leitura que vocês vão transformar em código no exercício 1. Tempo: ~3 min.
-->

---

# Pergunta pra sala

<div style="margin-top:2em; font-size:1.3em">

Seu cliente manda `expand 12 7`. Um segundo depois, chega uma resposta do servidor.

**Como você sabe a qual pedido essa resposta se refere?**

</div>

<!--
Espere. A resposta natural é "pela ordem", mas e se duas mensagens se cruzarem? E se a resposta demorar? Conduzir: a gente precisa de uma etiqueta em cada mensagem. Tempo: ~1 min 30 s.
-->

---

# A etiqueta: o ref

<v-clicks>

- toda mensagem do cliente carrega um **ref**: uma etiqueta única, tipo `aurora-k3f9-17`
- o formato é `<nome>-<sessão>-<número>`: o número cresce a cada mensagem
- a **sessão** (4 letras, sorteada a cada vez que a página abre) garante que ninguém repete etiqueta, nem depois de reconectar
- quando o servidor responde `ACK aurora-k3f9-17`, ele **repete a etiqueta**: é assim que você casa resposta com pedido

</v-clicks>

<!--
Analogia: senha de padaria. Você pega a senha 17, o atendente chama "17!", e você sabe que é a sua vez - não a da pessoa do lado. Tempo: ~3 min.
-->

---

# Pergunta pra sala

<div style="margin-top:2em; font-size:1.3em">

Você mandou `expand`. Passou o tick e **nenhuma resposta chegou**.

**O que aconteceu? E o que seu cliente deve fazer?**

</div>

<!--
Espere as hipóteses: a mensagem se perdeu, a resposta se perdeu, o servidor caiu. Os dois primeiros casos são iguais do ponto de vista do cliente: ele não sabe qual dos dois aconteceu! Essa é a parte importante - deixar a sala chegar nessa conclusão. Tempo: ~2 min.
-->

---

# Tentar de novo - sem aplicar duas vezes

<v-clicks>

- o cliente não sabe se o pedido ou a resposta se perderam - então ele **reenvia**, com a **mesma etiqueta**
- o servidor guarda as etiquetas que já aplicou: se o ref é repetido, ele **não aplica de novo** - só reenvia o `ACK` original
- reenviar é seguro: no máximo, você recebe a mesma confirmação duas vezes

</v-clicks>

<v-click>

<div style="margin-top:1.5em">

é por isso que pagamento online não cobra duas vezes quando você clica "pagar" de novo: a etiqueta única é a trava.

</div>

</v-click>

<!--
Conceito importante com nome feio (idempotência) - usar a analogia, não o nome. Se alguém perguntar o nome técnico, dar. Avisar: o reenvio com limite já vem implementado na casca do kit, vocês não escrevem essa parte - mas precisam entender, porque é o que salva o cliente de vocês na fase cooperativa. Tempo: ~3 min.
-->

---

# Quando a resposta é "não": o NACK

<v-clicks>

- nem toda resposta é `ACK`: se a jogada é inválida, o servidor responde `NACK`
- o `NACK` traz um **código de erro** de uma tabela fixa: `bad_cell`, `not_empty`, `not_enemy`, `too_late`...
- o código é pra **máquina** ler (curto, fixo); o resto da linha é texto livre, pro **humano** ler
- `too_late`: sua ação chegou depois do tick fechar - ela entra na fila do próximo tick, **nunca some em silêncio**

</v-clicks>

<v-click>

<div style="margin-top:1.5em" class="muted">

erro aqui não quebra nada: é só mais uma mensagem, com informação pro seu cliente decidir o que fazer.

</div>

</v-click>

<!--
E se a mensagem chegar tão quebrada que nem dá pra entender? O servidor responde ERR bad_message e a conexão continua aberta. Falha vira dado, não crash - essa frase prepara o próximo slide. Tempo: ~2 min 30 s.
-->

---

# Traduzir ou quebrar: o parser

<v-clicks>

- o que chega da rede é **texto cru**: uma linha que pode estar certa, errada ou pela metade
- antes de usar, o cliente **traduz**: a linha vira um dado organizado, com campos nomeados
- essa tradução se chama **parser** - e ela acontece **uma vez só, na entrada**
- depois dela, nenhum outro pedaço do código toca em texto cru

</v-clicks>

<v-click>

<div style="margin-top:1.5em">

regra de ouro: linha malformada vira **resposta de erro**, nunca exceção. o programa não pode cair porque a rede mandou lixo.

</div>

</v-click>

<!--
O nome disso é "parse, don't validate" - citar o nome pra quem quiser pesquisar depois. A ideia em uma frase: a bagunça fica na fronteira; dentro do programa, só dado limpo. Tempo: ~3 min.
-->

---

# O leitor tolerante

<v-clicks>

- e se chegar uma linha com **campos a mais** no final?
- resposta: **ignore os extras** e fique com o que você conhece
- parser que exige o formato exato quebra na primeira mudança; parser tolerante sobrevive

</v-clicks>

<v-click>

<div style="margin-top:1.5em">

guarde essa regra. às 2:50 o protocolo muda - e ela é a diferença entre consertar em 2 minutos ou reescrever tudo.

</div>

</v-click>

<!--
Não explicar o drill ainda - só plantar a semente. Tempo: ~1 min 30 s.
-->

---
layout: section
---

# PARTE 3

## O código

<div class="muted" style="margin-top:1em">função pura, testes e o mapa do kit</div>

<!--
Transição. Tempo: ~15 s.
-->

---

# Pergunta pra sala

<div style="margin-top:2em; font-size:1.3em">

Como você testa um programa que depende de rede, servidor e outros 19 jogadores...

**sem rede, sem servidor e sem os outros 19?**

</div>

<!--
Espere. A resposta aparece no próximo slide. Tempo: ~30 s - essa pergunta é quase retórica, serve de gancho.
-->

---

# Função pura: a receita de bolo

<v-clicks>

- uma **função pura** é como receita de bolo: mesmos ingredientes, mesmo bolo. sempre.
- ela não olha relógio, não abre rede, não sorteia número escondido: só usa o que entra por parâmetro
- mesma entrada, mesma saída - então dá pra testar **sem ligar nada**: entra uma linha de texto, sai um dado

</v-clicks>

<v-click>

<div style="margin-top:1.5em">

a parte que fala com a rede (a **casca**) fica separada da parte que pensa (o **núcleo puro**). vocês só escrevem o núcleo.

</div>

</v-click>

<!--
Esse é o conceito central do minicurso, o mesmo da palestra. Ir devagar. O teste prático: se dá pra chamar a função num arquivo de teste e comparar o resultado com o esperado, sem subir servidor, ela é pura. Tempo: ~3 min.
-->

---

# A arquitetura do cliente

<div class="diag">
<svg viewBox="0 0 1000 160" role="img" aria-label="Pipeline do cliente: socket, parse, decide, encode, send">
  <defs>
    <marker id="m1-arr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#9393A8"/>
    </marker>
  </defs>

  <text class="dg-lane" x="24" y="22">casca - efeitos - já vem no kit</text>
  <text class="dg-lane" x="224" y="22">núcleo puro - vocês escrevem</text>

  <rect class="dg-node dg-cyan" x="24" y="60" width="150" height="60" rx="12"/>
  <text class="dg-title" x="99" y="85">transport.js</text>
  <text class="dg-sub" x="99" y="101">WebSocket</text>

  <line class="dg-edge" x1="174" y1="90" x2="220" y2="90" marker-end="url(#m1-arr)"/>
  <text class="dg-edge-label" x="197" y="78">linha OBS</text>

  <rect class="dg-node dg-green" x="224" y="60" width="150" height="60" rx="12"/>
  <text class="dg-title" x="299" y="85">parse.js</text>
  <text class="dg-sub" x="299" y="101">E1 - linha -> obs</text>

  <line class="dg-edge" x1="374" y1="90" x2="420" y2="90" marker-end="url(#m1-arr)"/>
  <text class="dg-edge-label" x="397" y="78">observação</text>

  <rect class="dg-node dg-green" x="424" y="60" width="150" height="60" rx="12"/>
  <text class="dg-title" x="499" y="85">decide.js</text>
  <text class="dg-sub" x="499" y="101">E3 - obs -> ação</text>

  <line class="dg-edge" x1="574" y1="90" x2="620" y2="90" marker-end="url(#m1-arr)"/>
  <text class="dg-edge-label" x="597" y="78">ação</text>

  <rect class="dg-node dg-green" x="624" y="60" width="150" height="60" rx="12"/>
  <text class="dg-title" x="699" y="85">encode.js</text>
  <text class="dg-sub" x="699" y="101">E2 - ação -> linha</text>

  <line class="dg-edge" x1="774" y1="90" x2="820" y2="90" marker-end="url(#m1-arr)"/>
  <text class="dg-edge-label" x="797" y="78">linha ACT</text>

  <rect class="dg-node dg-cyan" x="824" y="60" width="150" height="60" rx="12"/>
  <text class="dg-title" x="899" y="85">app.js</text>
  <text class="dg-sub" x="899" y="101">o único send</text>
</svg>
</div>

<div class="muted" style="margin-top:0.8em">

<span class="green">verde</span> = núcleo puro (vocês escrevem) / <span class="cyan">azul</span> = casca (já vem pronta)

</div>

<!--
O slide central. Andar pelo fluxo como se fosse uma esteira: a linha de texto chega pela rede -> vira observação (E1) -> vira decisão (E3) -> vira ação -> vira linha de texto de novo (E2) -> e só então é enviada. Apontar: os exercícios E1 a E3 são exatamente as caixas verdes. O reenvio de mensagem perdida (aquele conceito da Parte 2) já vem pronto na casca do kit - não é exercício. Tempo: ~4 min.
-->

---
layout: statement
---

# No pipeline inteiro, só uma chamada fala com a rede.

<div class="muted" style="margin-top:1em">

encontrem ela quando investigarem o kit. todo o resto é função pura: mesma entrada, mesma saída, testável sem internet.

</div>

<!--
Essa é a pergunta-guia da investigação (bloco das 0:25-1:00). Anotar no quadro: "ache a única linha de código que fala com a rede". Tempo: ~1 min.
-->

---

# O mapa do kit oficial (JavaScript)

```text {all|2-4|6-8|10-13|all}
student-kit/
├── index.html            # abre no navegador, sem instalar nada
├── src/
│   ├── protocol/         # E1 parse.js - E2 encode.js
│   ├── strategy/         # E3 decide.js - a sua estratégia
│   ├── world/            # ajudantes prontos: expandable, attackable, borderCells
│   └── infra/            # a casca: transporte, app, desenho, simulador local
├── test/                 # página de testes (começa toda vermelha)
└── docs/                 # PROTOCOL.md + cheatsheet
```

<div class="muted" style="margin-top:1em">

baixar em `/kit`, descompactar, `python3 -m http.server` na pasta, abrir a página no navegador, clicar em "testes". sem Node, sem build, sem internet.

</div>

<!--
Distribuir o kit: http://<ip>:4000/kit (o endereço exato vai no quadro). Enfatizar a divisão de trabalho: protocol/ e strategy/ são de vocês; world/ e infra/ já vêm prontos e testados - inclusive o reenvio de mensagem perdida, que mora na casca. E o kit traz um simulador local - um servidor de mentira que roda dentro da página, com dois bots. Dá pra desenvolver o dia inteiro sem encostar na rede. Tempo: ~3 min.
-->

---

# Por que o kit oficial é em JavaScript?

<v-clicks>

- todo computador do laboratório **já tem navegador**: nada pra instalar
- o kit JS é o único com **visualizador**: você vê a grade, as colônias e o placar na tela
- e é o único com **simulador local**: um servidor de mentira dentro da página, com dois bots pra treinar
- os testes rodam numa página: vermelho vira verde, sem terminal

</v-clicks>

<v-click>

<div style="margin-top:1.5em" class="muted">

a linguagem é só a ferramenta - os conceitos (protocolo, parser, função pura) são os mesmos em qualquer uma.

</div>

</v-click>

<!--
Deixar claro: ninguém precisa saber JS de cor. Os exercícios são pequenos, os comentários no código guiam cada passo, e trabalhar em dupla ajuda. Tempo: ~2 min.
-->

---

# Quer se aventurar em outra linguagem?

<v-clicks>

- cada linguagem tem seu próprio zip: `/kit/elixir`, `/kit/golang`, `/kit/python`, `/kit/c`
- todos falam **o mesmo protocolo** e jogam no **mesmo servidor** - muda a linguagem, não o jogo
- estrutura parecida em todos: um arquivo pro protocolo, um pra estratégia, um pros ajudantes, um pra casca

</v-clicks>

<v-click>

<div style="margin-top:1.5em">

regra da casa: sem visualizador, sem simulador, **sem suporte do instrutor**. escolham pela linguagem que vocês dominam - em dúvida, fiquem no JS (`/kit`).

</div>

</v-click>

<!--
Estrutura de cada um, pra quem perguntar: todos espelham o mesmo pipeline. Elixir: projeto mix, lib/slimes_client/ com protocol.ex, decide.ex, observation.ex, pending.ex + client.ex (a casca) e testes ExUnit (mix test). Go: arquivos soltos protocol.go, decide.go, observation.go, pending.go + main.go. Python: protocol.py, decide.py, observation.py, pending.py + main.py, testes com unittest. C: src/ com protocol.c, decide.c, observation.c, transport.c + main.c - esse é só pra quem realmente sabe o que está fazendo. O suporte do dia inteiro é no kit JS: os outros são por conta e risco. Tempo: ~2 min.
-->

---

# Testes: do vermelho ao verde

<v-clicks>

- a página de testes começa **toda vermelha** - não é bug: é o mapa do que falta construir
- cada exercício que fica verde destrava a próxima fase
- o **simulador local** tem exatamente a mesma lógica do servidor real - o que passa nele passa no torneio

</v-clicks>

<v-click>

<div style="margin-top:1.5em">

meta do próximo bloco: E1 e E2 verdes, e a sua colônia aparecendo no placar do simulador.

</div>

</v-click>

<!--
O loop de trabalho: rodar os testes, ler o que falhou, consertar, rodar de novo. Se perguntarem como o simulador e o servidor concordam: mesmo log de partida rodado nos dois dá o mesmo placar (são as "fixtures douradas" do repositório). Tempo: ~2 min.
-->

---
layout: section
---

# PARTE 4

## Mão na massa

<div class="muted" style="margin-top:1em">E1 a E3, um conceito por vez</div>

<!--
Transição. Tempo: ~15 s.
-->

---

# E1 - o tradutor da entrada

<div class="muted">parse.js: a linha de texto vira um dado organizado</div>

```js {all|3-5|7-8|all}
// src/protocol/parse.js
parseObservation("OBS srv-97 97 alive 97 9,5,plain,0,0;...")
// => { tag: "ok",
//      value: { ref, tick: 97, status: "alive", scoresTick, cells } }

parseObservation("OBS srv-97 alive")  // linha quebrada
// => { tag: "error", reason: "..." }   // nunca exceção
```

<v-clicks>

- a função **devolve** um resultado com etiqueta: `ok` com o valor, ou `error` com o motivo - quem chamou decide o que fazer
- `parseCell` e `cellList` já existem no kit: o trabalho é montar a linha inteira
- campos extras no final da linha: **ignore** - é o leitor tolerante do slide anterior

</v-clicks>

<!--
Bloco das 1:00-1:35, junto com o E2. Lembrem a sala: depois dessa função, nenhum outro pedaço do programa vê texto cru. Tempo do slide: ~2 min. O exercício em si: ~20 min.
-->

---

# E2 - o tradutor da saída

<div class="muted">encode.js: o espelho do E1 - a ação vira linha de texto</div>

```js {all|3|5|7|all}
// src/protocol/encode.js
encodeAction({ kind: "expand", x: 12, y: 7 }, ref)
// => "ACT aurora-k3f9-17 expand 12 7"

encodeAction({ kind: "pass" }, ref)
// => "ACT aurora-k3f9-18 pass"        // sem coordenadas
```

<v-clicks>

- o ref vem pronto de `createRefs(nome)`: `<nome>-<sessão>-<número>`, número crescente
- lembra da etiqueta? é **essa** função que coloca ela na mensagem - e é ela que permite reenviar sem medo

</v-clicks>

<!--
E1 e E2 são espelhos: um traduz a entrada, o outro a saída, os dois na fronteira, os dois puros. Com os dois verdes, a colônia já entra no placar do simulador - só passando a vez, porque o cérebro (E3) ainda é um rascunho. Tempo do slide: ~2 min.
-->

---

# E3 - o cérebro

<div class="muted">decide.js: a única função que é 100% sua - olha a vizinhança, escolhe a ação</div>

<v-clicks>

- pura como as outras: mesma observação, mesma ação - sem rede, sem relógio, sem sorte escondida
- ajudantes prontos em `world/observation.js`: `expandable`, `attackable`, `borderCells`
- **começo simples**: expanda pra uma casa vazia vizinha; nunca ataque casa fortificada
- **próximo nível**: fortifique fronteira com inimigo ao lado; ataque inimigo sem fortificação
- os testes só verificam o **tipo** da ação, não a casa exata: a estratégia é livre

</v-clicks>

<v-click>

<div style="margin-top:1.5em">

meta: E3 verde + uma partida completa contra os bots do simulador.

</div>

</v-click>

<!--
Bloco das 1:45-2:30. Aqui cada um diverge de verdade: não existe resposta certa. Quem for rápido pega as tarefas extras do kit (heurísticas melhores, previsão de placar). Tempo do slide: ~2 min 30 s.
-->

---

# Quando as regras mudam: a v2

<v-clicks>

- às 2:50 o servidor reinicia na **v2**: cada casa ganha um campo a mais (recurso)
- protocolo novo não renomeia nem reordena campo: evolução é **adicionar no final**
- parser que exige exatamente 5 campos **quebra**; parser tolerante sobrevive
- todo mundo quebra do mesmo jeito, todo mundo conserta junto, em 10 minutos

</v-clicks>

<v-click>

<div style="margin-top:1.5em">

é pra isso que existe o `v1` no `HELLO` - e o leitor tolerante do E1.

</div>

</v-click>

<!--
NÃO mostrar esse slide antes das 2:50 - ele é o roteiro do conserto coletivo, não um spoiler. A lição: quem publica um protocolo não controla quando os clientes atualizam, então o formato só cresce pra trás. Tempo: ~2 min, durante o drill.
-->

---
layout: section
---

# PARTE 5

## O torneio

<div class="muted" style="margin-top:1em">e o que acontece do outro lado, no servidor</div>

<!--
Transição. Tempo: ~15 s.
-->

---

# Duas fases, um restart

<v-clicks>

- **cooperativa** (2:30): servidor com ataques desligados; `attack` recebe `NACK attacks_disabled`
- cada colônia cresce no seu canto - agora contra o servidor **de verdade**, na rede **de verdade**
- **torneio** (3:00): o servidor reinicia sem a trava - restart é partida nova, de propósito
- rodadas curtas; quem perde assiste pelo projetor

</v-clicks>

<v-click>

<div style="margin-top:1.5em" class="muted">

se a conexão cair: reconectar com o mesmo nome de colônia viva retoma o estado. colônia morta é entrada nova.

</div>

</v-click>

<!--
A fase cooperativa não é aquecimento vazio: é o primeiro contato com latência de verdade, ACK perdido de verdade, reconexão de verdade - tudo que o simulador fingia. Tempo: ~2 min.
-->

---

# A demo final

<div class="diag">
<svg viewBox="0 0 920 190" role="img" aria-label="Servidor: clientes enviam ações, resolve é função pura, efeitos na borda, log permite replay">
  <defs>
    <marker id="m2-arr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#9393A8"/>
    </marker>
  </defs>

  <rect class="dg-node dg-cyan" x="24" y="50" width="150" height="56" rx="12"/>
  <text class="dg-title" x="99" y="72">N clientes</text>
  <text class="dg-sub" x="99" y="88">um ACT por tick</text>

  <line class="dg-edge" x1="174" y1="78" x2="220" y2="78" marker-end="url(#m2-arr)"/>
  <text class="dg-edge-label" x="197" y="66">ações</text>

  <rect class="dg-node dg-green" x="224" y="50" width="170" height="56" rx="12"/>
  <text class="dg-title" x="309" y="72">resolve/2</text>
  <text class="dg-sub" x="309" y="88">função pura</text>

  <line class="dg-edge" x1="394" y1="78" x2="440" y2="78" marker-end="url(#m2-arr)"/>
  <text class="dg-edge-label" x="417" y="66">novo estado</text>

  <rect class="dg-node dg-purple" x="444" y="50" width="160" height="56" rx="12"/>
  <text class="dg-title" x="524" y="72">World</text>
  <text class="dg-sub" x="524" y="88">GenServer - a casca</text>

  <line class="dg-edge" x1="604" y1="78" x2="650" y2="78" marker-end="url(#m2-arr)"/>

  <rect class="dg-node dg-cyan" x="654" y="50" width="170" height="56" rx="12"/>
  <text class="dg-title" x="739" y="72">sockets</text>
  <text class="dg-sub" x="739" y="88">OBS - SCORE - DIFF</text>

  <rect class="dg-node dg-optional" x="444" y="134" width="160" height="44" rx="12"/>
  <text class="dg-title" x="524" y="152">log.jsonl</text>
  <text class="dg-sub" x="524" y="166">mix replay = mesmo placar</text>

  <line class="dg-edge dg-optional" x1="524" y1="106" x2="524" y2="130" marker-end="url(#m2-arr)"/>
</svg>
</div>

<v-clicks>

- o servidor usa **exatamente** a arquitetura que vocês acabaram de escrever: núcleo puro no meio, rede na borda
- a trava de etiqueta repetida cabe em ~5 linhas de Elixir - mostrada ao vivo
- o servidor grava cada evento num log: reexecutar o log dá o mesmo placar - o estado é só a soma dos eventos
- e sim: vou derrubar o servidor no meio de uma partida. observem os `NACK too_late` chegando

</v-clicks>

<!--
3:20-3:30, no projetor. A graça é a sala reconhecer no servidor o mesmo desenho que acabou de fazer no cliente. A queda do servidor fecha o arco: tudo que praticaram hoje acontece de verdade, ao vivo. Tempo: ~10 min, com perguntas.
-->

---
layout: statement
---

# O que fica

<div style="margin-top:1.5em; font-size:1.05em">

O jogo era a desculpa. O que vocês praticaram vale pra qualquer sistema:

um **contrato** na fronteira, um **núcleo puro** no meio, os **efeitos** na borda.

E isso funciona em qualquer linguagem.

</div>

<!--
O takeaway, devagar. Amanhã, quando escreverem um cliente HTTP, um webhook, uma integração de pagamento, vão usar exatamente o que fizeram hoje: traduzir sem exceção, etiquetar mensagens, tentar de novo com limite, tratar erro como dado. Tempo: ~2 min.
-->

---
layout: end
---

# Obrigada

<div style="display:flex; align-items:center; justify-content:center; gap:3em; margin-top:2em">

<div style="font-size:1.2em; text-align:left">

em todo lugar: <strong class="cyan">@zoedsoupe</strong>

<div class="muted" style="font-size:0.8em; margin-top:0.5em">zoedsoupe.zeetech.io - slides + referências</div>

</div>

<img src="/qr-zoey.svg" style="width:8.5em; border-radius:6px" />

</div>

<div style="margin-top:1.5em; font-size:1.5em">

**Bom torneio.**

</div>

<!--
Antes de abrir pra perguntas: o repositório é público, com clientes de referência em Elixir, Python e Go pra quem quiser refazer o protocolo em outra linguagem (não suportados, por conta e risco). Ponteiros pra ir além: "Parse, don't validate" (Alexis King), "Boundaries" (Gary Bernhardt), e o PROTOCOL.md como exemplo de contrato de uma página. Se sobrar tempo, perguntas.
-->
