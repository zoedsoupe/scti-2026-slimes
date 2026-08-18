defmodule SlimesWeb.SocketHandler do
  @moduledoc """
  Um processo por socket. Dono da conexão: faz o parse de cada linha para
  um tipo de domínio na fronteira e conversa com o `Slimes.World` só em
  structs. O World nunca vê uma linha crua nem um socket.

  Máquina de estados por socket: `awaiting_hello -> joined`. `HELLO` só
  vale como primeira mensagem, uma única vez. Linha malformada responde
  `ERR` com o melhor ref possível e nunca derruba o processo.

  Mensagens do World chegam por `handle_info` como tuplas de domínio e
  saem como um frame por linha.
  """

  @behaviour WebSock

  alias Slimes.Message
  alias Slimes.Message.{Act, Cell, Error, Hello, Nack, Ping, Pong}
  alias Slimes.Message.{Ack, Diff, Obs, Score, Welcome}
  alias Slimes.World

  defstruct [:world, :role, :colony_id, status: :awaiting_hello]

  @impl true
  def init(opts) do
    {:ok, %__MODULE__{world: Keyword.get(opts, :world, Slimes.World)}}
  end

  @impl true
  def handle_in({line, [opcode: :text]}, state) do
    case Message.decode_message(line) do
      {:ok, msg} -> dispatch(msg, state)
      {:error, errors} -> {:push, error_frames(errors, line), state}
    end
  end

  ## HELLO

  defp dispatch(%Hello{} = hello, %{status: :awaiting_hello} = state) do
    case hello.role do
      :colony -> join_colony(hello, state)
      :spectator -> join_spectator(state)
    end
  end

  defp dispatch(%Hello{ref: ref}, state) do
    {:push, [error_frame(ref, :bad_message, "hello ja enviado")], state}
  end

  ## ACT

  defp dispatch(%Act{} = act, %{status: :joined, role: :colony, colony_id: id} = state) do
    case World.act(state.world, id, act) do
      {:ok, tick} ->
        {:push, [text_frame(%Ack{ref: act.ref, tick: tick})], state}

      {:duplicate, {:ok, tick}} ->
        # informativo: o ack original é reenviado em seguida, sem reaplicar
        frames = [
          text_frame(%Nack{ref: act.ref, code: :duplicate_ref, detail: "ref ja processado"}),
          text_frame(%Ack{ref: act.ref, tick: tick})
        ]

        {:push, frames, state}

      {:error, errors} ->
        {:push, nack_frames(act.ref, errors), state}
    end
  end

  defp dispatch(%Act{ref: ref}, state) do
    {:push, [error_frame(ref, :bad_message, "acao fora de uma colonia")], state}
  end

  ## PING

  defp dispatch(%Ping{ref: ref}, %{status: :joined} = state) do
    {:push, [text_frame(%Pong{ref: ref})], state}
  end

  defp dispatch(%Ping{ref: ref}, state) do
    {:push, [error_frame(ref, :bad_message, "ping antes do hello")], state}
  end

  ## Entradas

  defp join_colony(%Hello{} = hello, state) do
    case World.join(state.world, hello.name, self()) do
      {:ok, info} ->
        welcome = %Welcome{
          ref: "srv-0",
          role: :colony,
          id: info.id,
          name: info.name,
          color: info.color,
          w: info.width,
          h: info.height,
          tick_ms: info.tick_ms,
          view_radius: info.view_radius,
          spawn: info.spawn
        }

        state = %{state | status: :joined, role: :colony, colony_id: info.id}
        {:push, [text_frame(welcome)], state}

      {:error, errors} ->
        {:push, nack_frames(hello.ref, errors), state}
    end
  end

  defp join_spectator(state) do
    {:ok, snapshot} = World.watch(state.world, self())

    welcome = %Welcome{
      ref: "srv-0",
      role: :spectator,
      w: snapshot.width,
      h: snapshot.height,
      tick_ms: snapshot.tick_ms,
      cells: Enum.map(snapshot.cells, &cell_struct/1)
    }

    {:push, [text_frame(welcome)], %{state | status: :joined, role: :spectator}}
  end

  ## Mensagens do World

  @impl true
  def handle_info({:obs, tick, status, scores_tick, cells}, state) do
    obs = %Obs{
      ref: "srv-#{tick}",
      tick: tick,
      status: status,
      scores_tick: scores_tick,
      cells: Enum.map(cells, &cell_struct/1)
    }

    {:push, [text_frame(obs)], state}
  end

  def handle_info({:score, tick, entries}, state) do
    score = %Score{
      ref: "srv-#{tick}",
      tick: tick,
      entries: Enum.map(entries, fn {id, name, cells, status} ->
        %{id: id, name: name, cells: cells, status: status}
      end)
    }

    {:push, [text_frame(score)], state}
  end

  def handle_info({:diff, tick, changes}, state) do
    diff = %Diff{
      ref: "srv-#{tick}",
      tick: tick,
      changes: Enum.map(changes, fn {x, y, owner, fortified} ->
        %{x: x, y: y, owner: owner, fortified: fortified}
      end)
    }

    {:push, [text_frame(diff)], state}
  end

  def handle_info(_msg, state), do: {:ok, state}

  ## Frames de erro

  # o decoder reporta o que está errado; aqui decidimos o roteamento:
  # falha de forma vira ERR, rejeição de domínio vira NACK
  @err_codes [:bad_version, :bad_message]

  defp nack_frames(ref, errors) do
    Enum.map(errors, fn %{code: code, detail: detail} ->
      text_frame(%Nack{ref: ref, code: code, detail: detail})
    end)
  end

  defp error_frames(errors, line) do
    ref = best_effort_ref(line)

    Enum.map(errors, fn %{code: code, detail: detail} ->
      if code in @err_codes do
        error_frame(ref, code, detail)
      else
        text_frame(%Nack{ref: ref, code: code, detail: detail})
      end
    end)
  end

  defp error_frame(ref, code, detail) do
    text_frame(%Error{ref: ref, code: code, detail: detail})
  end

  # melhor ref possível para uma linha que não deu parse: o token de ref da
  # mensagem (terceiro no HELLO, segundo nas demais), ou um placeholder
  # quando a linha é lixo desde o começo
  defp best_effort_ref(line) do
    case String.split(line, " ", trim: true) do
      ["HELLO", _version, ref | _] -> ref
      [_type, ref | _] -> ref
      _ -> "unknown"
    end
  end

  defp cell_struct({x, y, terrain, owner, fortified}) do
    %Cell{x: x, y: y, terrain: terrain, owner: owner, fortified: fortified}
  end

  defp text_frame(msg), do: {:text, Message.encode_message(msg)}
end
