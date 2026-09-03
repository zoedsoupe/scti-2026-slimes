defmodule SlimesClient.DecideTest do
  use ExUnit.Case, async: true

  alias SlimesClient.Decide

  defp cell(x, y, owner, fortified \\ 0),
    do: %{x: x, y: y, terrain: "plain", owner: owner, fortified: fortified}

  test "inimigo desfortificado adjacente leva attack" do
    obs = %{cells: [cell(5, 5, 1), cell(6, 5, 2, 0)]}
    assert Decide.decide(obs, 1).kind == "attack"
  end

  test "sem inimigos e com vazia adjacente leva expand" do
    obs = %{cells: [cell(5, 5, 1), cell(6, 5, 0)]}
    assert Decide.decide(obs, 1).kind == "expand"
  end

  test "só inimigo fortificado adjacente leva fortify" do
    # decide/2 fortifica uma célula de fronteira quando há inimigos mas
    # todos estão fortificados
    obs = %{cells: [cell(5, 5, 1), cell(6, 5, 2, 1)]}
    assert Decide.decide(obs, 1).kind == "fortify"
  end

  test "sem para onde ir leva pass" do
    obs = %{
      cells: [cell(5, 5, 1), cell(4, 5, 1), cell(6, 5, 1), cell(5, 4, 1), cell(5, 6, 1)]
    }

    assert Decide.decide(obs, 1).kind == "pass"
  end
end
