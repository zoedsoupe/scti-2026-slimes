defmodule SlimesClient.Pending do
  @moduledoc """
  Política de retry pura sobre o mapa de pendentes.

  pending: `%{ref => %{line, tick, retries}}`. Nada aqui toca no socket:
  `on_timeout/2` devolve o que fazer (retry ou drop) e a borda executa.
  """

  @budget 3
  @timeout 2

  def add_pending(pending, ref, line, tick),
    do: Map.put(pending, ref, %{line: line, tick: tick, retries: 0})

  def on_ack(pending, ref), do: Map.delete(pending, ref)

  @doc "refs vencidos: retry enquanto couber no orçamento, drop no limite"
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
