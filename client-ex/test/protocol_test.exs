defmodule SlimesClient.ProtocolTest do
  use ExUnit.Case, async: true

  alias SlimesClient.Protocol

  test "welcome de colônia" do
    assert {:ok, msg} = Protocol.parse_line("WELCOME srv-0 3 aurora 96CDFB 60 40 1000 3 4,34")
    assert msg.type == "welcome" and msg.role == "colony"
    assert msg.id == 3 and msg.name == "aurora" and msg.color == "96CDFB"
    assert {msg.w, msg.h, msg.tick_ms, msg.view_radius} == {60, 40, 1000, 3}
    assert msg.spawn == {4, 34}
  end

  test "observação" do
    assert {:ok, msg} =
             Protocol.parse_line("OBS srv-97 97 alive 97 9,5,plain,0,0;10,5,plain,3,1")

    assert msg.tick == 97 and msg.status == "alive" and msg.scores_tick == 97

    assert msg.cells == [
             %{x: 9, y: 5, terrain: "plain", owner: 0, fortified: 0},
             %{x: 10, y: 5, terrain: "plain", owner: 3, fortified: 1}
           ]
  end

  test "leitor tolerante: tokens extras no final ignorados" do
    assert {:ok, %{type: "ack", ref: "aurora-k3f9-17", tick: 97}} =
             Protocol.parse_line("ACK aurora-k3f9-17 97 extra tokens")
  end

  test "nack e score" do
    assert {:ok, nack} = Protocol.parse_line("NACK aurora-k3f9-17 too_late tick 96 resolvido")
    assert nack.code == "too_late" and nack.detail == "tick 96 resolvido"

    assert {:ok, score} = Protocol.parse_line("SCORE srv-97 97 3,aurora,21,alive;5,nova,14,dead")

    assert Enum.at(score.entries, 1) == %{id: 5, name: "nova", cells: 14, status: "dead"}
  end

  test "linhas malformadas viram {:error, _}, nunca exceção" do
    assert {:error, _} = Protocol.parse_line("ACTN foo bar")
    assert {:error, _} = Protocol.parse_line("OBS srv-97 x alive 97")
    assert {:error, _} = Protocol.parse_line("OBS srv-97 97 undead 97")
    assert {:error, _} = Protocol.parse_line("WELCOME srv-0 3 aurora 96CDFB 60 40 1000 3")
    assert {:error, _} = Protocol.parse_line("ACK ref notanumber")
    assert :error = Protocol.parse_cell("9,5,plain,0")
  end

  test "encode" do
    refs = Protocol.refs("aurora", "k3f9")
    assert {"aurora-k3f9-1", refs} = Protocol.next_ref(refs)

    assert {"aurora-k3f9-2", refs} = Protocol.next_ref(refs)

    assert Protocol.encode_action(%{kind: "expand", x: 12, y: 7}, "aurora-k3f9-2") ==
             "ACT aurora-k3f9-2 expand 12 7"

    assert {"aurora-k3f9-3", _refs} = Protocol.next_ref(refs)
    assert Protocol.encode_action(%{kind: "pass"}, "aurora-k3f9-3") == "ACT aurora-k3f9-3 pass"
  end
end
