defmodule Slimes.GoldenTest do
  use ExUnit.Case

  # Emite priv/golden/*.jsonl sob demanda: `mix test --include golden`.
  # Cada cenário roda uma partida curta num World real e exporta o log no
  # formato de docs/GOLDEN.md. O simulador JS reexecuta esses arquivos nos
  # testes de paridade.

  @moduletag :golden

  alias Slimes.Message.Act
  alias Slimes.World

  @dir Path.expand("../../priv/golden", __DIR__)

  test "expand and fortify" do
    run_scenario(
      "expand_and_fortify",
      [base_seed: 42, width: 10, height: 10, spawns: %{"aurora" => {4, 4}, "nova" => {8, 8}}],
      ["aurora", "nova"],
      [
        [{"aurora", :expand, {4, 3}}, {"nova", :expand, {8, 7}}],
        [{"aurora", :fortify, {4, 4}}],
        []
      ]
    )
  end

  test "attack and elimination" do
    run_scenario(
      "attack_elimination",
      [base_seed: 42, width: 5, height: 1, spawns: %{"aurora" => {0, 0}, "nova" => {2, 0}}],
      ["aurora", "nova"],
      [
        [{"nova", :expand, {1, 0}}],
        [{"nova", :attack, {0, 0}}]
      ]
    )
  end

  test "orphan rule" do
    run_scenario(
      "orphan_rule",
      [base_seed: 42, width: 5, height: 3, spawns: %{"aurora" => {0, 1}, "nova" => {1, 0}}],
      ["aurora", "nova"],
      [
        [{"aurora", :expand, {1, 1}}],
        [{"aurora", :expand, {2, 1}}],
        [{"nova", :attack, {1, 1}}]
      ]
    )
  end

  test "terrain" do
    run_scenario(
      "terrain",
      [
        base_seed: 42,
        width: 10,
        height: 10,
        terrain: [{5, 5, :forest}, {6, 5, :water}],
        spawns: %{"aurora" => {4, 4}, "nova" => {8, 8}}
      ],
      ["aurora", "nova"],
      [
        [{"aurora", :expand, {4, 3}}, {"nova", :expand, {8, 7}}]
      ]
    )
  end

  defp run_scenario(name, world_opts, colonies, script) do
    {:ok, world} = World.start_link(world_opts)
    sink = spawn(fn -> :timer.sleep(:infinity) end)

    ids =
      Map.new(colonies, fn name ->
        {:ok, info} = World.join(world, name, sink)
        {name, info.id}
      end)

    for {tick_actions, index} <- Enum.with_index(script, 1) do
      for {name, kind, {x, y}} <- tick_actions do
        action = %Act{ref: "#{name}-g-#{index}", kind: kind, x: x, y: y}
        assert {:ok, _} = World.act(world, ids[name], action)
      end

      send(world, :tick)
    end

    jsonl = World.export(world)

    File.mkdir_p!(@dir)
    File.write!(Path.join(@dir, "#{name}.jsonl"), jsonl)

    lines = String.split(jsonl, "\n", trim: true)

    assert [%{"kind" => "config"}, %{"kind" => "spawns"} | _] =
             Enum.map(lines, &JSON.decode!/1)

    assert %{"kind" => "final"} = lines |> List.last() |> JSON.decode!()
    assert length(lines) == 3 + length(script)
  end
end
