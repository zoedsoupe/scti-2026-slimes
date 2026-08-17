defmodule Slimes.Message.Ack do
  @moduledoc """
  Confirmação de uma ação aceita neste tick.

  Responde `ACT` quando a ação entra na resolução do tick corrente. O ref é o
  eco do ref da ação, então o cliente casa a confirmação com o pedido:

      ACK aurora-k3f9-17 97

  O tick informado é o tick em que a ação será resolvida. Se o `ACK` se
  perder, reenviar o mesmo ref é seguro: o servidor deduplica por
  `(colony_id, ref)` e reenvia a confirmação sem reaplicar a ação.
  """

  @type t :: %__MODULE__{
          ref: String.t(),
          tick: non_neg_integer
        }

  defstruct [:ref, :tick]

  @schema %{
    ref: {:required, :string},
    tick: {:required, {:integer, gte: 0}}
  }

  def parse(attrs) do
    with {:ok, attrs} <- Peri.validate(@schema, attrs) do
      struct(__MODULE__, attrs)
    end
  end
end
