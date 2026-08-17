defmodule Slimes.Message do
  @moduledoc """
  Fronteira do protocolo: linha de texto entra, struct de domínio sai.

  Uma mensagem por linha, um frame WebSocket por linha. `decode_message/1`
  tokeniza a linha, identifica o tipo e valida os campos com Peri;
  `encode_message/1` serializa as mensagens do servidor de volta para a
  linha.

  Regra de parse, vale para os dois lados: tokens extras no final são
  ignorados e linha malformada vai para o caminho de erro, nunca derruba o
  processo. O decodificador reporta *o que* está errado (código, campo e
  detalhe, uma entrada por campo inválido); quem decide o roteamento entre
  `ERR` e `NACK` é o chamador.

  Mensagens do cliente: `HELLO`, `ACT`, `PING`. Mensagens do servidor:
  `WELCOME`, `OBS`, `ACK`, `NACK`, `SCORE`, `DIFF`, `PONG`, `ERR`. O
  contrato completo está em `docs/PROTOCOL.md`.
  """

  alias Slimes.Message.Ack
  alias Slimes.Message.Act
  alias Slimes.Message.Cell
  alias Slimes.Message.Diff
  alias Slimes.Message.Error
  alias Slimes.Message.Hello
  alias Slimes.Message.Nack
  alias Slimes.Message.Obs
  alias Slimes.Message.Ping
  alias Slimes.Message.Pong
  alias Slimes.Message.Score
  alias Slimes.Message.Welcome

  alias Slimes.Result

  @type client :: Act.t() | Hello.t() | Ping.t()

  @type server ::
          Ack.t()
          | Diff.t()
          | Error.t()
          | Nack.t()
          | Obs.t()
          | Pong.t()
          | Score.t()
          | Welcome.t()

  @type t :: client() | server()

  ## ENCODING

  @spec encode_message(server) :: String.t()
  def encode_message(%Pong{ref: ref}), do: "PONG " <> ref

  def encode_message(%Ack{} = ack), do: Enum.join(["ACK", ack.ref, ack.tick], " ")

  def encode_message(%Nack{} = nack) do
    Enum.join(["NACK", nack.ref, nack.code, nack.detail], " ")
  end

  def encode_message(%Error{} = err) do
    Enum.join(["ERR", err.ref, err.code, err.detail], " ")
  end

  def encode_message(%Welcome{role: :colony} = welcome) do
    {spawn_x, spawn_y} = welcome.spawn

    Enum.join(
      [
        "WELCOME",
        welcome.ref,
        welcome.id,
        welcome.name,
        welcome.color,
        welcome.w,
        welcome.h,
        welcome.tick_ms,
        welcome.view_radius,
        "#{spawn_x},#{spawn_y}"
      ],
      " "
    )
  end

  def encode_message(%Welcome{role: :spectator} = welcome) do
    cells = Enum.map_join(welcome.cells, ";", &Cell.encode/1)

    Enum.join(["WELCOME", welcome.ref, "spectator", welcome.w, welcome.h, welcome.tick_ms, cells], " ")
  end

  def encode_message(%Obs{} = obs) do
    cells = Enum.map_join(obs.cells, ";", &Cell.encode/1)

    Enum.join(["OBS", obs.ref, obs.tick, obs.status, obs.scores_tick, cells], " ")
  end

  def encode_message(%Score{} = score) do
    entries =
      Enum.map_join(score.entries, ";", fn entry ->
        Enum.join([entry.id, entry.name, entry.cells, entry.status], ",")
      end)

    Enum.join(["SCORE", score.ref, score.tick, entries], " ")
  end

  def encode_message(%Diff{} = diff) do
    changes =
      Enum.map_join(diff.changes, ";", fn change ->
        Enum.join([change.x, change.y, change.owner, change.fortified], ",")
      end)

    Enum.join(["DIFF", diff.ref, diff.tick, changes], " ")
  end

  ## DECODING

  @spec decode_message(binary) :: {:ok, t} | {:error, [decode_error]}
        when decode_error: %{code: atom, key: atom | nil, detail: String.t() | nil}
  def decode_message(str) do
    msg = tokenize(str)

    with {:ok, msg} <- decode(msg) do
      parse(msg)
    end
    |> Result.ok()
    |> Result.map_error(&humanize_error/1)
  end

  defp parse({:act, attrs}), do: Act.parse(attrs)
  defp parse({:hello, attrs}), do: Hello.parse(attrs)
  defp parse({:ping, attrs}), do: Ping.parse(attrs)

  # The decoder reports WHAT is wrong (code + key + human detail, one entry
  # per failing key). ERR-vs-NACK routing, ref policy and detail joining are
  # decided by the caller.
  defp humanize_error(%Peri.Error{} = err), do: [error_to_map(err)]

  defp humanize_error([%Peri.Error{} | _] = errors), do: Enum.map(errors, &error_to_map/1)

  defp humanize_error(:bad_version),
    do: [%{code: :bad_version, key: :version, detail: "unsupported protocol version"}]

  defp humanize_error(:bad_name), do: [%{code: :bad_name, key: :name, detail: "reserved name"}]

  defp humanize_error(:bad_message),
    do: [%{code: :bad_message, key: nil, detail: "malformed line"}]

  defp error_to_map(%Peri.Error{message: msg, key: key}) do
    %{code: code_for(key, msg), key: key, detail: msg}
  end

  defp code_for(:name, _msg), do: :bad_name

  defp code_for(_key, msg) when is_binary(msg) do
    if msg =~ "greater", do: :bad_cell, else: :bad_message
  end

  defp tokenize(str) do
    str
    |> String.trim()
    |> String.split("\s", trim: true)
  end

  defguardp is_kind(k) when k in ~w(expand attack fortify)

  defp decode(["HELLO", v | _]) when v != "v1" do
    {:error, :bad_version}
  end

  defp decode(["HELLO", v, ref, "colony", name | _]) do
    {:ok, {:hello, %{version: v, name: name, ref: ref, role: "colony"}}}
  end

  defp decode(["HELLO", v, ref, "spectator" | _]) do
    {:ok, {:hello, %{version: v, ref: ref, role: "spectator"}}}
  end

  defp decode(["ACT", ref, "pass" = k | _]) do
    {:ok, {:act, %{ref: ref, kind: k}}}
  end

  defp decode(["ACT", ref, kind, x, y | _]) when is_kind(kind) do
    {:ok, {:act, %{ref: ref, kind: kind, x: x, y: y}}}
  end

  defp decode(["PING", ref | _]) do
    {:ok, {:ping, %{ref: ref}}}
  end

  defp decode(_), do: {:error, :bad_message}
end
