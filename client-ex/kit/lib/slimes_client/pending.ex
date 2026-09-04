defmodule SlimesClient.Pending do
  @moduledoc """
  Política de retry pura sobre o mapa de pendentes.

  Toda ação enviada ao servidor fica pendente até o ACK (ou NACK) chegar.
  Este módulo guarda esse mapa e decide o que fazer com cada pendência:
  confirmar, reenviar ou desistir. Nada aqui toca no socket: as funções
  devolvem dados e a borda (`SlimesClient.Client`) executa os efeitos.

  Formato do mapa: `%{ref => %{line: line, tick: tick, retries: retries}}`,
  onde `line` é a linha já codificada pronta para reenvio, `tick` é o tick
  do último envio (ou reenvio) e `retries` conta quantos reenvios já houve.
  """

  @budget 3
  @timeout 2

  @doc """
  Registra uma ação recém enviada como pendente.

  Parâmetros:

    * `pending`: o mapa de pendentes atual
    * `ref`: o ref da ação (vem de `SlimesClient.Protocol.next_ref/1`)
    * `line`: a linha codificada que foi para o socket
    * `tick`: o tick atual (vem da observação)

  Devolve um novo mapa com o ref registrado e `retries` zerado.

      pending = Pending.add_pending(%{}, "ana-x1y2-1", "ACT ana-x1y2-1 expand 3 4", 10)
      pending["ana-x1y2-1"]
      # => %{line: "ACT ana-x1y2-1 expand 3 4", tick: 10, retries: 0}
  """
  def add_pending(pending, ref, line, tick),
    do: Map.put(pending, ref, %{line: line, tick: tick, retries: 0})

  @doc """
  Confirma um pendente: o ACK (ou NACK) daquele ref chegou.

  Devolve um novo mapa sem o ref. Se o ref não existir, o mapa volta igual.

      pending = Pending.add_pending(%{}, "ana-x1y2-1", "ACT ana-x1y2-1 pass", 10)
      Pending.on_ack(pending, "ana-x1y2-1")
      # => %{}
  """
  def on_ack(pending, ref), do: Map.delete(pending, ref)

  @doc """
  Vence os pendentes antigos e devolve `{novo_mapa, efeitos}`.

  Para cada ref com `now - tick >= timeout`:

    * se `retries < budget`: reenvia. O efeito é `%{retry: ref, line: line}`
      e o ref fica no mapa com `retries + 1` e `tick` atualizado para `now`
    * se o budget acabou: desiste. O efeito é `%{drop: ref}` e o ref sai
      do mapa

  Refs recentes ficam intactos e não geram efeito. A ordem dos efeitos não
  é garantida (mapas não têm ordem). A borda reenvia as linhas dos efeitos
  `%{retry: ...}` e loga os `%{drop: ...}`.

  `budget` e `timeout` têm defaults (3 reenvios, 2 ticks) e quase nunca
  precisam ser passados.

      pending = Pending.add_pending(%{}, "ana-x1y2-1", "ACT ana-x1y2-1 pass", 10)
      {next, effects} = Pending.on_timeout(pending, 12)
      effects
      # => [%{retry: "ana-x1y2-1", line: "ACT ana-x1y2-1 pass"}]
      next["ana-x1y2-1"].retries
      # => 1
  """
  def on_timeout(pending, now, budget \\ @budget, timeout \\ @timeout) do
    Enum.reduce(pending, {%{}, []}, fn {ref, entry}, {next, effects} ->
      cond do
        now - entry.tick < timeout ->
          {Map.put(next, ref, entry), effects}

        entry.retries < budget ->
          retried = %{entry | tick: now, retries: entry.retries + 1}
          {Map.put(next, ref, retried), [%{retry: ref, line: entry.line} | effects]}

        true ->
          {next, [%{drop: ref} | effects]}
      end
    end)
  end
end
