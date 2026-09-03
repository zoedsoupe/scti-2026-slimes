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

  # TODO E4: o ACK chegou. Devolva um NOVO mapa sem o ref confirmado.
  # Enquanto o stub estiver aqui os pendentes nunca são confirmados.
  def on_ack(pending, _ref), do: pending

  # TODO E4: vence os pendentes antigos. Para cada ref com now - tick >= timeout:
  #   - se retries < budget: reenvia -> efeito %{retry: ref, line: line},
  #     retries + 1, tick atualizado para now
  #   - se retries esgotou o budget: desiste -> efeito %{drop: ref},
  #     o ref some do mapa
  # Refs recentes ficam intactos. Devolva {novo_mapa, efeitos}.
  # Enquanto o stub estiver aqui nenhuma ação é reenviada nem descartada.
  def on_timeout(pending, _now, _budget \\ @budget, _timeout \\ @timeout) do
    {pending, []}
  end
end
