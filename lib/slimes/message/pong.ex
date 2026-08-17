defmodule Slimes.Message.Pong do
  @moduledoc false

  @type t :: %__MODULE__{ref: String.t()}

  defstruct [:ref]

  @schema %{ref: {:required, :string}}

  def parse(attrs) do
    with {:ok, attrs} <- Peri.validate(@schema, attrs) do
      struct(__MODULE__, attrs)
    end
  end
end
