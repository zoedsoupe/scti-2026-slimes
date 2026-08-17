defmodule Slimes.Message.Hello do
  @moduledoc """
  Entrada no jogo. Primeira mensagem do socket, enviada uma vez.

      HELLO v1 aurora-k3f9-1 colony aurora
      HELLO v1 proj-a1b2-1 spectator

  É a única mensagem que carrega a versão do protocolo: o servidor assume v1
  nas demais e responde versão errada com `ERR bad_version`. O nome só
  existe para colônia; `"spectator"` é nome reservado e nome inválido ou
  duplicado leva `NACK bad_name`.

  Reconexão: nome de colônia viva retoma a colônia, com mesmo id e estado
  intacto. Nome de colônia eliminada é entrada nova. Respondida por
  `WELCOME` ou `NACK`.
  """

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
