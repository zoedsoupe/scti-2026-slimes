defmodule Slimes.MessageTest do
  use ExUnit.Case, async: true

  alias Slimes.Message
  alias Slimes.Message.{Act, Hello, Ping}

  describe "decode/1 HELLO" do
    test "parses a colony hello" do
      assert {:ok, msg} = Message.decode_message("HELLO v1 aurora-k3f9-1 colony aurora")

      assert %Hello{} = msg
      assert msg.version == :v1
      assert msg.ref == "aurora-k3f9-1"
      assert msg.role == :colony
      assert msg.name == "aurora"
    end

    test "parses a spectator hello without a name" do
      assert {:ok, msg} = Message.decode_message("HELLO v1 proj-a1b2-1 spectator")

      assert %Hello{} = msg
      assert msg.version == :v1
      assert msg.ref == "proj-a1b2-1"
      assert msg.role == :spectator
      assert is_nil(msg.name)
    end

    test "accepts colony names across the full allowed alphabet" do
      assert {:ok, %Hello{name: "a"}} = Message.decode_message("HELLO v1 r-1 colony a")

      assert {:ok, %Hello{name: "slime-lord-9000"}} =
               Message.decode_message("HELLO v1 r-1 colony slime-lord-9000")

      assert {:ok, %Hello{name: "abcdefghijklmnop"}} =
               Message.decode_message("HELLO v1 r-1 colony abcdefghijklmnop")
    end

    test "ignores extra trailing tokens (tolerant reader)" do
      assert {:ok, %Hello{role: :colony, name: "aurora"}} =
               Message.decode_message("HELLO v1 aurora-k3f9-1 colony aurora extra tokens here")

      assert {:ok, %Hello{role: :spectator}} =
               Message.decode_message("HELLO v1 proj-a1b2-1 spectator extra")
    end

    test "rejects a version other than v1 with :bad_version" do
      assert {:error, [%{code: :bad_version, key: :version, detail: detail}]} =
               Message.decode_message("HELLO v2 aurora-k3f9-1 colony aurora")

      assert is_binary(detail)

      assert {:error, [%{code: :bad_version}]} =
               Message.decode_message("HELLO v0 aurora-k3f9-1 spectator")

      assert {:error, [%{code: :bad_version}]} =
               Message.decode_message("HELLO 1 aurora-k3f9-1 colony aurora")
    end

    test "rejects invalid colony names with :bad_name" do
      assert {:error, [%{code: :bad_name, key: :name, detail: detail}]} =
               Message.decode_message("HELLO v1 aurora-k3f9-1 colony Aurora")

      assert is_binary(detail)

      assert {:error, [%{code: :bad_name, key: :name}]} =
               Message.decode_message("HELLO v1 aurora-k3f9-1 colony slime_lord")

      assert {:error, [%{code: :bad_name, key: :name}]} =
               Message.decode_message("HELLO v1 aurora-k3f9-1 colony abcdefghijklmnopq")
    end

    test "rejects the reserved name spectator with :bad_name" do
      assert {:error, [%{code: :bad_name, key: :name}]} =
               Message.decode_message("HELLO v1 aurora-k3f9-1 colony spectator")
    end

    test "rejects a colony hello without a name" do
      assert {:error, [%{code: :bad_message} | _]} =
               Message.decode_message("HELLO v1 aurora-k3f9-1 colony")
    end

    test "rejects an unknown role" do
      assert {:error, [%{code: :bad_message} | _]} =
               Message.decode_message("HELLO v1 aurora-k3f9-1 admin aurora")
    end

    test "rejects wrong arity" do
      assert {:error, [%{code: :bad_message} | _]} = Message.decode_message("HELLO")
      assert {:error, [%{code: :bad_message} | _]} = Message.decode_message("HELLO v1")

      assert {:error, [%{code: :bad_message} | _]} =
               Message.decode_message("HELLO v1 aurora-k3f9-1")
    end
  end

  describe "decode/1 ACT" do
    test "parses pass without coordinates" do
      assert {:ok, msg} = Message.decode_message("ACT aurora-k3f9-18 pass")

      assert %Act{} = msg
      assert msg.ref == "aurora-k3f9-18"
      assert msg.kind == :pass
      assert is_nil(msg.x)
      assert is_nil(msg.y)
    end

    test "parses expand with integer coordinates" do
      assert {:ok, msg} = Message.decode_message("ACT aurora-k3f9-17 expand 12 7")

      assert %Act{} = msg
      assert msg.ref == "aurora-k3f9-17"
      assert msg.kind == :expand
      assert msg.x == 12
      assert msg.y == 7
    end

    test "parses attack and fortify" do
      assert {:ok, %Act{kind: :attack, x: 0, y: 59}} =
               Message.decode_message("ACT aurora-k3f9-19 attack 0 59")

      assert {:ok, %Act{kind: :fortify, x: 4, y: 34}} =
               Message.decode_message("ACT aurora-k3f9-20 fortify 4 34")
    end

    test "ignores extra trailing tokens (tolerant reader)" do
      assert {:ok, %Act{kind: :expand, x: 12, y: 7}} =
               Message.decode_message("ACT aurora-k3f9-17 expand 12 7 extra")

      assert {:ok, %Act{kind: :pass}} =
               Message.decode_message("ACT aurora-k3f9-18 pass 12 7")
    end

    test "rejects a non-integer coordinate with :bad_message" do
      assert {:error, [%{code: :bad_message, key: :x} | _]} =
               Message.decode_message("ACT aurora-k3f9-17 expand x 7")

      assert {:error, [%{code: :bad_message, key: :y} | _]} =
               Message.decode_message("ACT aurora-k3f9-17 expand 12 seven")

      assert {:error, [%{code: :bad_message} | _]} =
               Message.decode_message("ACT aurora-k3f9-17 expand 1.5 7")
    end

    test "rejects a negative coordinate with :bad_cell" do
      assert {:error, [%{code: :bad_cell, key: :x, detail: detail} | _]} =
               Message.decode_message("ACT aurora-k3f9-17 expand -1 7")

      assert is_binary(detail)

      assert {:error, [%{code: :bad_cell, key: :y} | _]} =
               Message.decode_message("ACT aurora-k3f9-17 expand 12 -7")
    end

    test "returns one error per key when multiple coordinates are invalid" do
      assert {:error, errors} = Message.decode_message("ACT aurora-k3f9-17 expand -1 -7")

      assert length(errors) == 2
      assert Enum.all?(errors, &(&1.code == :bad_cell))
      assert Enum.all?(errors, &(&1.key in [:x, :y]))
      assert Enum.all?(errors, &is_binary(&1.detail))
    end

    test "rejects missing coordinates on non-pass kinds" do
      assert {:error, [%{code: :bad_message} | _]} =
               Message.decode_message("ACT aurora-k3f9-17 expand")

      assert {:error, [%{code: :bad_message} | _]} =
               Message.decode_message("ACT aurora-k3f9-17 expand 12")

      assert {:error, [%{code: :bad_message} | _]} =
               Message.decode_message("ACT aurora-k3f9-17 attack")

      assert {:error, [%{code: :bad_message} | _]} =
               Message.decode_message("ACT aurora-k3f9-17 fortify")
    end

    test "rejects an unknown kind" do
      assert {:error, [%{code: :bad_message} | _]} =
               Message.decode_message("ACT aurora-k3f9-17 conquer 12 7")
    end

    test "rejects wrong arity" do
      assert {:error, [%{code: :bad_message} | _]} = Message.decode_message("ACT")

      assert {:error, [%{code: :bad_message} | _]} =
               Message.decode_message("ACT aurora-k3f9-17")
    end
  end

  describe "decode/1 PING" do
    test "parses a ping" do
      assert {:ok, msg} = Message.decode_message("PING aurora-k3f9-30")

      assert %Ping{} = msg
      assert msg.ref == "aurora-k3f9-30"
    end

    test "ignores extra trailing tokens (tolerant reader)" do
      assert {:ok, %Ping{ref: "aurora-k3f9-30"}} =
               Message.decode_message("PING aurora-k3f9-30 extra")
    end

    test "rejects a ping without a ref" do
      assert {:error, [%{code: :bad_message} | _]} = Message.decode_message("PING")
    end
  end

  describe "decode/1 malformed lines" do
    test "rejects an unknown message type" do
      assert {:error, [%{code: :bad_message} | _]} =
               Message.decode_message("ACTN aurora-k3f9-17 expand 12 7")

      assert {:error, [%{code: :bad_message} | _]} =
               Message.decode_message("WELCOME srv-0 3 aurora")
    end

    test "rejects lowercase types (protocol types are uppercase)" do
      assert {:error, [%{code: :bad_message} | _]} =
               Message.decode_message("act aurora-k3f9-17 pass")

      assert {:error, [%{code: :bad_message} | _]} =
               Message.decode_message("hello v1 r colony aurora")
    end

    test "rejects empty and whitespace-only lines" do
      assert {:error, [%{code: :bad_message} | _]} = Message.decode_message("")
      assert {:error, [%{code: :bad_message} | _]} = Message.decode_message("   ")
    end

    test "rejects garbage" do
      assert {:error, [%{code: :bad_message} | _]} = Message.decode_message(";;;")
      assert {:error, [%{code: :bad_message} | _]} = Message.decode_message("HELLOv1aurora")
    end
  end

  describe "decode/1 line handling" do
    test "trims surrounding whitespace" do
      assert {:ok, %Ping{ref: "aurora-k3f9-30"}} =
               Message.decode_message("  PING aurora-k3f9-30  ")
    end

    test "strips a trailing newline" do
      assert {:ok, %Act{kind: :pass}} =
               Message.decode_message("ACT aurora-k3f9-18 pass\n")
    end
  end
end
