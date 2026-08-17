defmodule Slimes.Message.Obs do
  @moduledoc """
  Observação do tick para uma colônia, visão local apenas.

  Uma por tick, por colônia. Não existe mensagem de tick separada: o número
  viaja aqui e no `SCORE`:

      OBS srv-97 97 alive 97 9,5,plain,0,0;10,5,plain,3,1;11,5,forest,2,0

  | campo       | significado                                                              |
  | ----------- | ------------------------------------------------------------------------ |
  | tick        | o tick que esta observação descreve                                      |
  | status      | `alive` ou `dead`; após a eliminação o socket continua aberto            |
  | scores_tick | tick do último scoreboard; permite notar um scoreboard perdido           |
  | células     | união das vizinhanças 7x7 ao redor de cada célula da colônia             |

  Cada célula segue o formato completo de `Slimes.Message.Cell`.
  """

  alias Slimes.Message.Cell

  @type t :: %__MODULE__{
          ref: String.t(),
          tick: non_neg_integer,
          status: :alive | :dead,
          scores_tick: non_neg_integer,
          cells: [Cell.t()]
        }

  defstruct [:ref, :tick, :status, :scores_tick, cells: []]

  @schema %{
    ref: {:required, :string},
    tick: {:required, {:integer, gte: 0}},
    status: {:required, {:enum, ~w(alive dead)a}},
    scores_tick: {:required, {:integer, gte: 0}},
    cells: {:required, {:list, Cell.schema()}}
  }

  def parse(attrs) do
    with {:ok, attrs} <- Peri.validate(@schema, attrs) do
      attrs = Map.update!(attrs, :cells, &Enum.map(&1, fn c -> struct(Cell, c) end))
      struct(__MODULE__, attrs)
    end
  end
end
