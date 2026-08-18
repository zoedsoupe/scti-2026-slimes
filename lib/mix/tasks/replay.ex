defmodule Mix.Tasks.Replay do
  @moduledoc """
  Reexecuta um log de partida (JSONL no formato de docs/GOLDEN.md) a partir
  do estado inicial e imprime o placar final.

      mix replay caminho/para/log.jsonl

  A resolução usa o mesmo `Slimes.World.Resolve` e as mesmas seeds do
  servidor, então o placar calculado deve reproduzir exatamente o placar
  gravado na linha `final` do log. Divergência encerra com erro.
  """

  use Mix.Task

  alias Slimes.World.Resolve

  @shortdoc "Reexecuta um log de partida e imprime o placar final"

  @impl true
  def run([path]) do
    lines =
      path
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.map(&JSON.decode!/1)

    config = Enum.find(lines, &(&1["kind"] == "config"))
    spawns = Enum.find(lines, &(&1["kind"] == "spawns"))
    ticks = Enum.filter(lines, &(&1["kind"] == "tick"))
    final = Enum.find(lines, &(&1["kind"] == "final"))

    initial = initial_state(config, spawns)

    state =
      Enum.reduce(ticks, initial, fn line, state ->
        actions = Enum.map(line["actions"], &decode_action/1)
        rng = :rand.seed(:exsss, {config["base_seed"], line["tick"], 0})

        {state, _events} =
          Resolve.resolve(%{state | tick: line["tick"]}, actions, rng)

        state
      end)

    computed = scoreboard(state)

    IO.puts("placar final (tick #{state.tick}):")

    for score <- computed do
      status = if score.alive, do: "alive", else: "dead"
      IO.puts("  #{score.id} #{score.name} #{score.cells} celulas #{status}")
    end

    expected =
      Map.new(final["scores"], fn s -> {s["id"], {s["cells"], s["alive"]}} end)

    matches? =
      length(computed) == map_size(expected) and
        Enum.all?(computed, fn score ->
          Map.get(expected, score.id) == {score.cells, score.alive}
        end)

    unless matches? do
      Mix.raise("replay divergiu do placar gravado no log")
    end
  end

  def run(_), do: Mix.raise("uso: mix replay caminho/para/log.jsonl")

  defp initial_state(config, spawns) do
    terrain =
      Map.new(config["terrain"], fn [x, y, t] ->
        {{x, y}, %{terrain: String.to_atom(t), owner: 0, fortified: 0}}
      end)

    Enum.reduce(spawns["colonies"], %{cells: terrain, colonies: %{}}, fn colony, acc ->
      id = colony["id"]
      [sx, sy] = colony["cell"]

      cell = %{Map.get(acc.cells, {sx, sy}, %{terrain: :plain, owner: 0, fortified: 0}) | owner: id}

      %{
        acc
        | cells: Map.put(acc.cells, {sx, sy}, cell),
          colonies:
            Map.put(acc.colonies, id, %{
              id: id,
              name: colony["name"],
              status: :alive,
              oldest: {sx, sy}
            })
      }
    end)
    |> Map.merge(%{
      width: config["grid"]["w"],
      height: config["grid"]["h"],
      tick: 0
    })
  end

  defp decode_action(action) do
    [x, y] = action["cell"]
    %{colony: action["colony"], kind: String.to_atom(action["kind"]), cell: {x, y}}
  end

  defp scoreboard(state) do
    state.colonies
    |> Enum.sort_by(fn {id, _} -> id end)
    |> Enum.map(fn {id, colony} ->
      cells = Enum.count(state.cells, fn {_pos, cell} -> cell.owner == id end)
      %{id: id, name: colony.name, cells: cells, alive: colony.status == :alive}
    end)
  end
end
