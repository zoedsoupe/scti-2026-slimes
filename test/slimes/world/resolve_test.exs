defmodule Slimes.World.ResolveTest do
  use ExUnit.Case, async: true

  alias Slimes.World.Resolve

  # State shape under test (plain maps, sparse cells):
  #
  #   %{
  #     width: pos_integer,
  #     height: pos_integer,
  #     tick: non_neg_integer,
  #     cells: %{{x, y} => %{terrain: atom, owner: colony_id | 0, fortified: 0 | 1}},
  #     colonies: %{id => %{id:, name:, status: :alive | :dead, oldest: {x, y}}}
  #   }
  #
  # Actions arrive already validated (the World layer NACKs invalid ones):
  #   %{colony: id, kind: :expand | :attack | :fortify, cell: {x, y}}
  #
  # resolve(state, actions, rng) :: {new_state, events}
  # events :: [{:cell, x, y, owner, fortified} | {:eliminated, colony_id}]
  #
  # Adjacency is 4-directional.

  defp build_state(opts) do
    cells =
      opts
      |> Keyword.get(:cells, [])
      |> Map.new(fn
        {x, y, owner} -> {{x, y}, %{terrain: :plain, owner: owner, fortified: 0}}
        {x, y, owner, fort} -> {{x, y}, %{terrain: :plain, owner: owner, fortified: fort}}
      end)

    colonies =
      Map.new(Keyword.get(opts, :colonies, []), fn {id, name, oldest} ->
        {id, %{id: id, name: name, status: :alive, oldest: oldest}}
      end)

    %{
      width: Keyword.get(opts, :width, 10),
      height: Keyword.get(opts, :height, 10),
      tick: Keyword.get(opts, :tick, 1),
      cells: cells,
      colonies: colonies
    }
  end

  defp cell(state, x, y),
    do: Map.get(state.cells, {x, y}, %{terrain: :plain, owner: 0, fortified: 0})

  defp owner_of(state, x, y), do: cell(state, x, y).owner
  defp fortified_at?(state, x, y), do: cell(state, x, y).fortified == 1

  defp rng(tick, base \\ 42), do: :rand.seed(:exsss, {base, tick, 0})

  defp act(id, kind, cell), do: %{colony: id, kind: kind, cell: cell}

  describe "resolve/3 expand" do
    test "takes an adjacent empty cell" do
      state =
        build_state(
          colonies: [{1, "aurora", {1, 1}}],
          cells: [{1, 1, 1}]
        )

      {new_state, events} = Resolve.resolve(state, [act(1, :expand, {1, 2})], rng(1))

      assert owner_of(new_state, 1, 2) == 1
      assert {:cell, 1, 2, 1, 0} in events
    end

    test "conflict: two colonies expanding into the same cell, exactly one wins" do
      state =
        build_state(
          colonies: [{1, "aurora", {1, 1}}, {2, "nova", {3, 1}}],
          cells: [{1, 1, 1}, {3, 1, 2}]
        )

      actions = [act(1, :expand, {2, 1}), act(2, :expand, {2, 1})]

      {new_state, events} = Resolve.resolve(state, actions, rng(1))

      winner = owner_of(new_state, 2, 1)
      assert winner in [1, 2]

      takes = Enum.filter(events, &match?({:cell, 2, 1, _, _}, &1))
      assert length(takes) == 1
    end

    test "conflict winner varies with the tick seed (seeded resolution order)" do
      winners =
        for tick <- 1..20 do
          state =
            build_state(
              tick: tick,
              colonies: [{1, "aurora", {1, 1}}, {2, "nova", {3, 1}}],
              cells: [{1, 1, 1}, {3, 1, 2}]
            )

          actions = [act(1, :expand, {2, 1}), act(2, :expand, {2, 1})]
          {new_state, _} = Resolve.resolve(state, actions, rng(tick))
          owner_of(new_state, 2, 1)
        end

      assert 1 in winners
      assert 2 in winners
    end

    test "the losing action of a conflict is wasted, not requeued" do
      state =
        build_state(
          colonies: [{1, "aurora", {1, 1}}, {2, "nova", {3, 1}}],
          cells: [{1, 1, 1}, {3, 1, 2}]
        )

      actions = [act(1, :expand, {2, 1}), act(2, :expand, {2, 1})]

      {new_state, _} = Resolve.resolve(state, actions, rng(1))
      loser = if owner_of(new_state, 2, 1) == 1, do: 2, else: 1

      # the loser owns nothing new: only its original cell
      owned = for {{_x, _y}, c} <- new_state.cells, c.owner == loser, do: true
      assert length(owned) == 1
    end
  end

  describe "resolve/3 fortify" do
    test "fortifies an own cell" do
      state =
        build_state(
          colonies: [{1, "aurora", {1, 1}}],
          cells: [{1, 1, 1}]
        )

      {new_state, events} = Resolve.resolve(state, [act(1, :fortify, {1, 1})], rng(1))

      assert fortified_at?(new_state, 1, 1)
      assert {:cell, 1, 1, 1, 1} in events
    end

    test "fortify happens in phase 1, before expansion and attacks" do
      # colony 2 attacks colony 1's cell in the same tick that colony 1
      # fortifies it. The attack must face a fortified cell, so it can fail.
      outcomes =
        for tick <- 1..20 do
          state =
            build_state(
              tick: tick,
              colonies: [{1, "aurora", {1, 1}}, {2, "nova", {2, 1}}],
              cells: [{1, 1, 1}, {2, 1, 2}]
            )

          actions = [act(1, :fortify, {1, 1}), act(2, :attack, {1, 1})]
          {new_state, _} = Resolve.resolve(state, actions, rng(tick))
          owner_of(new_state, 1, 1)
        end

      # if fortify did not apply first, the attack would always succeed
      assert 1 in outcomes
      assert 2 in outcomes
    end

    test "fortify events come before expansion events" do
      state =
        build_state(
          colonies: [{1, "aurora", {1, 1}}, {2, "nova", {5, 5}}],
          cells: [{1, 1, 1}, {5, 5, 2}]
        )

      actions = [act(1, :fortify, {1, 1}), act(2, :expand, {5, 6})]
      {_new_state, events} = Resolve.resolve(state, actions, rng(1))

      fortify_idx = Enum.find_index(events, &match?({:cell, 1, 1, 1, 1}, &1))
      expand_idx = Enum.find_index(events, &match?({:cell, 5, 6, 2, 0}, &1))
      assert fortify_idx < expand_idx
    end
  end

  describe "resolve/3 attack" do
    test "always takes an unfortified enemy cell" do
      state =
        build_state(
          colonies: [{1, "aurora", {1, 1}}, {2, "nova", {2, 1}}],
          cells: [{1, 1, 1}, {2, 1, 2}]
        )

      {new_state, events} = Resolve.resolve(state, [act(1, :attack, {2, 1})], rng(1))

      assert owner_of(new_state, 2, 1) == 1
      assert not fortified_at?(new_state, 2, 1)
      assert {:cell, 2, 1, 1, 0} in events
    end

    test "taking a fortified enemy cell is a coin flip on the tick seed" do
      outcomes =
        for tick <- 1..20 do
          state =
            build_state(
              tick: tick,
              colonies: [{1, "aurora", {1, 1}}, {2, "nova", {2, 1}}],
              cells: [{1, 1, 1}, {2, 1, 2, 1}]
            )

          {new_state, _} = Resolve.resolve(state, [act(1, :attack, {2, 1})], rng(tick))
          owner_of(new_state, 2, 1)
        end

      assert 1 in outcomes
      assert 2 in outcomes
    end

    test "a failed attack on a fortified cell leaves the cell untouched" do
      # find a tick seed where the attack fails, then assert no change
      failing_tick =
        Enum.find(1..20, fn tick ->
          state =
            build_state(
              tick: tick,
              colonies: [{1, "aurora", {1, 1}}, {2, "nova", {2, 1}}],
              cells: [{1, 1, 1}, {2, 1, 2, 1}]
            )

          {new_state, _} = Resolve.resolve(state, [act(1, :attack, {2, 1})], rng(tick))
          owner_of(new_state, 2, 1) == 2
        end)

      assert failing_tick, "expected at least one failing coin flip in ticks 1..20"

      state =
        build_state(
          tick: failing_tick,
          colonies: [{1, "aurora", {1, 1}}, {2, "nova", {2, 1}}],
          cells: [{1, 1, 1}, {2, 1, 2, 1}]
        )

      {new_state, events} =
        Resolve.resolve(state, [act(1, :attack, {2, 1})], rng(failing_tick))

      assert owner_of(new_state, 2, 1) == 2
      assert fortified_at?(new_state, 2, 1)
      refute Enum.any?(events, &match?({:cell, 2, 1, _, _}, &1))
    end
  end

  describe "resolve/3 orphan rule" do
    test "cells cut off from the largest component die" do
      # chain 0,0 - 1,0 - 2,0 plus 2,1 and 2,2; enemy cuts the bridge at 1,0
      state =
        build_state(
          colonies: [{1, "aurora", {2, 2}}, {2, "nova", {1, 1}}],
          cells: [{0, 0, 1}, {1, 0, 1}, {2, 0, 1}, {2, 1, 1}, {2, 2, 1}, {1, 1, 2}]
        )

      {new_state, events} = Resolve.resolve(state, [act(2, :attack, {1, 0})], rng(1))

      # bridge taken: components {0,0} (size 1) and {2,0},{2,1},{2,2} (size 3)
      assert owner_of(new_state, 1, 0) == 2
      assert owner_of(new_state, 0, 0) == 0
      assert {:cell, 0, 0, 0, 0} in events

      assert owner_of(new_state, 2, 0) == 1
      assert owner_of(new_state, 2, 1) == 1
      assert owner_of(new_state, 2, 2) == 1
    end

    test "on a tie, the component containing the oldest cell survives" do
      # chain 0,0 - 1,0 - 2,0, oldest is 0,0; nova cuts the bridge at 1,0
      state =
        build_state(
          colonies: [{1, "aurora", {0, 0}}, {2, "nova", {1, 1}}],
          cells: [{0, 0, 1}, {1, 0, 1}, {2, 0, 1}, {1, 1, 2}]
        )

      {new_state, events} = Resolve.resolve(state, [act(2, :attack, {1, 0})], rng(1))

      assert owner_of(new_state, 0, 0) == 1
      assert owner_of(new_state, 2, 0) == 0
      assert {:cell, 2, 0, 0, 0} in events
    end

    test "a colony reduced to zero cells by the orphan rule is eliminated" do
      # colony 1 has a single cell; colony 2 takes it
      state =
        build_state(
          colonies: [{1, "aurora", {1, 1}}, {2, "nova", {2, 1}}],
          cells: [{1, 1, 1}, {2, 1, 2}]
        )

      {new_state, events} = Resolve.resolve(state, [act(2, :attack, {1, 1})], rng(1))

      assert new_state.colonies[1].status == :dead
      assert {:eliminated, 1} in events
      assert new_state.colonies[2].status == :alive
    end
  end

  describe "resolve/3 determinism" do
    test "same seed, same inputs, same outputs" do
      build = fn tick ->
        build_state(
          tick: tick,
          colonies: [{1, "aurora", {1, 1}}, {2, "nova", {3, 1}}],
          cells: [{1, 1, 1}, {3, 1, 2, 1}]
        )
      end

      actions = [act(1, :attack, {3, 1}), act(2, :expand, {3, 2}), act(1, :expand, {1, 2})]

      result_a = Resolve.resolve(build.(7), actions, rng(7))
      result_b = Resolve.resolve(build.(7), actions, rng(7))

      assert result_a == result_b
    end

    test "different tick seeds can produce different outcomes" do
      results =
        for tick <- 1..10 do
          state =
            build_state(
              tick: tick,
              colonies: [{1, "aurora", {1, 1}}, {2, "nova", {3, 1}}],
              cells: [{1, 1, 1}, {3, 1, 2, 1}]
            )

          {new_state, _} = Resolve.resolve(state, [act(1, :attack, {3, 1})], rng(tick))
          owner_of(new_state, 3, 1)
        end

      assert Enum.uniq(results) |> length() > 1
    end
  end

  describe "resolve/3 events" do
    test "events only record actual changes" do
      state =
        build_state(
          colonies: [{1, "aurora", {1, 1}}],
          cells: [{1, 1, 1}]
        )

      {_new_state, events} = Resolve.resolve(state, [], rng(1))

      assert events == []
    end

    test "fortifying an already fortified cell emits no event" do
      state =
        build_state(
          colonies: [{1, "aurora", {1, 1}}],
          cells: [{1, 1, 1, 1}]
        )

      {new_state, events} = Resolve.resolve(state, [act(1, :fortify, {1, 1})], rng(1))

      assert fortified_at?(new_state, 1, 1)
      assert events == []
    end
  end
end
