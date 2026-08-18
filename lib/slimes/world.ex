defmodule Slimes.World do
  @moduledoc """
  GenServer dono do estado do mundo: grade, colônias, espectadores,
  fila de ações do tick, tabela de deduplicação e log de eventos.

  Todo efeito do jogo mora aqui (a borda imperativa): timers, mensagens
  para os handlers dos sockets e broadcasts. A resolução do tick é
  delegada ao núcleo puro `Slimes.World.Resolve`.

  Fluxo por tick:

    1. coleta a fila de ações (no máximo uma por colônia, a última vence)
    2. semeia o rng com `{base_seed, tick, 0}` e chama `Resolve.resolve/3`
    3. anexa os eventos ao log
    4. transmite OBS (colônias), SCORE (todos) e DIFF (espectadores)
  """

  use GenServer

  require Logger

  alias Slimes.Message.Act
  alias Slimes.World.Resolve

  @palette ~w(F5C2E7 96CDFB 8BD5CA ABE9B3 F8BD96 F28FAD)
  @view_radius 3
  @empty %{terrain: :plain, owner: 0, fortified: 0}
  @name_regex ~r/^[a-z0-9-]{1,16}$/

  defstruct base_seed: 0,
            width: 60,
            height: 40,
            tick_ms: 1000,
            mode: :tournament,
            tick: 0,
            accepting: true,
            cells: %{},
            colonies: %{},
            next_id: 1,
            spectators: [],
            queue: %{},
            dedup: %{},
            event_log: [],
            scores_tick: 0,
            fixed_spawns: %{}

  ## API pública

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Entrada de colônia. Retorna os dados do WELCOME ou {:error, :bad_name}."
  def join(world, name, handler_pid) do
    GenServer.call(world, {:join, name, handler_pid})
  end

  @doc "Entrada de espectador. Retorna o snapshot completo da grade."
  def watch(world, spectator_pid) do
    GenServer.call(world, {:watch, spectator_pid})
  end

  @doc "Registra a ação da colônia no tick corrente."
  def act(world, colony_id, %Act{} = action) do
    GenServer.call(world, {:act, colony_id, action})
  end

  def event_log(world) do
    GenServer.call(world, :event_log)
  end

  ## Callbacks

  @impl true
  def init(opts) do
    state = %__MODULE__{
      base_seed: Keyword.get(opts, :base_seed, 0),
      width: Keyword.get(opts, :width, 60),
      height: Keyword.get(opts, :height, 40),
      tick_ms: Keyword.get(opts, :tick_ms, 1000),
      mode: Keyword.get(opts, :mode, :tournament),
      fixed_spawns: Keyword.get(opts, :spawns, %{}),
      cells: initial_cells(Keyword.get(opts, :terrain, []))
    }

    schedule_tick(state.tick_ms)
    {:ok, state}
  end

  @impl true
  def handle_call({:join, name, pid}, _from, state) do
    cond do
      name == "spectator" ->
        {:reply, err(:bad_name, :name, "nome reservado"), state}

      not Regex.match?(@name_regex, name) ->
        {:reply, err(:bad_name, :name, "nome invalido"), state}

      colony = find_colony_by_name(state, name) ->
        if colony.status == :alive do
          # reconexão: retoma a colônia e aponta o handler para o novo socket
          Logger.info("colonia #{colony.id} (#{name}) reconectou")
          colony = %{colony | handler: pid}
          state = put_in(state.colonies[colony.id], colony)
          {:reply, {:ok, welcome_info(state, colony)}, state}
        else
          # nome de colônia eliminada: entrada nova
          {state, colony} = fresh_join(state, name, pid)
          {:reply, {:ok, welcome_info(state, colony)}, state}
        end

      true ->
        {state, colony} = fresh_join(state, name, pid)
        {:reply, {:ok, welcome_info(state, colony)}, state}
    end
  end

  def handle_call({:watch, pid}, _from, state) do
    Logger.info("espectador conectado (#{length(state.spectators) + 1} no total)")

    snapshot = %{
      width: state.width,
      height: state.height,
      tick_ms: state.tick_ms,
      cells: full_grid(state)
    }

    {:reply, {:ok, snapshot}, %{state | spectators: [pid | state.spectators]}}
  end

  def handle_call({:act, colony_id, %Act{} = action}, _from, state) do
    key = {colony_id, action.ref}

    if recorded = state.dedup[key] do
      # ref repetido: não reaplica, devolve o ack original gravado
      {:reply, {:duplicate, recorded}, state}
    else
      case validate(state, colony_id, action) do
        :ok ->
          state = put_in(state.queue[colony_id], queued_action(colony_id, action))

          if state.accepting do
            ack = {:ok, state.tick}
            state = put_in(state.dedup[key], ack)
            {:reply, ack, state}
          else
            # chegou após a resolução: enfileirada para o próximo tick
            {:reply, err(:too_late, "tick #{state.tick} resolvido; acao enfileirada para #{state.tick + 1}"),
             state}
          end

        {:error, _} = error ->
          {:reply, error, state}
      end
    end
  end

  def handle_call(:event_log, _from, state) do
    {:reply, state.event_log, state}
  end

  @impl true
  def handle_info(:tick, state) do
    state = %{state | accepting: false}

    next = state.tick + 1
    rng = :rand.seed(:exsss, {state.base_seed, next, 0})

    actions =
      state.queue
      |> Enum.filter(fn {id, _} -> state.colonies[id].status == :alive end)
      |> Enum.map(fn {_id, action} -> action end)

    resolver_state = %{
      width: state.width,
      height: state.height,
      tick: next,
      cells: state.cells,
      colonies: state.colonies
    }

    {new_state, events} = Resolve.resolve(resolver_state, actions, rng)

    Logger.debug(
      "tick #{next} resolvido: #{length(actions)} acoes, #{length(events)} eventos"
    )

    for {:eliminated, id} <- events do
      Logger.info("colonia #{id} (#{new_state.colonies[id].name}) eliminada no tick #{next}")
    end

    state = %{
      state
      | tick: next,
        cells: new_state.cells,
        colonies: new_state.colonies,
        queue: %{},
        event_log: state.event_log ++ events,
        scores_tick: next
    }

    broadcast(state, events)
    schedule_tick(state.tick_ms)

    {:noreply, %{state | accepting: true}}
  end

  ## Entrada de colônias

  defp fresh_join(state, name, pid) do
    id = state.next_id

    # spawn fixo (pré-computado) vale uma única vez por nome; depois disso
    # o spawn é calculado pela regra normal
    {fixed, state} = get_and_update_in(state.fixed_spawns, &Map.pop(&1, name))
    spawn = fixed || spawn_cell(state)

    Logger.info("colonia #{id} (#{name}) entrou em #{inspect(spawn)}")

    colony = %{
      id: id,
      name: name,
      color: color(id),
      status: :alive,
      oldest: spawn,
      handler: pid
    }

    cell = %{cell_at(state, spawn) | owner: id, fortified: 0}

    state = %{
      state
      | colonies: Map.put(state.colonies, id, colony),
        cells: Map.put(state.cells, spawn, cell),
        next_id: id + 1
    }

    {state, colony}
  end

  defp welcome_info(state, colony) do
    %{
      id: colony.id,
      name: colony.name,
      color: colony.color,
      width: state.width,
      height: state.height,
      tick_ms: state.tick_ms,
      view_radius: @view_radius,
      spawn: colony.oldest
    }
  end

  defp find_colony_by_name(state, name) do
    Enum.find_value(state.colonies, fn {_id, colony} ->
      if colony.name == name, do: colony
    end)
  end

  # cores são função pura da ordem de entrada, para que espectadores
  # derivem a mesma paleta a partir dos ids
  defp color(id) when id <= 6, do: Enum.at(@palette, id - 1)

  defp color(id) do
    base = Enum.at(@palette, rem(id - 1, 6))
    cycle = div(id - 1, 6)
    factor = if rem(cycle, 2) == 1, do: 1.25, else: 0.75
    shade(base, factor)
  end

  defp shade(hex, factor) do
    <<r, g, b>> = Base.decode16!(hex)

    [r, g, b]
    |> Enum.map(fn c -> c |> Kernel.*(factor) |> round() |> min(255) end)
    |> Enum.map_join(fn c -> Integer.to_string(c, 16) |> String.pad_leading(2, "0") end)
  end

  # cantos primeiro, maximizando a distância para as colônias existentes;
  # empates resolvidos pelo rng semeado com {base_seed, ordem de entrada}
  defp spawn_cell(state) do
    taken = for {pos, %{owner: o}} <- state.cells, o != 0, do: pos

    corners = [
      {0, 0},
      {state.width - 1, 0},
      {0, state.height - 1},
      {state.width - 1, state.height - 1}
    ]

    free_corners = corners -- taken

    candidates =
      if free_corners == [] do
        for x <- 0..(state.width - 1), y <- 0..(state.height - 1), {x, y} not in taken, do: {x, y}
      else
        free_corners
      end

    rng = :rand.seed(:exsss, {state.base_seed, state.next_id, 1})

    {scored, _rng} =
      Enum.map_reduce(candidates, rng, fn pos, rng ->
        {tiebreak, rng} = :rand.uniform_s(rng)
        {{pos, -min_distance(pos, taken), tiebreak}, rng}
      end)

    scored
    |> Enum.sort_by(fn {_pos, dist, tiebreak} -> {dist, tiebreak} end)
    |> hd()
    |> elem(0)
  end

  defp min_distance(_pos, []), do: 0

  defp min_distance({x, y}, taken) do
    taken
    |> Enum.map(fn {tx, ty} -> abs(x - tx) + abs(y - ty) end)
    |> Enum.min()
  end

  ## Validação de ações, na ordem do spec

  # erros seguem o formato do decoder em Slimes.Message:
  # %{code, key, detail}, um por falha, para o chamador decidir o roteamento
  defp err(code, key \\ nil, detail), do: {:error, [%{code: code, key: key, detail: detail}]}

  defp validate(state, colony_id, %Act{kind: :pass}) do
    if state.colonies[colony_id], do: :ok, else: err(:bad_message, "colonia desconhecida")
  end

  defp validate(state, colony_id, %Act{} = action) do
    colony = state.colonies[colony_id]
    {x, y} = {action.x, action.y}

    cond do
      is_nil(colony) ->
        err(:bad_message, "colonia desconhecida")

      # modo antes de validade de célula: resposta consistente no cooperativo
      action.kind == :attack and state.mode == :cooperative ->
        err(:attacks_disabled, "ataques desabilitados no modo cooperativo")

      x < 0 or y < 0 or x >= state.width or y >= state.height ->
        err(:bad_cell, "fora da grade")

      not reachable?(state, colony_id, x, y) ->
        err(:bad_cell, "celula nao adjacente a colonia")

      true ->
        validate_ownership(state, colony_id, action, x, y)
    end
  end

  defp validate_ownership(state, _colony_id, %{kind: :expand}, x, y) do
    if cell_at(state, x, y).owner == 0, do: :ok, else: err(:not_empty, "celula ocupada")
  end

  defp validate_ownership(state, colony_id, %{kind: :attack}, x, y) do
    owner = cell_at(state, x, y).owner

    if owner != 0 and owner != colony_id, do: :ok, else: err(:not_enemy, "celula nao e inimiga")
  end

  defp validate_ownership(state, colony_id, %{kind: :fortify}, x, y) do
    if cell_at(state, x, y).owner == colony_id,
      do: :ok,
      else: err(:not_self, "celula nao pertence a colonia")
  end

  # célula alcançável: da própria colônia ou adjacente a uma célula dela
  defp reachable?(state, colony_id, x, y) do
    Enum.any?(state.cells, fn
      {{cx, cy}, %{owner: ^colony_id}} ->
        {cx, cy} == {x, y} or (abs(cx - x) + abs(cy - y)) == 1

      _ ->
        false
    end)
  end

  defp queued_action(colony_id, %Act{} = action) do
    cell = if action.kind == :pass, do: nil, else: {action.x, action.y}
    %{colony: colony_id, kind: action.kind, cell: cell}
  end

  ## Broadcasts

  defp broadcast(state, events) do
    diff = for {:cell, x, y, owner, fort} <- events, do: {x, y, owner, fort}

    for pid <- state.spectators do
      send(pid, {:diff, state.tick, diff})
    end

    entries =
      state.colonies
      |> Enum.sort_by(fn {id, _} -> id end)
      |> Enum.map(fn {id, colony} -> {id, colony.name, cell_count(state, id), colony.status} end)

    recipients = state.spectators ++ Enum.map(state.colonies, fn {_id, c} -> c.handler end)

    for pid <- recipients do
      send(pid, {:score, state.tick, entries})
    end

    for {_id, colony} <- state.colonies do
      cells =
        if colony.status == :alive do
          observable_cells(state, colony.id)
        else
          []
        end

      send(colony.handler, {:obs, state.tick, colony.status, state.scores_tick, cells})
    end
  end

  defp cell_count(state, id) do
    Enum.count(state.cells, fn {_pos, cell} -> cell.owner == id end)
  end

  # união das vizinhanças 7x7 ao redor de cada célula da colônia
  defp observable_cells(state, id) do
    owned = for {pos, %{owner: ^id}} <- state.cells, do: pos
    r = @view_radius

    owned
    |> Enum.flat_map(fn {cx, cy} ->
      for x <- (cx - r)..(cx + r), y <- (cy - r)..(cy + r), do: {x, y}
    end)
    |> Enum.uniq()
    |> Enum.filter(fn {x, y} -> x >= 0 and y >= 0 and x < state.width and y < state.height end)
    |> Enum.sort()
    |> Enum.map(fn {x, y} ->
      cell = cell_at(state, x, y)
      {x, y, cell.terrain, cell.owner, cell.fortified}
    end)
  end

  ## Grade

  defp initial_cells(terrain) do
    Map.new(terrain, fn {x, y, t} -> {{x, y}, %{terrain: t, owner: 0, fortified: 0}} end)
  end

  defp full_grid(state) do
    for x <- 0..(state.width - 1), y <- 0..(state.height - 1) do
      cell = cell_at(state, x, y)
      {x, y, cell.terrain, cell.owner, cell.fortified}
    end
  end

  defp cell_at(state, {x, y}), do: cell_at(state, x, y)
  defp cell_at(state, x, y), do: Map.get(state.cells, {x, y}, @empty)

  defp schedule_tick(tick_ms), do: Process.send_after(self(), :tick, tick_ms)
end
