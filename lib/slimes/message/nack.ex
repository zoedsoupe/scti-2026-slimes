defmodule Slimes.Message.Nack do
  @moduledoc """
  Rejeição de uma mensagem do cliente, com código e texto livre.

  Responde `HELLO` (nome inválido, reservado ou duplicado) e `ACT` (a ação não
  entrou na resolução). O formato é `NACK <ref> <código> <texto livre>`: o
  texto vai até o fim da linha e é o único lugar do protocolo, junto com
  `ERR`, onde espaços são permitidos:

      NACK aurora-k3f9-17 too_late tick 96 resolvido; acao enfileirada para 97

  O código vem da tabela fixa do protocolo. `duplicate_ref` é informacional:
  o `ACK` original é reenviado em seguida. `too_late` significa que a ação
  chegou após a resolução e foi enfileirada para o próximo tick, nunca
  descartada em silêncio.
  """

  @type code ::
          :bad_name
          | :bad_cell
          | :not_empty
          | :not_enemy
          | :not_self
          | :attacks_disabled
          | :duplicate_ref
          | :too_late

  @type t :: %__MODULE__{
          ref: String.t(),
          code: code,
          detail: String.t() | nil
        }

  defstruct [:ref, :code, :detail]

  @codes ~w(bad_name bad_cell not_empty not_enemy not_self attacks_disabled duplicate_ref too_late)a

  @schema %{
    ref: {:required, :string},
    code: {:required, {:enum, @codes}},
    detail: :string
  }

  def parse(attrs) do
    with {:ok, attrs} <- Peri.validate(@schema, attrs) do
      struct(__MODULE__, attrs)
    end
  end
end
