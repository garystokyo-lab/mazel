defmodule Room.Group do
  @moduledoc """
  Group wing LOOK. 🪽🪽🪽 — invite-only multi-handle stub.
  Distinct from Direct (🪽) and Intro (🪽🪽).
  """

  @wing "🪽🪽🪽"
  @command "🪽🪽🪽 @kai @nova sit together"

  def wing_mark, do: @wing
  def command, do: @command

  def run(opts \\ []) do
    context_id = Keyword.get(opts, :context_id) || "group-" <> random_id()

    with {:ok, result} <- Room.Wings.run(@command, Keyword.put(opts, :context_id, context_id)) do
      {:ok, wrapped} = Room.Return.wrap(result.state.context_id)
      {:ok, Map.put(result, :lines, after_return(result, wrapped))}
    end
  end

  def look(result) when is_map(result) do
    state = result[:state] || result
    handles = handle_list(result)
    opener = opener_of(state)

    [
      "ok  kind=group  wing=#{@wing}  handles=#{handles}",
      "ok  morph=morph.commit  consent=dual",
      "warm  why=group",
      "warm  opener=#{opener}",
      "warm  consent=dual"
    ]
  end

  def after_return(result, wrapped) do
    look(result) ++ [Room.Return.look(wrapped)]
  end

  @doc """
  Group wing end-to-end. Parse 🪽🪽🪽, mint invite, dual morph, return.
  Distinct from `group_demo` (no mint beat) and Direct invite.
  """
  def look_e2e(pack) when is_map(pack) do
    handles = pack[:handles] || "ariel@mazel,kai@mazel,nova@mazel"
    badge = pack[:badge] || %{}
    source = badge["source"] || badge[:source] || "invite"
    kind = badge["kind"] || badge[:kind] || "invite_token"
    opener = opener_of(pack[:state] || %{})

    [
      "ok  kind=group  wing=#{@wing}  handles=#{handles}",
      "ok  mint=#{source}  badge=#{kind}",
      "ok  morph=morph.commit  consent=dual",
      "warm  why=group",
      "warm  opener=#{opener}",
      "warm  consent=dual",
      "ok  return=agent  morph=closed  session=agent"
    ]
  end

  def look_e2e(_), do: look_e2e(%{})

  def e2e_demo(opts \\ []) do
    context = Keyword.get(opts, :context_id) || "group-e2e-" <> random_id()
    command = Keyword.get(opts, :command) || @command

    with {:ok, cmd} <- Room.Wings.parse(command),
         {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
         {:ok, nova} <- Room.Cards.lookup("@nova"),
         {:ok, badge} <-
           Room.Badge.mint(:invite, issuer: ariel, token: "group-invite-v0"),
         {:ok, state} <- play(context, ariel, [kai, nova], badge, cmd.text),
         {:ok, wrapped} <- Room.Return.wrap(context) do
      handles = Enum.map_join([ariel, kai, nova], ",", & &1.id)

      cond do
        cmd.session_kind != :group or Room.Types.wing_mark(cmd.session_kind) != @wing ->
          {:error, :not_group}

        Enum.map(cmd.targets, & &1.id) != ["kai@mazel", "nova@mazel"] ->
          {:error, :handle_miss}

        badge["source"] != "invite" or badge["kind"] != "invite_token" ->
          {:error, :not_invite}

        state.status != :morphed or not state.dual_consent ->
          {:error, :morph_miss}

        wrapped.status != :returned or wrapped.morph != "closed" or wrapped.session != "agent" ->
          {:error, :return_miss}

        true ->
          pack = %{
            handles: handles,
            badge: badge,
            state: state,
            wrapped: wrapped,
            cmd: cmd
          }

          {:ok, Map.put(pack, :lines, look_e2e(pack))}
      end
    end
  end

  defp play(context_id, from, peers, badge, text) do
    people =
      [from | List.wrap(peers)]
      |> Enum.uniq_by(& &1.id)
      |> Enum.map(&%{handle: Map.take(&1, [:id, :card_url]), role: :agent})

    {:ok, _} = Room.open(context_id, :group, people)
    {:ok, _} = Room.submit_badge(context_id, badge)
    {:ok, _} = Room.propose_morph(context_id, from.id)

    Enum.each([from | List.wrap(peers)], fn who ->
      {:ok, _} = Room.consent(context_id, who.id)
    end)

    Room.commit_morph(
      context_id,
      "Group wing. Invite mint. Humans inherit this packet.",
      [
        %{speaker: Map.take(from, [:id, :card_url]), text: text},
        %{speaker: Map.take(hd(peers), [:id, :card_url]), text: "Kai is up. Morph."}
      ]
    )
  end

  defp handle_list(%{speaker: speaker, peers: peers}) do
    [speaker | List.wrap(peers)]
    |> Enum.map(&id_of/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
    |> Enum.join(",")
  end

  defp handle_list(%{state: state}), do: handle_list(state)

  defp handle_list(state) when is_map(state) do
    (state[:participants] || [])
    |> Enum.filter(fn
      %{role: role} when role in [:agent, "agent"] -> true
      _ -> false
    end)
    |> Enum.map(&id_of/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(",")
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

  defp random_id do
    :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
  end
end
