defmodule Slimes.Message.Act do
  @moduledoc false

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
    {:ok, {:required, {:coerce, {:integer, gte: 0}}}}
  end

  def parse(attrs) do
    with {:ok, attrs} <- Peri.validate(schema(), attrs) do
      struct(__MODULE__, attrs)
    end
  end
end
