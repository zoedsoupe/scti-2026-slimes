defmodule Slimes.Message.Error do
  @moduledoc false

  @type t :: %__MODULE__{
          ref: String.t(),
          code:
            :bad_cell
            | :bad_message
            | :bad_name
            | :bad_version
            | :not_empty
            | :not_enemy
            | :not_self
            | :attacks_disabled
            | :duplicated_ref
            | :too_late,
          detail: String.t() | nil
        }

  defstruct [:ref, :code, :detail]

  @codes ~w(bad_cell bad_message bad_name bad_version not_empty not_enemy not_self attacks_disabled duplicated_ref too_late)a

  @schema %{
    ref: {:required, :string},
    code: {:required, {:coerce, {:enum, @codes}}},
    detail: :string
  }

  def parse(attrs) do
    with {:ok, attrs} <- Peri.validate(@schema, attrs) do
      struct(__MODULE__, attrs)
    end
  end
end
