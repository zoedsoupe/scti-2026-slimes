defmodule SlimesClient.Client do
  @moduledoc """
  Loop do cliente: conecta, cumprimenta, e a cada OBS decide e age.

  Uso:

      mix deps.get
      SLIMES_URL=ws://localhost:4000/ws SLIMES_NAME=aurora mix run --no-halt -e SlimesClient.Client.main
  """

  # use WebSockex: API oficial da lib (injeta child_spec e defaults);
  # os callbacks handle_connect/handle_frame/handle_disconnect são a borda.
  use WebSockex

  alias SlimesClient.{Decide, Pending, Protocol}

  def main do
    url = System.get_env("SLIMES_URL") || "ws://localhost:4000/ws"
    name = System.get_env("SLIMES_NAME") || "exslime"

    {:ok, _pid} = WebSockex.start_link(url, __MODULE__, %{name: name})
    Process.sleep(:infinity)
  end

  @impl true
  def handle_connect(_conn, %{name: name} = state) do
    {ref, refs} = Protocol.next_ref(Protocol.refs(name))

    state =
      state
      |> Map.put(:refs, refs)
      |> Map.put(:my_id, nil)
      |> Map.put(:pending, %{})

    {:reply, {:text, Protocol.encode_hello(ref, "colony", name)}, state}
  end

  @impl true
  def handle_frame({:text, line}, state) do
    case Protocol.parse_line(line) do
      {:error, reason} ->
        IO.puts("linha malformada: #{reason}")
        {:ok, state}

      {:ok, msg} ->
        dispatch(msg, state)
    end
  end

  @impl true
  def handle_disconnect(%{reason: reason}, state) do
    IO.puts("desconectado: #{inspect(reason)}")
    {:ok, state}
  end

  defp dispatch(%{type: "welcome"} = msg, state) do
    IO.puts("entrei como #{msg.name} (id #{msg.id}), cor ##{msg.color}")
    {:ok, %{state | my_id: msg.id}}
  end

  defp dispatch(%{type: "obs"} = msg, state) do
    {pending, effects} = Pending.on_timeout(state.pending, msg.tick)
    frames = for %{line: line} <- effects, do: {:text, line}

    {frames, pending, state} =
      if msg.status == "alive" and state.my_id do
        action = Decide.decide(msg, state.my_id)
        {ref, refs} = Protocol.next_ref(state.refs)
        line = Protocol.encode_action(action, ref)
        state = %{state | refs: refs}

        {frames ++ [{:text, line}], Pending.add_pending(pending, ref, line, msg.tick),
         state}
      else
        {frames, pending, state}
      end

    state = %{state | pending: pending}
    if frames == [], do: {:ok, state}, else: {:reply, frames, state}
  end

  defp dispatch(%{type: "ack"} = msg, state),
    do: {:ok, %{state | pending: Pending.on_ack(state.pending, msg.ref)}}

  defp dispatch(%{type: "nack"} = msg, state) do
    IO.puts("NACK #{msg.code}: #{msg.detail}")
    {:ok, state}
  end

  defp dispatch(%{type: "err"} = msg, state) do
    IO.puts("ERR #{msg.code}: #{msg.detail}")
    {:ok, state}
  end

  defp dispatch(_msg, state), do: {:ok, state}
end
