defmodule Slimes.Message.Score do
  @moduledoc """
  Scoreboard do tick, broadcast para todos os clientes.

  Uma por tick, com nomes e contagens, sem posições:

      SCORE srv-97 97 3,aurora,21,alive;5,nova,14,dead

  Cada entrada é `id,nome,células,status`. O número do tick viaja aqui e no
  `OBS`: não existe mensagem de tick separada.
  """

  @type entry :: %{
          id: non_neg_integer,
          name: String.t(),
          cells: non_neg_integer,
          status: :alive | :dead
        }

  @type t :: %__MODULE__{
          ref: String.t(),
          tick: non_neg_integer,
          entries: [entry]
        }

  defstruct [:ref, :tick, entries: []]

  @entry_schema %{
    id: {:required, {:integer, gte: 0}},
    name: {:required, :string},
    cells: {:required, {:integer, gte: 0}},
    status: {:required, {:enum, ~w(alive dead)a}}
  }

  @schema %{
    ref: {:required, :string},
    tick: {:required, {:integer, gte: 0}},
    entries: {:required, {:list, @entry_schema}}
  }

  def parse(attrs) do
    with {:ok, attrs} <- Peri.validate(@schema, attrs) do
      struct(__MODULE__, attrs)
    end
  end
end
