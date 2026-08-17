defmodule Slimes.Message.Cell do
  @moduledoc """
  Célula da grade no formato completo do protocolo.

  Não é uma mensagem: é o item das listas de células do `WELCOME` de
  espectador (snapshot inteiro, uma vez) e do `OBS` de cada colônia (visão
  local, uma por tick). Na linha, serializa como `x,y,terreno,dono,fortificada`:

      11,5,forest,2,0

  O terreno é decorativo na v1 e não muda durante a partida. Dono `0` marca
  célula vazia. A fortificação é visível para qualquer colônia, então dá para
  ver um forte inimigo antes de atacar.
  """

  @type terrain :: :plain | :forest | :water | :rock

  @type t :: %__MODULE__{
          x: non_neg_integer,
          y: non_neg_integer,
          terrain: terrain,
          owner: non_neg_integer,
          fortified: 0 | 1
        }

  defstruct [:x, :y, :terrain, :owner, :fortified]

  @doc false
  def schema do
    %{
      x: {:required, {:integer, gte: 0}},
      y: {:required, {:integer, gte: 0}},
      terrain: {:required, {:enum, ~w(plain forest water rock)a}},
      owner: {:required, {:integer, gte: 0}},
      fortified: {:required, {:enum, [0, 1]}}
    }
  end

  def parse(attrs) do
    with {:ok, attrs} <- Peri.validate(schema(), attrs) do
      struct(__MODULE__, attrs)
    end
  end

  @doc """
  Serializa a célula para o formato de lista do protocolo.

      iex> Slimes.Message.Cell.encode(%Slimes.Message.Cell{x: 11, y: 5, terrain: :forest, owner: 2, fortified: 0})
      "11,5,forest,2,0"
  """
  @spec encode(t) :: String.t()
  def encode(%__MODULE__{} = cell) do
    Enum.join([cell.x, cell.y, cell.terrain, cell.owner, cell.fortified], ",")
  end
end
