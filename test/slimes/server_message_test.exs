defmodule Slimes.ServerMessageTest do
  use ExUnit.Case, async: true

  alias Slimes.Message
  alias Slimes.Message.{Ack, Cell, Diff, Error, Nack, Obs, Pong, Score, Welcome}

  doctest Slimes.Message.Cell

  @cell %{x: 10, y: 5, terrain: :plain, owner: 3, fortified: 1}

  describe "Cell" do
    test "parses a valid cell" do
      assert %Cell{x: 10, y: 5, terrain: :plain, owner: 3, fortified: 1} = Cell.parse(@cell)
    end

    test "rejects an unknown terrain" do
      assert {:error, [%Peri.Error{key: :terrain}]} = Cell.parse(%{@cell | terrain: :lava})
    end

    test "rejects fortified outside 0 and 1" do
      assert {:error, [%Peri.Error{key: :fortified}]} = Cell.parse(%{@cell | fortified: 2})
    end

    test "rejects negative coordinates" do
      assert {:error, [%Peri.Error{key: :x}]} = Cell.parse(%{@cell | x: -1})
      assert {:error, [%Peri.Error{key: :y}]} = Cell.parse(%{@cell | y: -5})
    end

    test "rejects a negative owner" do
      assert {:error, [%Peri.Error{key: :owner}]} = Cell.parse(%{@cell | owner: -1})
    end
  end

  describe "encode/1 WELCOME" do
    test "encodes a colony welcome byte-for-byte from the protocol example" do
      welcome =
        Welcome.parse(%{
          ref: "srv-0",
          role: :colony,
          id: 3,
          name: "aurora",
          color: "96CDFB",
          w: 60,
          h: 40,
          tick_ms: 1000,
          view_radius: 3,
          spawn: {4, 34}
        })

      assert Message.encode_message(welcome) == "WELCOME srv-0 3 aurora 96CDFB 60 40 1000 3 4,34"
    end

    test "encodes a spectator welcome with the grid snapshot" do
      welcome =
        Welcome.parse(%{
          ref: "srv-0",
          role: :spectator,
          w: 60,
          h: 40,
          tick_ms: 1000,
          cells: [
            %{x: 0, y: 0, terrain: :plain, owner: 0, fortified: 0},
            %{x: 1, y: 0, terrain: :plain, owner: 0, fortified: 0}
          ]
        })

      assert Message.encode_message(welcome) ==
               "WELCOME srv-0 spectator 60 40 1000 0,0,plain,0,0;1,0,plain,0,0"
    end

    test "colony parse leaves spectator fields nil" do
      welcome =
        Welcome.parse(%{
          ref: "srv-0",
          role: :colony,
          id: 3,
          name: "aurora",
          color: "96CDFB",
          w: 60,
          h: 40,
          tick_ms: 1000,
          view_radius: 3,
          spawn: {4, 34}
        })

      assert is_nil(welcome.cells)
    end

    test "spectator parse builds Cell structs and leaves colony fields nil" do
      welcome =
        Welcome.parse(%{
          ref: "srv-0",
          role: :spectator,
          w: 60,
          h: 40,
          tick_ms: 1000,
          cells: [@cell]
        })

      assert [%Cell{x: 10, y: 5}] = welcome.cells
      assert is_nil(welcome.id)
      assert is_nil(welcome.name)
      assert is_nil(welcome.color)
      assert is_nil(welcome.spawn)
    end

    test "rejects a malformed color" do
      assert {:error, [%Peri.Error{key: :color}]} =
               Welcome.parse(%{
                 ref: "srv-0",
                 role: :colony,
                 id: 3,
                 name: "aurora",
                 color: "#96CDFB",
                 w: 60,
                 h: 40,
                 tick_ms: 1000,
                 view_radius: 3,
                 spawn: {4, 34}
               })
    end

    test "rejects a colony welcome missing colony fields" do
      assert {:error, errors} =
               Welcome.parse(%{ref: "srv-0", role: :colony, w: 60, h: 40, tick_ms: 1000})

      keys = Enum.map(errors, & &1.key)
      assert :id in keys
      assert :name in keys
      assert :spawn in keys
    end

    test "rejects a spectator welcome without cells" do
      assert {:error, [%Peri.Error{key: :cells} | _]} =
               Welcome.parse(%{ref: "srv-0", role: :spectator, w: 60, h: 40, tick_ms: 1000})
    end
  end

  describe "encode/1 OBS" do
    test "encodes byte-for-byte from the protocol example" do
      obs =
        Obs.parse(%{
          ref: "srv-97",
          tick: 97,
          status: :alive,
          scores_tick: 97,
          cells: [
            %{x: 9, y: 5, terrain: :plain, owner: 0, fortified: 0},
            %{x: 10, y: 5, terrain: :plain, owner: 3, fortified: 1},
            %{x: 11, y: 5, terrain: :forest, owner: 2, fortified: 0}
          ]
        })

      assert Message.encode_message(obs) ==
               "OBS srv-97 97 alive 97 9,5,plain,0,0;10,5,plain,3,1;11,5,forest,2,0"
    end

    test "parse builds Cell structs" do
      obs =
        Obs.parse(%{ref: "srv-97", tick: 97, status: :dead, scores_tick: 97, cells: [@cell]})

      assert %Obs{status: :dead, cells: [%Cell{owner: 3}]} = obs
    end

    test "rejects an unknown status" do
      assert {:error, [%Peri.Error{key: :status}]} =
               Obs.parse(%{
                 ref: "srv-97",
                 tick: 97,
                 status: :zombie,
                 scores_tick: 97,
                 cells: []
               })
    end

    test "rejects a negative tick" do
      assert {:error, [%Peri.Error{key: :tick} | _]} =
               Obs.parse(%{ref: "srv-97", tick: -1, status: :alive, scores_tick: 97, cells: []})
    end
  end

  describe "encode/1 ACK" do
    test "encodes byte-for-byte from the protocol example" do
      ack = Ack.parse(%{ref: "aurora-k3f9-17", tick: 97})

      assert Message.encode_message(ack) == "ACK aurora-k3f9-17 97"
    end

    test "rejects a negative tick" do
      assert {:error, [%Peri.Error{key: :tick}]} = Ack.parse(%{ref: "r", tick: -1})
    end
  end

  describe "encode/1 NACK" do
    test "encodes with free text until the end of the line" do
      nack =
        Nack.parse(%{
          ref: "aurora-k3f9-17",
          code: :too_late,
          detail: "tick 96 resolvido; acao enfileirada para 97"
        })

      assert Message.encode_message(nack) ==
               "NACK aurora-k3f9-17 too_late tick 96 resolvido; acao enfileirada para 97"
    end

    test "accepts every code from the protocol table" do
      for code <- ~w(bad_name bad_cell not_empty not_enemy not_self attacks_disabled duplicate_ref too_late)a do
        assert %Nack{code: ^code} = Nack.parse(%{ref: "r", code: code})
      end
    end

    test "rejects an ERR-only code" do
      assert {:error, [%Peri.Error{key: :code}]} = Nack.parse(%{ref: "r", code: :bad_version})
      assert {:error, [%Peri.Error{key: :code}]} = Nack.parse(%{ref: "r", code: :bad_message})
    end
  end

  describe "encode/1 SCORE" do
    test "encodes byte-for-byte from the protocol example" do
      score =
        Score.parse(%{
          ref: "srv-97",
          tick: 97,
          entries: [
            %{id: 3, name: "aurora", cells: 21, status: :alive},
            %{id: 5, name: "nova", cells: 14, status: :dead}
          ]
        })

      assert Message.encode_message(score) == "SCORE srv-97 97 3,aurora,21,alive;5,nova,14,dead"
    end

    test "rejects an entry with unknown status" do
      assert {:error, [%Peri.Error{key: :entries, errors: [%Peri.Error{key: :status} | _]}]} =
               Score.parse(%{
                 ref: "srv-97",
                 tick: 97,
                 entries: [%{id: 3, name: "aurora", cells: 21, status: :zombie}]
               })
    end

    test "rejects an entry missing a field" do
      assert {:error, [%Peri.Error{} | _]} =
               Score.parse(%{ref: "srv-97", tick: 97, entries: [%{id: 3, name: "aurora"}]})
    end
  end

  describe "encode/1 DIFF" do
    test "encodes byte-for-byte from the protocol example" do
      diff =
        Diff.parse(%{
          ref: "srv-97",
          tick: 97,
          changes: [
            %{x: 12, y: 7, owner: 3, fortified: 0},
            %{x: 12, y: 8, owner: 0, fortified: 0}
          ]
        })

      assert Message.encode_message(diff) == "DIFF srv-97 97 12,7,3,0;12,8,0,0"
    end

    test "rejects fortified outside 0 and 1" do
      assert {:error, [%Peri.Error{key: :changes, errors: [%Peri.Error{key: :fortified} | _]}]} =
               Diff.parse(%{
                 ref: "srv-97",
                 tick: 97,
                 changes: [%{x: 12, y: 7, owner: 3, fortified: 2}]
               })
    end
  end

  describe "encode/1 PONG and ERR" do
    test "encodes a pong" do
      assert Message.encode_message(%Pong{ref: "aurora-k3f9-30"}) == "PONG aurora-k3f9-30"
    end

    test "encodes an error with free text" do
      err = Error.parse(%{ref: "aurora-k3f9-31", code: :bad_message, detail: "tipo desconhecido ACTN"})

      assert Message.encode_message(err) == "ERR aurora-k3f9-31 bad_message tipo desconhecido ACTN"
    end

    test "accepts the duplicate_ref code from the protocol table" do
      assert %Error{code: :duplicate_ref} = Error.parse(%{ref: "r", code: :duplicate_ref})
    end
  end
end
