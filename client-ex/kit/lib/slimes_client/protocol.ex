defmodule SlimesClient.Protocol do
  @moduledoc """
  Parse e encode das linhas do protocolo, na fronteira.

  Regra do PROTOCOL.md: tokens extras no final são ignorados (leitor
  tolerante), linha malformada vira `{:error, reason}` e nunca lança exceção.
  Refs: `<nome>-<sessão>-<n>`, sessão de 4 chars gerada uma vez por processo.
  """

  @alpha ~c"abcdefghijklmnopqrstuvwxyz0123456789"

  # --- encode ---------------------------------------------------------------

  @doc """
  Gera o segmento de sessão do ref: 4 caracteres aleatórios de `a-z0-9`.

  É chamado uma vez por processo (como default de `refs/2`) e garante que
  os refs não colidem entre reconexões.

      Protocol.new_session()
      # => "k3f9"   (aleatório, muda a cada chamada)
  """
  def new_session, do: for(_ <- 1..4, into: "", do: <<Enum.random(@alpha)>>)

  @doc """
  Estado inicial do gerador de refs: `%{name, session, n}`.

  `name` é o nome da colônia e `session` é o segmento aleatório de
  `new_session/0` (passe um fixo nos testes para refs previsíveis).
  O contador `n` cresce a cada `next_ref/1`.

      Protocol.refs("ana", "x1y2")
      # => %{name: "ana", session: "x1y2", n: 0}
  """
  def refs(name, session \\ new_session()), do: %{name: name, session: session, n: 0}

  @doc """
  Devolve `{ref, novo_refs}`: o próximo ref e o gerador atualizado.

  O formato é `<nome>-<sessão>-<n>`, com `n` crescendo a cada chamada.

      {ref, refs} = Protocol.next_ref(Protocol.refs("ana", "x1y2"))
      ref
      # => "ana-x1y2-1"
  """
  def next_ref(%{n: n} = refs) do
    n = n + 1
    {"#{refs.name}-#{refs.session}-#{n}", %{refs | n: n}}
  end

  @doc """
  Linha HELLO de entrada no jogo.

  `encode_hello/2` entra como espectador; `encode_hello/3` entra como
  colônia com o nome dado. Devolve a linha pronta para o socket.

      Protocol.encode_hello("srv-0", "spectator")
      # => "HELLO v1 srv-0 spectator"

      Protocol.encode_hello("ana-x1y2-1", "colony", "ana")
      # => "HELLO v1 ana-x1y2-1 colony ana"
  """
  def encode_hello(ref, "spectator"), do: "HELLO v1 #{ref} spectator"
  def encode_hello(ref, "colony", name), do: "HELLO v1 #{ref} colony #{name}"

  @doc """
  E2: ação de domínio -> linha de protocolo com ref correto.

  TODO E2: implemente. O formato é:

      ACT <ref> <kind> <x> <y>   para expand, attack e fortify
      ACT <ref> pass             para pass (sem coordenadas)

  A ação de domínio é `%{kind: "expand" | "attack" | "fortify", x: x, y: y}`
  ou `%{kind: "pass"}`. Pattern matching na cabeça da função resolve.
  Devolve a linha pronta para o socket.

      Protocol.encode_action(%{kind: "expand", x: 12, y: 7}, "ana-x1y2-2")
      # => "ACT ana-x1y2-2 expand 12 7"

      Protocol.encode_action(%{kind: "pass"}, "ana-x1y2-3")
      # => "ACT ana-x1y2-3 pass"

  Enquanto o stub estiver aqui a sua colônia só passa a vez.
  """
  def encode_action(_action, ref), do: "ACT #{ref} pass"

  @doc """
  Linha PING com o ref dado (keepalive; o servidor responde PONG).

      Protocol.encode_ping("ana-x1y2-9")
      # => "PING ana-x1y2-9"
  """
  def encode_ping(ref), do: "PING #{ref}"

  # --- parse ----------------------------------------------------------------

  # inteiros base-10; qualquer outra coisa torna a linha malformada
  defp int(tok) when is_binary(tok) do
    case Integer.parse(tok) do
      {n, ""} -> {:ok, n}
      _ -> :error
    end
  end

  defp int(_), do: :error

  defp tok(t, i), do: Enum.at(t, i)

  @doc """
  Faz o parse de uma célula no formato `x,y,terrain,owner,fortified`.

  Devolve `{:ok, %{x, y, terrain, owner, fortified}}` ou `:error` se algum
  campo estiver faltando ou não for inteiro onde devia. Tokens extras no
  final da célula são ignorados (leitor tolerante). Usada por
  `parse_observation/1` (E1), uma vez por célula da lista.

      Protocol.parse_cell("9,5,plain,3,1")
      # => {:ok, %{x: 9, y: 5, terrain: "plain", owner: 3, fortified: 1}}

      Protocol.parse_cell("9,5,plain,0")
      # => :error
  """
  def parse_cell(tok) do
    case String.split(tok, ",") do
      [x, y, terrain, owner, fortified | _] ->
        with {:ok, x} <- int(x),
             {:ok, y} <- int(y),
             {:ok, owner} <- int(owner),
             {:ok, fortified} <- int(fortified) do
          {:ok, %{x: x, y: y, terrain: terrain, owner: owner, fortified: fortified}}
        else
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp cell_list(nil), do: {:ok, []}
  defp cell_list(""), do: {:ok, []}

  defp cell_list(tok) do
    cells = Enum.map(String.split(tok, ";"), &parse_cell/1)

    if Enum.any?(cells, &(&1 == :error)) do
      :error
    else
      {:ok, Enum.map(cells, fn {:ok, c} -> c end)}
    end
  end

  @doc """
  E1: uma linha OBS crua -> observação de domínio.

  TODO E1: implemente. O formato da linha é:

      OBS <ref> <tick> <status> <scores_tick> <celulas>

  `status` é "alive" ou "dead"; `celulas` é a lista separada por ";"
  (`parse_cell/1` e `cell_list/1` acima já existem, use-as). Devolva:

      {:ok, %{type: "obs", ref: ref, tick: tick, status: status,
              scores_tick: scores_tick, cells: cells}}

  ou `{:error, "motivo"}`. Linha malformada vira `{:error, _}`, nunca
  exceção. Tokens extras no final são ignorados (é o que salva o seu
  cliente no drill da v2).

      Protocol.parse_observation("OBS srv-97 97 alive 97 9,5,plain,0,0")
      # => {:ok, %{type: "obs", ref: "srv-97", tick: 97, status: "alive",
      #            scores_tick: 97,
      #            cells: [%{x: 9, y: 5, terrain: "plain", owner: 0, fortified: 0}]}}

  Enquanto o stub estiver aqui toda linha OBS volta como erro e o cliente
  não joga.
  """
  @spec parse_observation(String.t()) :: {:ok, map()} | {:error, String.t()}
  def parse_observation(line) do
    {:error, "TODO E1: implemente parse_observation (#{line})"}
  end

  defp parse_welcome(t) do
    if tok(t, 2) == "spectator" do
      with {:ok, w} <- int(tok(t, 3)),
           {:ok, h} <- int(tok(t, 4)),
           {:ok, tick_ms} <- int(tok(t, 5)),
           {:ok, cells} <- cell_list(tok(t, 6)) do
        {:ok,
         %{type: "welcome", role: "spectator", w: w, h: h, tick_ms: tick_ms, cells: cells}}
      else
        _ -> {:error, "welcome de espectador malformado"}
      end
    else
      with {:ok, id} <- int(tok(t, 2)),
           {:ok, w} <- int(tok(t, 5)),
           {:ok, h} <- int(tok(t, 6)),
           {:ok, tick_ms} <- int(tok(t, 7)),
           {:ok, view_radius} <- int(tok(t, 8)),
           [sx, sy | _] <- String.split(tok(t, 9) || "", ","),
           {:ok, spawn_x} <- int(sx),
           {:ok, spawn_y} <- int(sy) do
        {:ok,
         %{
           type: "welcome",
           role: "colony",
           id: id,
           name: tok(t, 3),
           color: tok(t, 4),
           w: w,
           h: h,
           tick_ms: tick_ms,
           view_radius: view_radius,
           spawn: {spawn_x, spawn_y}
         }}
      else
        _ -> {:error, "welcome malformado"}
      end
    end
  end

  defp parse_score(t) do
    with {:ok, tick} <- int(tok(t, 2)),
         {:ok, entries} <- score_entries(tok(t, 3)) do
      {:ok, %{type: "score", ref: tok(t, 1), tick: tick, entries: entries}}
    else
      _ -> {:error, "score malformado"}
    end
  end

  defp score_entries(nil), do: {:ok, []}

  defp score_entries(tok) do
    entries =
      tok
      |> String.split(";")
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(fn e ->
        case String.split(e, ",") do
          [id, name, cells, status | _] ->
            with {:ok, id} <- int(id), {:ok, cells} <- int(cells) do
              {:ok, %{id: id, name: name, cells: cells, status: status}}
            else
              _ -> :error
            end

          _ ->
            :error
        end
      end)

    if Enum.any?(entries, &(&1 == :error)),
      do: :error,
      else: {:ok, Enum.map(entries, fn {:ok, e} -> e end)}
  end

  defp parse_diff(t) do
    with {:ok, tick} <- int(tok(t, 2)),
         {:ok, changes} <- diff_changes(tok(t, 3)) do
      {:ok, %{type: "diff", ref: tok(t, 1), tick: tick, changes: changes}}
    else
      _ -> {:error, "diff malformado"}
    end
  end

  defp diff_changes(nil), do: {:ok, []}

  defp diff_changes(tok) do
    changes =
      tok
      |> String.split(";")
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(fn c ->
        case String.split(c, ",") do
          [x, y, owner, fortified | _] ->
            with {:ok, x} <- int(x),
                 {:ok, y} <- int(y),
                 {:ok, owner} <- int(owner),
                 {:ok, fortified} <- int(fortified) do
              {:ok, %{x: x, y: y, owner: owner, fortified: fortified}}
            else
              _ -> :error
            end

          _ ->
            :error
        end
      end)

    if Enum.any?(changes, &(&1 == :error)),
      do: :error,
      else: {:ok, Enum.map(changes, fn {:ok, c} -> c end)}
  end

  @doc """
  Ponto de entrada do parse: uma linha crua do socket vira uma mensagem de
  domínio tagueada.

  Devolve `{:ok, %{type: ...}}` com o mapa da mensagem ou
  `{:error, motivo}`. Nunca lança exceção: linha malformada ou de tipo
  desconhecido vira `{:error, _}`. Tipos possíveis: OBS (via
  `parse_observation/1`, o E1), WELCOME, ACK, NACK, ERR, SCORE, DIFF e
  PONG.

      Protocol.parse_line("ACK ana-x1y2-1 42")
      # => {:ok, %{type: "ack", ref: "ana-x1y2-1", tick: 42}}

      Protocol.parse_line("NAOEXISTE foo")
      # => {:error, "tipo desconhecido NAOEXISTE"}
  """
  @spec parse_line(String.t()) :: {:ok, map()} | {:error, String.t()}
  def parse_line(line) do
    t = String.split(line, " ")

    case hd(t) do
      "OBS" ->
        parse_observation(line)

      "WELCOME" ->
        parse_welcome(t)

      "ACK" ->
        case int(tok(t, 2)) do
          {:ok, tick} -> {:ok, %{type: "ack", ref: tok(t, 1), tick: tick}}
          :error -> {:error, "ack sem tick"}
        end

      "NACK" ->
        {:ok,
         %{
           type: "nack",
           ref: tok(t, 1),
           code: tok(t, 2),
           detail: Enum.join(Enum.drop(t, 3), " ")
         }}

      "ERR" ->
        {:ok,
         %{
           type: "err",
           ref: tok(t, 1),
           code: tok(t, 2),
           detail: Enum.join(Enum.drop(t, 3), " ")
         }}

      "SCORE" ->
        parse_score(t)

      "DIFF" ->
        parse_diff(t)

      "PONG" ->
        {:ok, %{type: "pong", ref: tok(t, 1)}}

      other ->
        {:error, "tipo desconhecido #{other}"}
    end
  end
end
