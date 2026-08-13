defmodule SlimesTest do
  use ExUnit.Case
  doctest Slimes

  test "greets the world" do
    assert Slimes.hello() == :world
  end
end
