defmodule Slimes.Result do
  @moduledoc false

  def map({:ok, val}, fun), do: {:ok, fun.(val)}
  def map(val, _), do: val

  def map_error({:error, reason}, fun), do: {:error, fun.(reason)}
  def map_error(val, _), do: val

  def unwrap!({:ok, val}), do: val

  def ok({:ok, val}), do: {:ok, val}
  def ok({:error, _} = err), do: err
  def ok(val), do: {:ok, val}

  def error({:ok, _} = ok), do: ok
  def error({:error, val}), do: {:error, val}
  def error(val), do: {:error, val}
end
