defmodule Slimes.Message do
  @moduledoc false

  alias Slimes.Message.Act
  alias Slimes.Message.Error
  alias Slimes.Message.Hello
  alias Slimes.Message.Ping
  alias Slimes.Message.Pong

  alias Slimes.Result

  @type client :: Act.t() | Hello.t() | Ping.t()
  @type server :: Error.t() | Pong.t()

  @type t :: client() | server()

  ## ENCODING

  @spec encode_message(server) :: String.t()
  def encode_message(%Pong{ref: ref}), do: "PONG " <> ref

  def encode_message(%Error{} = err) do
    Enum.join(["ERR", err.ref, err.code, err.detail])
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
