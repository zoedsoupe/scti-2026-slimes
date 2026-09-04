defmodule SlimesClient.Observation do
  @moduledoc """
  Helpers puros sobre uma observação (a visão que chega a cada tick).

  Uma observação é o mapa que `SlimesClient.Protocol.parse_observation/1`
  (E1) devolve, e a parte que interessa aqui é a lista `cells`: cada célula
  é `%{x, y, terrain, owner, fortified}`. Estas funções respondem às
  perguntas que a sua estratégia (E3) faz: quais células são minhas, para
  onde dá para expandir, quem dá para atacar, onde fortificar.

  Nada aqui conhece socket ou rede.
  """

  @doc """
  Indexa as células por posição: devolve o mapa `{{x, y} => célula}`.

  Use para consulta O(1) por coordenada em vez de varrer a lista.

      map = Observation.cell_map(cells)
      map[{9, 5}]
      # => %{x: 9, y: 5, terrain: "plain", owner: 0, fortified: 0}
  """
  def cell_map(cells), do: Map.new(cells, &{{&1.x, &1.y}, &1})

  @doc """
  Lista as 4 posições ortogonais de `(x, y)`: cima, baixo, esquerda,
  direita (sem diagonais).

  É a mesma adjacência que a regra de `bad_cell` do servidor usa.

      Observation.neighbors4(3, 4)
      # => [{4, 4}, {2, 4}, {3, 5}, {3, 3}]
  """
  def neighbors4(x, y), do: [{x + 1, y}, {x - 1, y}, {x, y + 1}, {x, y - 1}]

  @doc """
  Filtra as células que pertencem à colônia `my_id` (o id veio no WELCOME).

      Observation.own_cells(cells, 3)
      # => [%{x: 10, y: 5, terrain: "plain", owner: 3, fortified: 1}, ...]
  """
  def own_cells(cells, my_id), do: Enum.filter(cells, &(&1.owner == my_id))

  @doc """
  Lista as células vazias (`owner == 0`) adjacentes a alguma célula sua:
  os alvos válidos de `expand`.

  Devolve as células (não só as posições), sem repetição, em ordem
  arbitrária. Lista vazia significa que não há para onde expandir.

      Observation.expandable(cells, 3)
      # => [%{x: 9, y: 5, terrain: "plain", owner: 0, fortified: 0}, ...]
  """
  def expandable(cells, my_id), do: adjacent(cells, my_id, &(&1.owner == 0))

  @doc """
  Lista as células inimigas adjacentes à sua colônia: os alvos válidos de
  `attack`.

  Inimigo é qualquer `owner` diferente de 0 e diferente de `my_id`.
  Células fortificadas aparecem na lista (cabe à estratégia filtrar por
  `fortified == 0` se não quiser atacar fortaleza).

      Observation.attackable(cells, 3)
      # => [%{x: 12, y: 8, terrain: "plain", owner: 5, fortified: 0}, ...]
  """
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

  @doc """
  Lista as suas células que têm pelo menos um vizinho inimigo: a fronteira,
  candidatas a `fortify`.

  Vizinho fora do mapa (a célula não aparece na observação) não conta como
  inimigo.

      Observation.border_cells(cells, 3)
      # => [%{x: 10, y: 5, terrain: "plain", owner: 3, fortified: 0}, ...]
  """
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
