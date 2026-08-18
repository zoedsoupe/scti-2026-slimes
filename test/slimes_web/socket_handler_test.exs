defmodule SlimesWeb.SocketHandlerTest do
  use ExUnit.Case

  alias Slimes.World
  alias SlimesWeb.SocketHandler

  # O handler é testado pelos callbacks do WebSock, sem bandit: init/1,
  # handle_in/2 e handle_info/2 direto, com um World real por trás.
  # Frames de saída são tuplas {:text, linha}.

  @world_opts [base_seed: 42, width: 10, height: 10, tick_ms: 60_000, mode: :tournament]

  setup do
    {:ok, world} = World.start_link(@world_opts)
    {:ok, state} = SocketHandler.init(world: world)
    %{world: world, state: state}
  end

  defp send_line(state, line), do: SocketHandler.handle_in({line, [opcode: :text]}, state)

  defp join_colony(state, name \\ "aurora") do
    {:push, [frame], state} = send_line(state, "HELLO v1 #{name}-t3st-1 colony #{name}")
    {frame, state}
  end

  describe "HELLO" do
    test "colony hello answers WELCOME with the colony identity", %{state: state} do
      {{:text, line}, state} = join_colony(state)

      assert line =~ ~r/^WELCOME srv-0 1 aurora F5C2E7 10 10 60000 3 \d+,\d+$/
      assert state.status == :joined
      assert state.role == :colony
      assert state.colony_id == 1
    end

    test "spectator hello answers WELCOME with the full grid snapshot", %{state: state} do
      {:push, [{:text, line}], state} = send_line(state, "HELLO v1 proj-t3st-1 spectator")

      assert String.starts_with?(line, "WELCOME srv-0 spectator 10 10 60000 ")
      assert String.contains?(line, "0,0,plain,0,0")
      assert String.contains?(line, "9,9,plain,0,0")
      assert state.role == :spectator
    end

    test "wrong version answers ERR bad_version", %{state: state} do
      {:push, [{:text, line}], _state} = send_line(state, "HELLO v2 aurora-t3st-1 colony aurora")

      assert String.starts_with?(line, "ERR aurora-t3st-1 bad_version")
    end

    test "reserved name answers NACK bad_name", %{state: state} do
      {:push, [{:text, line}], _state} = send_line(state, "HELLO v1 r-1 colony spectator")

      assert String.starts_with?(line, "NACK r-1 bad_name")
    end

    test "a second HELLO answers ERR bad_message and keeps the socket", %{state: state} do
      {_welcome, state} = join_colony(state)

      {:push, [{:text, line}], state} = send_line(state, "HELLO v1 r-2 colony nova")

      assert String.starts_with?(line, "ERR r-2 bad_message")
      assert state.status == :joined
    end
  end

  describe "ACT" do
    test "a valid action answers ACK echoing the ref", %{state: state} do
      {{:text, welcome}, state} = join_colony(state)
      {x, y} = neighbor_of(welcome)

      {:push, [{:text, line}], _state} = send_line(state, "ACT aurora-t3st-2 expand #{x} #{y}")

      assert line == "ACK aurora-t3st-2 0"
    end

    test "an invalid action answers NACK with the domain code", %{state: state} do
      {_welcome, state} = join_colony(state)

      {:push, [{:text, line}], _state} = send_line(state, "ACT aurora-t3st-2 expand 9 9")

      assert String.starts_with?(line, "NACK aurora-t3st-2 bad_cell")
    end

    test "a repeated ref answers NACK duplicate_ref followed by the recorded ACK",
         %{state: state} do
      {{:text, welcome}, state} = join_colony(state)
      {x, y} = neighbor_of(welcome)

      {:push, [ack], state} = send_line(state, "ACT aurora-t3st-2 expand #{x} #{y}")
      assert {:text, "ACK aurora-t3st-2 0"} = ack

      {:push, [nack, duplicate_ack], _state} = send_line(state, "ACT aurora-t3st-2 expand #{x} #{y}")

      assert {:text, nack_line} = nack
      assert String.starts_with?(nack_line, "NACK aurora-t3st-2 duplicate_ref")
      assert duplicate_ack == ack
    end

    test "ACT before HELLO answers ERR bad_message", %{state: state} do
      {:push, [{:text, line}], _state} = send_line(state, "ACT aurora-t3st-2 pass")

      assert String.starts_with?(line, "ERR aurora-t3st-2 bad_message")
    end

    test "ACT on a spectator socket answers ERR bad_message", %{state: state} do
      {:push, [_welcome], state} = send_line(state, "HELLO v1 proj-t3st-1 spectator")

      {:push, [{:text, line}], _state} = send_line(state, "ACT proj-t3st-2 pass")

      assert String.starts_with?(line, "ERR proj-t3st-2 bad_message")
    end
  end

  describe "PING" do
    test "PING after join answers PONG echoing the ref", %{state: state} do
      {_welcome, state} = join_colony(state)

      {:push, [{:text, line}], _state} = send_line(state, "PING aurora-t3st-30")

      assert line == "PONG aurora-t3st-30"
    end

    test "PING before HELLO answers ERR bad_message", %{state: state} do
      {:push, [{:text, line}], _state} = send_line(state, "PING aurora-t3st-30")

      assert String.starts_with?(line, "ERR aurora-t3st-30 bad_message")
    end
  end

  describe "malformed lines" do
    test "unknown type answers ERR bad_message with the best-effort ref", %{state: state} do
      {:push, [{:text, line}], _state} = send_line(state, "ACTN aurora-t3st-2 expand 1 0")

      assert String.starts_with?(line, "ERR aurora-t3st-2 bad_message")
    end

    test "garbage from token one answers ERR with a placeholder ref", %{state: state} do
      {:push, [{:text, line}], _state} = send_line(state, ";;;")

      assert String.starts_with?(line, "ERR unknown bad_message")
    end

    test "a malformed line never crashes the handler", %{state: state} do
      {:push, _, state} = send_line(state, "HELLO")
      {:push, _, state} = send_line(state, "")
      {_welcome, state} = join_colony(state)

      {:push, [{:text, line}], _state} = send_line(state, "PING aurora-t3st-30")
      assert line == "PONG aurora-t3st-30"
    end
  end

  describe "world broadcasts" do
    test "OBS becomes one text frame per line", %{state: state} do
      {_welcome, state} = join_colony(state)

      {:push, [{:text, line}], _state} =
        SocketHandler.handle_info({:obs, 1, :alive, 1, [{0, 0, :plain, 1, 0}]}, state)

      assert line == "OBS srv-1 1 alive 1 0,0,plain,1,0"
    end

    test "SCORE becomes one text frame", %{state: state} do
      {_welcome, state} = join_colony(state)

      {:push, [{:text, line}], _state} =
        SocketHandler.handle_info({:score, 1, [{1, "aurora", 1, :alive}]}, state)

      assert line == "SCORE srv-1 1 1,aurora,1,alive"
    end

    test "DIFF becomes one text frame", %{state: state} do
      {:push, [_welcome], state} = send_line(state, "HELLO v1 proj-t3st-1 spectator")

      {:push, [{:text, line}], _state} =
        SocketHandler.handle_info({:diff, 1, [{1, 0, 1, 0}]}, state)

      assert line == "DIFF srv-1 1 1,0,1,0"
    end

    test "a full match flow: join, act, tick, receive OBS and SCORE", %{world: world, state: state} do
      {{:text, welcome}, state} = join_colony(state)
      assert welcome =~ ~r/^WELCOME srv-0 1 aurora/

      {x, y} = neighbor_of(welcome)
      {:push, [{:text, "ACK aurora-t3st-2 0"}], state} =
        send_line(state, "ACT aurora-t3st-2 expand #{x} #{y}")

      send(world, :tick)

      assert_receive {:obs, 1, :alive, 1, cells}
      assert {x, y, :plain, 1, 0} in cells

      {:push, [{:text, obs_line}], state} =
        SocketHandler.handle_info({:obs, 1, :alive, 1, cells}, state)

      assert obs_line =~ ~r/^OBS srv-1 1 alive 1 /
      assert obs_line =~ "#{x},#{y},plain,1,0"

      assert_receive {:score, 1, entries}
      {:push, [{:text, score_line}], _state} =
        SocketHandler.handle_info({:score, 1, entries}, state)

      assert score_line == "SCORE srv-1 1 1,aurora,2,alive"
    end
  end

  defp neighbor_of(welcome_line) do
    [sx, sy] =
      welcome_line
      |> String.split(" ")
      |> List.last()
      |> String.split(",")
      |> Enum.map(&String.to_integer/1)

    [{sx + 1, sy}, {sx - 1, sy}, {sx, sy + 1}, {sx, sy - 1}]
    |> Enum.find(fn {x, y} -> x >= 0 and y >= 0 and x < 10 and y < 10 end)
  end
end
