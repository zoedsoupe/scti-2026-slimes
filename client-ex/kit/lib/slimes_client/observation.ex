defmodule SlimesClient.Observation do
  @moduledoc """
  Helpers puros sobre uma observação (a visão que chega a cada tick).
  Nada aqui conhece socket ou rede.
  """

  @doc "mapa {x, y} -> célula, para consulta O(1)"
  def cell_map(cells), do: Map.new(cells, &{{&1.x, &1.y}, &1})

  @doc "adjacência ortogonal (a regra de bad_cell do servidor usa a mesma)"
  def neighbors4(x, y), do: [{x + 1, y}, {x - 1, y}, {x, y + 1}, {x, y - 1}]

  def own_cells(cells, my_id), do: Enum.filter(cells, &(&1.owner == my_id))

  @doc "células vazias adjacentes a alguma célula da colônia: alvos de expand"
  def expandable(cells, my_id), do: adjacent(cells, my_id, &(&1.owner == 0))

  @doc "células inimigas adjacentes à colônia: alvos de attack"
  def attackable(cells, my_id),
    do: adjacent(cells, my_id, &(&1.owner != 0 and &1.owner != my_id))

  defp adjacent(cells, my_id, target?) do
    map = cell_map(cells)

    cells
    |> own_cells(my_id)
    |> Enum.flat_map(fn c -> neighbors4(c.x, c.y) end)
    |> Enum.uniq()
    |> Enum.map(&map[&1])
    |> Enum.filter(&(&1 && target?.(&1)))
  end

  @doc "células próprias com vizinho inimigo: fronteira, candidatas a fortify"
  def border_cells(cells, my_id) do
    map = cell_map(cells)

    Enum.filter(own_cells(cells, my_id), fn c ->
      Enum.any?(neighbors4(c.x, c.y), fn pos ->
        case map[pos] do
          nil -> false
          n -> n.owner != 0 and n.owner != my_id
        end
      end)
    end)
  end
end
