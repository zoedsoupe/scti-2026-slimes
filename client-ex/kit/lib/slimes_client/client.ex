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

    # WebSockex não aceita reply em handle_connect: manda para si mesmo
    # e responde no handle_info
    send(self(), {:hello, ref})
    {:ok, state}
  end

  @impl true
  def handle_info({:hello, ref}, %{name: name} = state) do
    {:reply, {:text, Protocol.encode_hello(ref, "colony", name)}, state}
  end

  @impl true
  def handle_cast({:text, _line} = frame, state), do: {:reply, frame, state}

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
    # {:reconnect, state} reabre o socket; handle_connect manda um HELLO
    # novo com segmento de sessão novo, então os refs nunca colidem
    IO.puts("desconectado: #{inspect(reason)}, reconectando")
    {:reconnect, state}
  end

  defp dispatch(%{type: "welcome", role: "colony"} = msg, state) do
    IO.puts("entrei como #{msg.name} (id #{msg.id}), cor ##{msg.color}")
    {:ok, %{state | my_id: msg.id}}
  end

  # welcome de espectador não tem name/id/color: só registra e segue
  defp dispatch(%{type: "welcome"}, state) do
    IO.puts("welcome de espectador, ignorado")
    {:ok, state}
  end

  defp dispatch(%{type: "obs"} = msg, state) do
    # Map.get em vez de msg.tick/msg.status: enquanto o E1 é stub o tipo
    # inferido de msg não tem as chaves da observação e o acesso direto
    # vira warning de tipo na compilação
    tick = Map.get(msg, :tick)
    {pending, effects} = Pending.on_timeout(state.pending, tick)

    # WebSockex não devolve lista de frames no reply: cada retry vai por
    # cast (cai no handle_cast acima) e a ação do tick volta como reply
    for %{line: line} <- effects, do: WebSockex.cast(self(), {:text, line})
    for %{drop: ref} <- effects, do: IO.puts("drop #{ref}: sem ACK depois dos retries")

    if Map.get(msg, :status) == "alive" and state.my_id do
      action = Decide.decide(msg, state.my_id)
      {ref, refs} = Protocol.next_ref(state.refs)
      line = Protocol.encode_action(action, ref)

      state = %{
        state
        | refs: refs,
          pending: Pending.add_pending(pending, ref, line, tick)
      }

      {:reply, {:text, line}, state}
    else
      {:ok, %{state | pending: pending}}
    end
  end

  defp dispatch(%{type: "ack"} = msg, state),
    do: {:ok, %{state | pending: Pending.on_ack(state.pending, msg.ref)}}

  defp dispatch(%{type: "nack", code: "duplicate_ref"}, state) do
    # informacional: o ACK original chega em seguida, mantém o pendente
    {:ok, state}
  end

  defp dispatch(%{type: "nack"} = msg, state) do
    IO.puts("NACK #{msg.code}: #{msg.detail}")
    {:ok, %{state | pending: Pending.on_ack(state.pending, msg.ref)}}
  end

  defp dispatch(%{type: "err"} = msg, state) do
    IO.puts("ERR #{msg.code}: #{msg.detail}")
    {:ok, state}
  end

  defp dispatch(_msg, state), do: {:ok, state}
end
