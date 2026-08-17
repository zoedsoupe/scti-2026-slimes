defmodule Slimes.Message.Ping do
  @moduledoc """
  Verificação de vida do socket.

      PING aurora-k3f9-30

  Respondida por `PONG` ecoando o mesmo ref.
  """

  @type t :: %__MODULE__{ref: String.t()}

  defstruct [:ref]

  @schema %{ref: {:required, :string}}

  def parse(attrs) do
    with {:ok, attrs} <- Peri.validate(@schema, attrs) do
      struct(__MODULE__, attrs)
    end
  end
end
