defmodule Slimes.Message.Diff do
  @moduledoc """
  Mudanças do tick, só para espectadores.

  O espectador recebe o snapshot inteiro no `WELCOME` e depois só as
  mudanças, uma mensagem por tick:

      DIFF srv-97 97 12,7,3,0;12,8,0,0

  Cada mudança é `x,y,dono,fortificada`: sem terreno, porque o terreno não
  muda durante a partida. Dono `0` marca célula que voltou a ficar vazia.
  """

  @type change :: %{
          x: non_neg_integer,
          y: non_neg_integer,
          owner: non_neg_integer,
          fortified: 0 | 1
        }

  @type t :: %__MODULE__{
          ref: String.t(),
          tick: non_neg_integer,
          changes: [change]
        }

  defstruct [:ref, :tick, changes: []]

  @change_schema %{
    x: {:required, {:integer, gte: 0}},
    y: {:required, {:integer, gte: 0}},
    owner: {:required, {:integer, gte: 0}},
    fortified: {:required, {:enum, [0, 1]}}
  }

  @schema %{
    ref: {:required, :string},
    tick: {:required, {:integer, gte: 0}},
    changes: {:required, {:list, @change_schema}}
  }

  def parse(attrs) do
    with {:ok, attrs} <- Peri.validate(@schema, attrs) do
      struct(__MODULE__, attrs)
    end
  end
end
