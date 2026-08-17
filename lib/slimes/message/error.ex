defmodule Slimes.Message.Error do
  @moduledoc """
  Falha de protocolo, fora do fluxo normal de jogo.

  Diferente do `NACK`, que rejeita uma mensagem válida por regra de jogo,
  `ERR` reporta problema de forma: linha malformada, tipo desconhecido,
  número inválido ou versão errada. O formato é `ERR <ref> <código> <texto
  livre>`, com o texto indo até o fim da linha:

      ERR aurora-k3f9-31 bad_message tipo desconhecido ACTN

  Os códigos de `ERR` são `bad_version` e `bad_message`. Os demais códigos
  da tabela fixa viajam em `NACK`.
  """

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
            | :duplicate_ref
            | :too_late,
          detail: String.t() | nil
        }

  defstruct [:ref, :code, :detail]

  @codes ~w(bad_cell bad_message bad_name bad_version not_empty not_enemy not_self attacks_disabled duplicate_ref too_late)a

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
