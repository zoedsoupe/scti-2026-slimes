# Cliente de referência Slimes

**Regra de dependências:** `src/protocol/`, `src/world/` e `src/strategy/` nunca importam nada de `src/infra/` (domínio puro não conhece infraestrutura). Só `src/infra/` toca em DOM, canvas e rede.

Cliente de referência do minicurso: HTML estático e módulos ES, sem build, sem npm, sem dependências. Joga uma partida inteira sozinho usando a estratégia de referência (`src/strategy/decide.js`).

## Como rodar

A partir da raiz do repositório `slimes/`:

```
python3 -m http.server
```

Abra http://localhost:8000/client-js/ no navegador. Módulos ES não carregam via `file://`, por isso o servidor HTTP é necessário.

## Jogar contra o simulador local

Deixe o campo "servidor" em `local`, escolha um nome de colônia (`[a-z0-9-]{1,16}`) e clique em "conectar". O simulador roda no próprio navegador.

## Apontar para o servidor real

No campo "servidor", use `ws://<ip-do-mac>:4000/ws` e clique em "conectar". Se a conexão cair, o cliente tenta de novo após 1 segundo com o mesmo nome; o servidor retoma a colônia se ela ainda estiver viva.

## Testes

Os testes dos módulos puros vivem em `client-js/test/index.html`: abra essa página no navegador e os resultados aparecem nela.
