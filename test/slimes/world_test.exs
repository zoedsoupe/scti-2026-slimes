defmodule Slimes.WorldTest do
  use ExUnit.Case

  alias Slimes.Message.Act
  alias Slimes.World

  # World is a GenServer owning grid state, the tick loop, the
  # colony_id => handler_pid map, the spectator list, the dedup table
  # and the event log.
  #
  # API under test:
  #   World.start_link(opts)
  #     opts: :base_seed, :width, :height, :tick_ms, :mode (:tournament | :cooperative),
  #           optional :spawns (%{name => {x, y}}) and :terrain ([{x, y, atom}])
  #   World.join(world, name, handler_pid)
  #     :: {:ok, %{id:, name:, color:, width:, height:, tick_ms:, view_radius:, spawn:}}
  #      | {:error, :bad_name}
  #   World.watch(world, spectator_pid)
  #     :: {:ok, %{width:, height:, tick_ms:, cells: [{x, y, terrain, owner, fortified}]}}
  #   World.act(world, colony_id, %Act{})
  #     :: {:ok, tick} | {:error, code} | {:duplicate, {:ok, tick}}
  #   World.event_log(world) :: [event]
  #
  # Broadcasts reach handler pids as plain messages:
  #   {:obs, tick, status, scores_tick, cells}    colonies only
  #   {:score, tick, entries}                     everyone
  #     entries :: [{colony_id, name, cell_count, :alive | :dead}]
  #   {:diff, tick, changes}                      spectators only
  #     changes :: [{x, y, owner, fortified}]
  #
  # Tests drive ticks by sending :tick directly; tick_ms is set high so the
  # timer never fires during a test.
  #
  # Assumed conventions: the world starts at tick 0 (first ACK answers 0,
  # first broadcast is tick 1), and the GenServer state is a struct with an
  # :accepting flag that is false while the resolution window is closed
  # (the too_late test flips it via :sys.replace_state/2). Own cells count as
  # "adjacent to the colony" for the bad_cell check, so expanding into an own
  # cell reaches the ownership check and answers not_empty.

  @base_opts [base_seed: 42, width: 10, height: 10, tick_ms: 60_000, mode: :tournament]

  defp start_world(opts \\ []) do
    {:ok, world} = World.start_link(Keyword.merge(@base_opts, opts))
    world
  end

  defp act(ref, kind, x \\ nil, y \\ nil), do: %Act{ref: ref, kind: kind, x: x, y: y}

  defp tick(world), do: send(world, :tick)

  defp neighbor_of({x, y}, w, h) do
    [{x + 1, y}, {x - 1, y}, {x, y + 1}, {x, y - 1}]
    |> Enum.find(fn {nx, ny} -> nx >= 0 and ny >= 0 and nx < w and ny < h end)
  end

  describe "join/3 colonies" do
    test "first colony gets id 1, the first palette color and a corner spawn" do
      world = start_world()

      assert {:ok, info} = World.join(world, "aurora", self())

      assert info.id == 1
      assert info.name == "aurora"
      assert info.color == "F5C2E7"
      assert info.width == 10
      assert info.height == 10
      assert info.tick_ms == 60_000
      assert info.view_radius == 3
      assert info.spawn in [{0, 0}, {9, 0}, {0, 9}, {9, 9}]
    end

    test "ids and colors follow join order" do
      world = start_world()

      assert {:ok, %{id: 1, color: "F5C2E7"}} = World.join(world, "a", self())
      assert {:ok, %{id: 2, color: "96CDFB"}} = World.join(world, "b", self())
      assert {:ok, %{id: 3, color: "8BD5CA"}} = World.join(world, "c", self())
    end

    test "spawns are distinct and deterministic for the same base seed" do
      world_a = start_world()
      world_b = start_world()

      {:ok, one} = World.join(world_a, "a", self())
      {:ok, two} = World.join(world_a, "b", self())
      {:ok, other} = World.join(world_b, "a", self())

      assert one.spawn != two.spawn
      assert one.spawn == other.spawn
    end

    test "rejects the reserved name" do
      world = start_world()

      assert {:error, :bad_name} = World.join(world, "spectator", self())
    end

    test "rejects invalid names" do
      world = start_world()

      assert {:error, :bad_name} = World.join(world, "Aurora", self())
      assert {:error, :bad_name} = World.join(world, "slime_lord", self())
      assert {:error, :bad_name} = World.join(world, "abcdefghijklmnopq", self())
      assert {:error, :bad_name} = World.join(world, "", self())
    end

    test "rejoining with a live name resumes the colony and repoints the handler" do
      world = start_world()
      stale_handler = spawn(fn -> :timer.sleep(:infinity) end)

      {:ok, first} = World.join(world, "aurora", stale_handler)
      {:ok, resumed} = World.join(world, "aurora", self())

      assert resumed.id == first.id
      assert resumed.color == first.color
      assert resumed.spawn == first.spawn

      tick(world)
      assert_receive {:obs, 1, :alive, _, _}
    end

    test "an eliminated colony's name joins fresh with a new id" do
      world = start_world(width: 5, height: 1, spawns: %{"aurora" => {0, 0}, "nova" => {2, 0}})

      {:ok, %{id: aurora_id}} = World.join(world, "aurora", self())
      {:ok, %{id: nova_id}} = World.join(world, "nova", self())

      {:ok, _} = World.act(world, nova_id, act("n-1", :expand, 1, 0))
      tick(world)
      assert_receive {:obs, 1, :alive, _, _}

      {:ok, _} = World.act(world, nova_id, act("n-2", :attack, 0, 0))
      tick(world)
      assert_receive {:obs, 2, :dead, _, []}

      assert {:ok, fresh} = World.join(world, "aurora", self())
      assert fresh.id != aurora_id
      assert fresh.id == 3
      assert fresh.spawn != {0, 0}
    end
  end

  describe "watch/2 spectators" do
    test "returns the full grid snapshot with terrain" do
      world = start_world(terrain: [{3, 3, :forest}])

      assert {:ok, snapshot} = World.watch(world, self())

      assert snapshot.width == 10
      assert snapshot.height == 10
      assert snapshot.tick_ms == 60_000
      assert length(snapshot.cells) == 100
      assert {3, 3, :forest, 0, 0} in snapshot.cells
      assert {0, 0, :plain, 0, 0} in snapshot.cells
    end

    test "spectators receive DIFF and SCORE, never OBS" do
      world = start_world()

      {:ok, _} = World.watch(world, self())
      {:ok, %{id: id, spawn: spawn}} = World.join(world, "aurora", spawnless())
      {tx, ty} = neighbor_of(spawn, 10, 10)
      {:ok, _} = World.act(world, id, act("a-1", :expand, tx, ty))

      tick(world)

      assert_receive {:diff, 1, changes}
      assert {tx, ty, id, 0} in changes
      assert_receive {:score, 1, _}
      refute_receive {:obs, _, _, _, _}
    end
  end

  describe "act/3 validation" do
    setup do
      world = start_world()
      {:ok, info} = World.join(world, "aurora", self())
      %{world: world, id: info.id, spawn: info.spawn}
    end

    test "accepts a valid action and answers with the current tick", %{world: w, id: id, spawn: s} do
      {tx, ty} = neighbor_of(s, 10, 10)

      assert {:ok, 0} = World.act(w, id, act("a-1", :expand, tx, ty))
    end

    test "pass is always valid", %{world: w, id: id} do
      assert {:ok, 0} = World.act(w, id, act("a-1", :pass))
    end

    test "rejects cells outside the grid with bad_cell", %{world: w, id: id} do
      assert {:error, :bad_cell} = World.act(w, id, act("a-1", :expand, 10, 0))
      assert {:error, :bad_cell} = World.act(w, id, act("a-2", :expand, 0, 10))
    end

    test "rejects cells not adjacent to the colony with bad_cell", %{world: w, id: id, spawn: s} do
      {sx, sy} = s
      # a cell at Chebyshev distance 3 from the spawn, clamped in-bounds
      fx = if(sx + 3 < 10, do: sx + 3, else: sx - 3)
      fy = if(sy + 3 < 10, do: sy + 3, else: sy - 3)

      assert {:error, :bad_cell} = World.act(w, id, act("a-1", :expand, fx, fy))
    end

    test "rejects expand into an own cell with not_empty", %{world: w, id: id, spawn: {sx, sy}} do
      assert {:error, :not_empty} = World.act(w, id, act("a-1", :expand, sx, sy))
    end

    test "rejects attack into an empty cell with not_enemy", %{world: w, id: id, spawn: s} do
      {tx, ty} = neighbor_of(s, 10, 10)

      assert {:error, :not_enemy} = World.act(w, id, act("a-1", :attack, tx, ty))
    end

    test "rejects fortify of a cell the colony does not own with not_self", %{world: w, id: id, spawn: s} do
      {tx, ty} = neighbor_of(s, 10, 10)

      assert {:error, :not_self} = World.act(w, id, act("a-1", :fortify, tx, ty))
    end

    test "fortify of an already fortified own cell is acked and wasted", %{world: w, id: id, spawn: {sx, sy}} do
      assert {:ok, _} = World.act(w, id, act("a-1", :fortify, sx, sy))
      tick(w)
      assert_receive {:obs, 1, :alive, _, _}

      assert {:ok, _} = World.act(w, id, act("a-2", :fortify, sx, sy))
    end
  end

  describe "act/3 in cooperative mode" do
    test "attack is rejected with attacks_disabled" do
      world = start_world(mode: :cooperative, spawns: %{"a" => {0, 0}, "b" => {1, 0}})

      {:ok, %{id: a}} = World.join(world, "a", self())
      {:ok, _} = World.join(world, "b", spawnless())

      assert {:error, :attacks_disabled} = World.act(world, a, act("a-1", :attack, 1, 0))
    end

    test "attacks_disabled is checked before cell validity" do
      world = start_world(mode: :cooperative, spawns: %{"a" => {0, 0}})

      {:ok, %{id: a}} = World.join(world, "a", self())

      # 9,9 is neither adjacent nor enemy: the mode answer must win
      assert {:error, :attacks_disabled} = World.act(world, a, act("a-1", :attack, 9, 9))
    end
  end

  describe "act/3 dedup and queueing" do
    setup do
      world = start_world()
      {:ok, info} = World.join(world, "aurora", self())
      %{world: world, id: info.id, spawn: info.spawn}
    end

    test "a repeated ref answers duplicate and does not reapply", %{world: w, id: id, spawn: s} do
      {tx, ty} = neighbor_of(s, 10, 10)

      assert {:ok, tick} = World.act(w, id, act("a-1", :expand, tx, ty))
      assert {:duplicate, {:ok, ^tick}} = World.act(w, id, act("a-1", :expand, tx, ty))

      tick(w)

      assert_receive {:obs, 1, :alive, _, cells}
      assert {tx, ty, :plain, id, 0} in cells
    end

    test "the last valid action in the window wins", %{world: w, id: id, spawn: s} do
      {sx, sy} = s

      neighbors =
        [{sx + 1, sy}, {sx - 1, sy}, {sx, sy + 1}, {sx, sy - 1}]
        |> Enum.filter(fn {x, y} -> x >= 0 and y >= 0 and x < 10 and y < 10 end)

      # a corner spawn in a 10x10 grid always has two in-bounds neighbors
      assert length(neighbors) >= 2
      [{ax, ay}, {bx, by} | _] = neighbors

      assert {:ok, _} = World.act(w, id, act("a-1", :expand, ax, ay))
      assert {:ok, _} = World.act(w, id, act("a-2", :expand, bx, by))

      tick(w)

      assert_receive {:obs, 1, :alive, _, cells}
      assert {bx, by, :plain, id, 0} in cells
      refute {ax, ay, :plain, id, 0} in cells
    end

    test "an action arriving after resolution is too_late and queued for the next tick",
         %{world: w, id: id, spawn: s} do
      {tx, ty} = neighbor_of(s, 10, 10)

      # simulate the resolution window being closed
      :sys.replace_state(w, &%{&1 | accepting: false})

      assert {:error, :too_late} = World.act(w, id, act("a-1", :expand, tx, ty))

      :sys.replace_state(w, &%{&1 | accepting: true})

      # the late action was not dropped: it applies on the next tick
      tick(w)

      assert_receive {:obs, 1, :alive, _, cells}
      assert {tx, ty, :plain, id, 0} in cells
    end
  end

  describe "tick broadcasts" do
    test "colonies receive OBS with their local view only" do
      world = start_world(spawns: %{"aurora" => {0, 0}, "nova" => {9, 9}})

      {:ok, %{id: id}} = World.join(world, "aurora", self())
      {:ok, _} = World.join(world, "nova", spawnless())

      tick(world)

      assert_receive {:obs, 1, :alive, scores_tick, cells}
      assert scores_tick == 1

      # union of 7x7 neighborhoods around owned cells, in-bounds only
      assert length(cells) == 16
      assert {0, 0, :plain, id, 0} in cells
      assert Enum.all?(cells, fn {x, y, _, _, _} ->
               x in 0..3 and y in 0..3
             end)
    end

    test "OBS shows enemy fortifications" do
      world = start_world(spawns: %{"aurora" => {0, 0}, "nova" => {1, 0}})

      {:ok, _} = World.join(world, "aurora", self())
      {:ok, %{id: nova_id}} = World.join(world, "nova", spawnless())

      {:ok, _} = World.act(world, nova_id, act("n-1", :fortify, 1, 0))
      tick(world)

      assert_receive {:obs, 1, :alive, _, cells}
      assert {1, 0, :plain, nova_id, 1} in cells
    end

    test "eliminated colonies keep receiving OBS with status dead and no cells" do
      world = start_world(width: 5, height: 1, spawns: %{"aurora" => {0, 0}, "nova" => {2, 0}})

      {:ok, _} = World.join(world, "aurora", self())
      {:ok, %{id: nova_id}} = World.join(world, "nova", spawnless())

      {:ok, _} = World.act(world, nova_id, act("n-1", :expand, 1, 0))
      tick(world)
      assert_receive {:obs, 1, :alive, _, _}

      {:ok, _} = World.act(world, nova_id, act("n-2", :attack, 0, 0))
      tick(world)
      assert_receive {:obs, 2, :dead, _, []}

      tick(world)
      assert_receive {:obs, 3, :dead, _, []}
    end

    test "SCORE reaches colonies and spectators, including the eliminated" do
      world = start_world(width: 5, height: 1, spawns: %{"aurora" => {0, 0}, "nova" => {2, 0}})

      {:ok, _} = World.watch(world, self())
      {:ok, %{id: aurora_id}} = World.join(world, "aurora", self())
      {:ok, %{id: nova_id}} = World.join(world, "nova", spawnless())

      {:ok, _} = World.act(world, nova_id, act("n-1", :expand, 1, 0))
      tick(world)
      assert_receive {:score, 1, _}
      assert_receive {:obs, 1, :alive, _, _}

      {:ok, _} = World.act(world, nova_id, act("n-2", :attack, 0, 0))
      tick(world)

      assert_receive {:score, 2, entries}
      assert {aurora_id, "aurora", 0, :dead} in entries
      assert {nova_id, "nova", 3, :alive} in entries
    end

    test "DIFF includes cells that became empty" do
      world =
        start_world(
          width: 5,
          height: 3,
          spawns: %{"aurora" => {0, 1}, "nova" => {1, 0}}
        )

      {:ok, _} = World.watch(world, self())
      {:ok, %{id: aurora_id}} = World.join(world, "aurora", spawnless())
      {:ok, %{id: nova_id}} = World.join(world, "nova", spawnless())

      {:ok, _} = World.act(world, aurora_id, act("a-1", :expand, 1, 1))
      tick(world)
      assert_receive {:diff, 1, _}

      {:ok, _} = World.act(world, aurora_id, act("a-2", :expand, 2, 1))
      tick(world)
      assert_receive {:diff, 2, _}

      # nova cuts the bridge at 1,1: aurora splits into {0,1} and {2,1},
      # the orphan {2,1} dies and must appear in the diff as emptied
      {:ok, _} = World.act(world, nova_id, act("n-1", :attack, 1, 1))
      tick(world)

      assert_receive {:diff, 3, changes}
      assert {1, 1, nova_id, 0} in changes
      assert {2, 1, 0, 0} in changes
    end

    test "tick numbers increase across ticks" do
      world = start_world()
      {:ok, _} = World.join(world, "aurora", self())

      tick(world)
      assert_receive {:obs, 1, _, _, _}

      tick(world)
      assert_receive {:obs, 2, _, _, _}
    end
  end

  describe "event log" do
    test "records tick events in order" do
      world = start_world(spawns: %{"aurora" => {0, 0}})

      {:ok, %{id: id}} = World.join(world, "aurora", self())
      {:ok, _} = World.act(world, id, act("a-1", :expand, 1, 0))

      assert World.event_log(world) == []

      tick(world)
      assert_receive {:obs, 1, _, _, _}

      log = World.event_log(world)
      assert log != []
      assert Enum.any?(log, &match?({:cell, 1, 0, ^id, 0}, &1))
    end
  end

  # a throwaway handler pid for joins whose messages the test does not read
  defp spawnless do
    spawn(fn -> :timer.sleep(:infinity) end)
  end
end
