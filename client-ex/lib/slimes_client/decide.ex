defmodule SlimesClient.Decide do
  @moduledoc """
  Estratégia de referência. observação -> ação, pura.

  Prioridade: ataca inimigo desfortificado adjacente; fortifica fronteira
  sob ameaça; expande na direção do inimigo mais próximo; senão passa.

  É O ÚNICO MÓDULO QUE VOCÊ PRECISA EDITAR para jogar.
  """

  import SlimesClient.Observation

  def decide(obs, my_id) do
    enemies = attackable(obs.cells, my_id)
    weak = Enum.filter(enemies, &(&1.fortified == 0))
    border = Enum.filter(border_cells(obs.cells, my_id), &(&1.fortified == 0))
    targets = Enum.sort_by(expandable(obs.cells, my_id), &dist(&1, List.first(enemies)))

    cond do
      weak != [] ->
        %{kind: "attack", x: hd(weak).x, y: hd(weak).y}

      border != [] and enemies != [] ->
        %{kind: "fortify", x: hd(border).x, y: hd(border).y}

      targets != [] ->
        %{kind: "expand", x: hd(targets).x, y: hd(targets).y}

      true ->
        %{kind: "pass"}
    end
  end

  defp dist(_a, nil), do: 0
  defp dist(a, b), do: abs(a.x - b.x) + abs(a.y - b.y)
end
