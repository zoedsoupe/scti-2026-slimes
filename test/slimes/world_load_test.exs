defmodule Slimes.WorldLoadTest do
  use ExUnit.Case

  # Carga: 20 clientes concorrentes agindo no mesmo tick, broadcasts para
  # todos a cada tick, sem perda de mensagem. Os handlers são processos
  # simples (este próprio processo de teste), como no spec.

  alias Slimes.Message.Act
  alias Slimes.World

  @clients 20
  @ticks 10

  test "20 clients acting at once, 10 ticks, no message loss" do
    {:ok, world} =
      World.start_link(base_seed: 7, width: 20, height: 20, tick_ms: 60_000)

    test_pid = self()

    ids =
      for i <- 1..@clients do
        {:ok, info} = World.join(world, "c#{i}", test_pid)
        info.id
      end

    for tick <- 1..@ticks do
      results =
        Task.async_stream(
          ids,
          fn id -> World.act(world, id, %Act{ref: "c#{id}-t#{tick}", kind: :pass}) end,
          max_concurrency: @clients
        )
        |> Enum.map(fn {:ok, result} -> result end)

      assert Enum.all?(results, &match?({:ok, _}, &1))

      send(world, :tick)

      for _ <- ids, do: assert_receive({:obs, ^tick, _, _, _}, 1_000)
      for _ <- ids, do: assert_receive({:score, ^tick, _}, 1_000)
    end
  end
end
