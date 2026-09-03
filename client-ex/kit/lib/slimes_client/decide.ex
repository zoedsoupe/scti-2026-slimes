defmodule SlimesClient.Decide do
  @moduledoc """
  E3: a sua estratégia. observação -> ação, pura.

  É O ÚNICO MÓDULO QUE VOCÊ PRECISA EDITAR para jogar depois do E1 e E2.
  """

  # TODO E3: implemente decide/2. A observação é o que o seu parse do E1
  # devolveu: %{type: "obs", ref: _, tick: _, status: _, scores_tick: _,
  # cells: cells}, onde cada célula é %{x, y, terrain, owner, fortified}.
  # my_id é o id da sua colônia (veio no WELCOME). Devolva uma ação:
  # %{kind: "expand" | "attack" | "fortify", x: x, y: y} ou %{kind: "pass"}.
  #
  # Os helpers de SlimesClient.Observation já estão prontos e testados:
  # own_cells/2, expandable/2 (vazias adjacentes), attackable/2 (inimigas
  # adjacentes), border_cells/2 (suas células na fronteira). Use-os.
  #
  # Dica nível 1 (sobrevivência): expanda para células vazias, nunca ataque
  # célula fortificada. Dica nível 2 (expansão + defesa): fortifique
  # fronteiras com inimigo ao lado, ataque inimigos desfortificados.
  #
  # Enquanto o stub estiver aqui a sua colônia só passa a vez.
  def decide(_obs, _my_id) do
    %{kind: "pass"}
  end
end
