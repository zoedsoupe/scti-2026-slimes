defmodule Slimes.World.Resolve do
  @moduledoc """
  Resolução pura de um tick do mundo.

  Recebe o estado, as ações já validadas (no máximo uma por colônia) e um
  gerador de números aleatórios já semeado com `{base_seed, tick, 0}`.
  Devolve o novo estado e a lista de eventos. Sem efeitos colaterais:
  mesmos argumentos, mesmo resultado.

      resolve(state, actions, rng) :: {new_state, events}

  Ordem da resolução:

    1. embaralha as colônias com o rng (ordem de resolução do tick)
    2. fase 1, defesa: aplica todos os `fortify`
    3. fase 2, expansão: aplica `expand` e `attack` na ordem embaralhada
    4. regra dos órfãos: células fora do maior componente da colônia morrem
    5. colônias sem nenhuma célula são eliminadas

  Eventos: `{:cell, x, y, owner, fortified}` para cada mudança de célula e
  `{:eliminated, colony_id}` para cada eliminação.
  """

  @empty %{terrain: :plain, owner: 0, fortified: 0}

  @spec resolve(map, [map], :rand.state()) :: {map, [tuple]}
  def resolve(state, actions, rng) do
    {order, rng} = shuffle(Map.keys(state.colonies), rng)
    by_colony = Map.new(actions, &{&1.colony, &1})

    {state, fortify_events} =
      Enum.reduce(order, {state, []}, fn id, {st, evs} ->
        case by_colony[id] do
          %{kind: :fortify, cell: cell} -> fortify(st, id, cell, evs)
          _ -> {st, evs}
        end
      end)

    {state, expansion_events, _rng} =
      Enum.reduce(order, {state, [], rng}, fn id, {st, evs, rng} ->
        case by_colony[id] do
          %{kind: :expand, cell: cell} -> expand(st, id, cell, evs, rng)
          %{kind: :attack, cell: cell} -> attack(st, id, cell, evs, rng)
          _ -> {st, evs, rng}
        end
      end)

    {state, orphan_events} = apply_orphan_rule(state)

    {state, elimination_events} = eliminate_empty_colonies(state)

    events = fortify_events ++ expansion_events ++ orphan_events ++ elimination_events
    {state, events}
  end

  ## Fase 1: defesa

  defp fortify(state, id, {x, y}, events) do
    cell = cell_at(state, x, y)

    if cell.owner == id and cell.fortified == 0 do
      state = put_cell(state, x, y, %{cell | fortified: 1})
      {state, events ++ [{:cell, x, y, id, 1}]}
    else
      {state, events}
    end
  end

  ## Fase 2: expansão

  defp expand(state, id, {x, y}, events, rng) do
    if cell_at(state, x, y).owner == 0 do
      state = put_cell(state, x, y, %{cell_at(state, x, y) | owner: id, fortified: 0})
      {state, events ++ [{:cell, x, y, id, 0}], rng}
    else
      # perdedor do conflito: ação desperdiçada, não reenfileirada
      {state, events, rng}
    end
  end

  defp attack(state, id, {x, y}, events, rng) do
    cell = cell_at(state, x, y)

    cond do
      cell.owner == id ->
        {state, events, rng}

      cell.fortified == 1 ->
        # célula fortificada: 50/50 pelo rng do tick
        {won, rng} = coin_flip(rng)

        if won do
          {take(state, id, x, y, cell), events ++ [{:cell, x, y, id, 0}], rng}
        else
          {state, events, rng}
        end

      true ->
        {take(state, id, x, y, cell), events ++ [{:cell, x, y, id, 0}], rng}
    end
  end

  defp take(state, id, x, y, cell) do
    put_cell(state, x, y, %{cell | owner: id, fortified: 0})
  end

  ## Regra dos órfãos

  defp apply_orphan_rule(state) do
    Enum.reduce(state.colonies, {state, []}, fn {id, colony}, {st, evs} ->
      if colony.status == :alive do
        orphans = orphaned_cells(st, id, colony)

        Enum.reduce(orphans, {st, evs}, fn {x, y}, {st, evs} ->
          cell = cell_at(st, x, y)
          st = put_cell(st, x, y, %{cell | owner: 0, fortified: 0})
          {st, evs ++ [{:cell, x, y, 0, 0}]}
        end)
      else
        {st, evs}
      end
    end)
  end

  # células da colônia que ficaram fora do componente sobrevivente
  defp orphaned_cells(state, id, colony) do
    owned = for {{x, y}, %{owner: ^id}} <- state.cells, do: {x, y}

    case components(owned) do
      [] -> []
      [_single] -> []
      comps ->
        survivor = surviving_component(comps, colony.oldest)
        comps |> List.delete(survivor) |> List.flatten()
    end
  end

  # o maior componente sobrevive; no empate, o que contém a célula mais antiga
  defp surviving_component(comps, oldest) do
    max_size = comps |> Enum.map(&length/1) |> Enum.max()
    largest = Enum.filter(comps, &(length(&1) == max_size))

    Enum.find(largest, fn comp -> oldest in comp end) || hd(largest)
  end

  defp components(cells) do
    cells
    |> Enum.reduce({MapSet.new(cells), []}, fn cell, {remaining, comps} ->
      if MapSet.member?(remaining, cell) do
        comp = flood(MapSet.new([cell]), [cell], remaining)
        remaining = MapSet.difference(remaining, comp)
        {remaining, [MapSet.to_list(comp) | comps]}
      else
        {remaining, comps}
      end
    end)
    |> elem(1)
    |> Enum.reverse()
  end

  defp flood(comp, [cell | rest], remaining) do
    newly =
      cell
      |> neighbors()
      |> Enum.filter(&MapSet.member?(remaining, &1))
      |> Enum.reject(&MapSet.member?(comp, &1))

    comp = Enum.reduce(newly, comp, &MapSet.put(&2, &1))
    flood(comp, newly ++ rest, remaining)
  end

  defp flood(comp, [], _remaining), do: comp

  # adjacência ortogonal
  defp neighbors({x, y}), do: [{x + 1, y}, {x - 1, y}, {x, y + 1}, {x, y - 1}]

  ## Eliminação

  defp eliminate_empty_colonies(state) do
    Enum.reduce(state.colonies, {state, []}, fn {id, colony}, {st, evs} ->
      alive = colony.status == :alive
      owns_any? = Enum.any?(st.cells, fn {_pos, cell} -> cell.owner == id end)

      if alive and not owns_any? do
        st = put_in(st.colonies[id].status, :dead)
        {st, evs ++ [{:eliminated, id}]}
      else
        {st, evs}
      end
    end)
  end

  ## RNG sempre passado adiante, nunca o dicionário de processo

  @doc """
  Ordem de resolução de um tick, sem rodar a resolução.

  Mesma seed e mesmo shuffle de `resolve/3`, para o `World` gravar no log
  as ações na ordem em que foram (ou seriam) resolvidas.
  """
  @spec seeded_order([term], non_neg_integer, non_neg_integer) :: [term]
  def seeded_order(colony_ids, base_seed, tick) do
    rng = :rand.seed(:exsss, {base_seed, tick, 0})
    {order, _rng} = shuffle(colony_ids, rng)
    order
  end

  defp shuffle(list, rng) when length(list) < 2, do: {list, rng}

  defp shuffle(list, rng) do
    arr = List.to_tuple(list)
    last = tuple_size(arr) - 1

    {arr, rng} =
      Enum.reduce(last..1//-1, {arr, rng}, fn i, {arr, rng} ->
        {j, rng} = :rand.uniform_s(i + 1, rng)
        {swap(arr, i, j - 1), rng}
      end)

    {Tuple.to_list(arr), rng}
  end

  defp swap(arr, i, j) do
    a = elem(arr, i)
    arr = put_elem(arr, i, elem(arr, j))
    put_elem(arr, j, a)
  end

  defp coin_flip(rng) do
    {n, rng} = :rand.uniform_s(2, rng)
    {n == 1, rng}
  end

  ## Células: mapa esparso, o padrão é planície vazia

  defp cell_at(state, x, y), do: Map.get(state.cells, {x, y}, @empty)

  defp put_cell(state, x, y, cell), do: put_in(state.cells[{x, y}], cell)
end
