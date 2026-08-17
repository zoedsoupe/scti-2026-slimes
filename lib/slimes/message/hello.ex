defmodule Slimes.Message.Hello do
  @moduledoc false

  @type t :: %__MODULE__{
          ref: String.t(),
          version: :v1 | :v2,
          role: :spectator | :colony,
          name: String.t() | nil
        }

  defstruct [:ref, :version, :role, :name]

  defp schema do
    %{
      version: {:required, {:coerce, {:enum, ~w(v1 v2)a}}},
      ref: {:required, :string},
      role: {:required, {:coerce, {:enum, ~w(colony spectator)a}}},
      name: {:dependent, &with_role/1}
    }
  end

  defp with_role(%{role: "colony", name: "spectator"}),
    do: {:error, "bad_name", []}

  defp with_role(%{role: "colony"}) do
    {:ok, {:required, {:string, regex: ~r/^[a-z0-9-]{1,16}$/, error: "bad_name"}}}
  end

  defp with_role(%{role: "spectator"}), do: {:ok, nil}

  def parse(attrs) do
    with {:ok, attrs} <- Peri.validate(schema(), attrs) do
      struct(__MODULE__, attrs)
    end
  end
end
