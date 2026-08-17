defmodule Slimes.Message.Welcome do
  @moduledoc """
  Resposta ao `HELLO`, no formato do papel pedido.

  Para colônia, traz a identidade e as regras da partida:

      WELCOME srv-0 3 aurora 96CDFB 60 40 1000 3 4,34

  | campo       | significado                |
  | ----------- | -------------------------- |
  | colony id   | identificador numérico     |
  | nome        | eco do `HELLO`             |
  | cor         | hex sem `#`                |
  | w h         | dimensões da grade         |
  | tick_ms     | duração do tick            |
  | view_radius | raio de visão              |
  | spawn       | `x,y` da célula inicial    |

  Para espectador, traz o snapshot completo da grade, uma única vez:

      WELCOME srv-0 spectator 60 40 1000 0,0,plain,0,0;1,0,plain,0,0;...

  O terreno não muda durante a partida, então esta é a única mensagem que o
  envia por inteiro. Depois disso o espectador recebe só `DIFF`.
  """

  alias Slimes.Message.Cell

  @type t :: %__MODULE__{
          ref: String.t(),
          role: :colony | :spectator,
          id: non_neg_integer | nil,
          name: String.t() | nil,
          color: String.t() | nil,
          w: pos_integer,
          h: pos_integer,
          tick_ms: pos_integer,
          view_radius: non_neg_integer | nil,
          spawn: {non_neg_integer, non_neg_integer} | nil,
          cells: [Cell.t()] | nil
        }

  defstruct [
    :ref,
    :role,
    :id,
    :name,
    :color,
    :w,
    :h,
    :tick_ms,
    :view_radius,
    :spawn,
    :cells
  ]

  defp schema do
    %{
      ref: {:required, :string},
      role: {:required, {:enum, ~w(colony spectator)a}},
      w: {:required, {:integer, gt: 0}},
      h: {:required, {:integer, gt: 0}},
      tick_ms: {:required, {:integer, gt: 0}},
      id: {:dependent, &colony_only(&1, {:integer, gte: 0})},
      name: {:dependent, &colony_only(&1, :string)},
      color: {:dependent, &colony_only(&1, {:string, regex: ~r/^[0-9A-Fa-f]{6}$/})},
      view_radius: {:dependent, &colony_only(&1, {:integer, gte: 0})},
      spawn: {:dependent, &colony_only(&1, {:tuple, [{:integer, gte: 0}, {:integer, gte: 0}]})},
      cells: {:dependent, &spectator_only(&1, {:list, Cell.schema()})}
    }
  end

  defp colony_only(%{role: role}, type) when role in ["colony", :colony],
    do: {:ok, {:required, type}}

  defp colony_only(_, _), do: {:ok, nil}

  defp spectator_only(%{role: role}, type) when role in ["spectator", :spectator],
    do: {:ok, {:required, type}}

  defp spectator_only(_, _), do: {:ok, nil}

  def parse(attrs) do
    with {:ok, attrs} <- Peri.validate(schema(), attrs) do
      attrs = Map.update(attrs, :cells, nil, &Enum.map(&1, fn c -> struct(Cell, c) end))
      struct(__MODULE__, attrs)
    end
  end
end
