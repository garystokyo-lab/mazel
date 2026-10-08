defmodule Room.Intro do
  @moduledoc """
  Intro wing LOOK. 🪽🪽 — broker/vouch story, not Direct.
  """

  @wing "🪽🪽"

  def wing_mark, do: @wing

  def look(result) when is_map(result) do
    state = result[:state] || result
    badge = badge_of(state)
    {from, peer} = ends(result)
    opener = opener_of(state)

    [
      "ok  kind=intro  wing=#{@wing}  badge=#{badge}",
      "ok  morph=morph.commit  consent=dual",
      "warm  from=#{from}  peer=#{peer}",
      "warm  why=intro",
      "warm  opener=#{opener}",
      "warm  consent=dual"
    ]
  end

  def after_return(result, wrapped) do
    look(result) ++ [Room.Return.look(wrapped)]
  end

  @command "🪽🪽 @kai series-A CTO"

  def command, do: @command

  @doc """
  Intro wing end-to-end. Parse 🪽🪽, mint vouch, dual morph, return.
  Distinct from `intro_demo` (no mint beat) and Direct invite.
  """
  def look_e2e(pack) when is_map(pack) do
    handle = pack[:handle] || "kai@mazel"
    badge = pack[:badge] || %{}
    source = badge["source"] || badge[:source] || "vouch"
    kind = badge["kind"] || badge[:kind] || "vouch"
    opener = opener_of(pack[:state] || %{})

    [
      "ok  kind=intro  wing=#{@wing}  handle=#{handle}",
      "ok  mint=#{source}  badge=#{kind}",
      "ok  morph=morph.commit  consent=dual",
      "warm  why=intro",
      "warm  opener=#{opener}",
      "warm  consent=dual",
      "ok  return=agent  morph=closed  session=agent"
    ]
  end

  def look_e2e(_), do: look_e2e(%{})

  def e2e_demo(opts \\ []) do
    context = Keyword.get(opts, :context_id) || "intro-e2e-" <> random_id()
    command = Keyword.get(opts, :command) || @command

    with {:ok, cmd} <- Room.Wings.parse(command),
         {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
         {:ok, badge} <-
           Room.Badge.mint(:vouch,
             voucher: ariel,
             subject: kai,
             note: "Intro wing. Ariel vouches for Kai."
           ),
         {:ok, state} <- play(context, ariel, kai, badge),
         {:ok, wrapped} <- Room.Return.wrap(context) do
      cond do
        cmd.session_kind != :intro or Room.Types.wing_mark(cmd.session_kind) != @wing ->
          {:error, :not_intro}

        cmd.target.id != "kai@mazel" ->
          {:error, :handle_miss}

        badge["source"] != "vouch" or badge["kind"] != "vouch" ->
          {:error, :not_vouch}

        state.status != :morphed or not state.dual_consent ->
          {:error, :morph_miss}

        wrapped.status != :returned or wrapped.morph != "closed" or wrapped.session != "agent" ->
          {:error, :return_miss}

        true ->
          pack = %{
            handle: "kai@mazel",
            badge: badge,
            state: state,
            wrapped: wrapped,
            cmd: cmd
          }

          {:ok, Map.put(pack, :lines, look_e2e(pack))}
      end
    end
  end

  defp play(context_id, from, peer, badge) do
    {:ok, _} =
      Room.open(context_id, :intro, [
        %{handle: Map.take(from, [:id, :card_url]), role: :agent},
        %{handle: Map.take(peer, [:id, :card_url]), role: :agent}
      ])

    {:ok, _} = Room.submit_badge(context_id, badge)
    {:ok, _} = Room.propose_morph(context_id, from.id)
    {:ok, _} = Room.consent(context_id, from.id)
    {:ok, _} = Room.consent(context_id, peer.id)

    Room.commit_morph(
      context_id,
      "Intro wing. Broker vouch. Humans inherit this packet.",
      [
        %{speaker: Map.take(from, [:id, :card_url]), text: "Ariel introducing Kai."},
        %{speaker: Map.take(peer, [:id, :card_url]), text: "Kai is up. Morph."}
      ]
    )
  end

  defp random_id do
    :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
  end

  defp badge_of(state) do
    badge = state[:badge] || %{}
    badge["kind"] || badge[:kind] || "pull_intent"
  end

  defp ends(%{from: from, peer: peer}), do: {id_of(from), id_of(peer)}

  defp ends(%{state: state}), do: ends(state)

  defp ends(state) when is_map(state) do
    agents =
      (state[:participants] || [])
      |> Enum.filter(fn
        %{role: role} when role in [:agent, "agent"] -> true
        _ -> false
      end)

    {id_of(Enum.at(agents, 0)), id_of(Enum.at(agents, 1))}
  end

  defp opener_of(state) do
    packet = state[:warm_packet] || %{}
    excerpt = packet[:transcript_excerpt] || packet["transcript_excerpt"] || []

    case List.first(excerpt) do
      %{text: text} when is_binary(text) -> text
      %{"text" => text} when is_binary(text) -> text
      _ -> ""
    end
  end

  defp id_of(%{id: id}) when is_binary(id), do: id
  defp id_of(%{"id" => id}) when is_binary(id), do: id
  defp id_of(%{handle: handle}), do: id_of(handle)
  defp id_of(_), do: ""
end
