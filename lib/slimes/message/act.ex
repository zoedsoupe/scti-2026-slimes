defmodule Slimes.Message.Act do
  @moduledoc """
  A única ação da colônia neste tick.

      ACT aurora-k3f9-17 expand 12 7
      ACT aurora-k3f9-18 pass

  Os tipos são `expand`, `attack`, `fortify` e `pass`. As coordenadas são
  absolutas e obrigatórias, exceto em `pass`. Respondida por `ACK` (aceita
  neste tick) ou `NACK` (rejeitada, com código). Reenviar o mesmo ref depois
  de perder um `ACK` é seguro: o servidor deduplica por `(colony_id, ref)` e
  reenvia a confirmação sem reaplicar a ação.
  """

  @type t :: %__MODULE__{
          ref: String.t(),
          kind: :pass | :attack | :expand | :fortify,
          x: integer | nil,
          y: integer | nil
        }

  defstruct [:ref, :kind, :x, :y]

  @kinds ~w(pass attack expand fortify)a

  defp schema do
    %{
      ref: {:required, :string},
      kind: {:required, {:coerce, {:enum, @kinds}}},
      x: {:dependent, &with_coords/1},
      y: {:dependent, &with_coords/1}
    }
  end

  defp with_coords(%{kind: kind}) when kind in ["pass", :pass], do: {:ok, nil}

  defp with_coords(_) do
    {:ok, {:required, {:coerce, {:integer, gte: 0, error: "coordenada fora da grade"}}}}
  end

  def parse(attrs) do
    with {:ok, attrs} <- Peri.validate(schema(), attrs) do
      struct(__MODULE__, attrs)
    end
  end
end
