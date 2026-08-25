defmodule SlimesClient.PendingTest do
  use ExUnit.Case, async: true

  alias SlimesClient.Pending

  # espelha os defaults de on_timeout/4 (BUDGET/TIMEOUT do cliente JS)
  @budget 3
  @timeout 2

  test "ack remove o ref dos pendentes" do
    pending = Pending.add_pending(%{}, "r-1", "ACT r-1 pass", 10)
    pending = Pending.on_ack(pending, "r-1")
    refute Map.has_key?(pending, "r-1")
  end

  test "timeout dentro do orçamento gera retry" do
    pending = Pending.add_pending(%{}, "r-1", "ACT r-1 expand 3 4", 10)
    {next, effects} = Pending.on_timeout(pending, 10 + @timeout)
    assert effects == [%{retry: "r-1", line: "ACT r-1 expand 3 4"}]
    assert next["r-1"].retries == 1
  end

  test "timeout no limite do orçamento descarta" do
    pending = Pending.add_pending(%{}, "r-1", "ACT r-1 pass", 0)

    # estoura o orçamento: @budget retries, o timeout seguinte derruba
    pending =
      Enum.reduce(1..@budget, pending, fn i, acc ->
        {next, effects} = Pending.on_timeout(acc, i * @timeout)
        assert length(effects) == 1
        assert %{retry: "r-1"} = hd(effects)
        next
      end)

    {next, effects} = Pending.on_timeout(pending, (@budget + 1) * @timeout)
    assert effects == [%{drop: "r-1"}]
    refute Map.has_key?(next, "r-1")
  end

  test "ref recente não vence" do
    pending = Pending.add_pending(%{}, "r-1", "ACT r-1 pass", 10)
    {next, effects} = Pending.on_timeout(pending, 10 + @timeout - 1)
    assert effects == []
    assert next["r-1"].retries == 0
  end
end
