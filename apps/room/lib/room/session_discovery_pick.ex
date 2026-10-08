defmodule Room.SessionDiscoveryPick do
  @moduledoc """
  Pick a discovery handle and Direct-open it with an id.

  need@mazel lists kai + nova. pick kai@mazel opens
  Direct talk. Morph denied without a badge. Distinct
  from session_discovery_direct (single handle, no id=),
  session_discovery_id (id, no talk), session_discovery_empty
  (handles=[]), and session_direct_id (no discovery pick).
  Off mint / Match / wiki / Consent / A2A.
  """

  def look_discovery(handles \\ ["kai@mazel", "nova@mazel"]) do
    listed =
      handles
      |> List.wrap()
      |> Enum.map(&show_handle/1)
      |> Enum.join(",")

    "ok  discovery=need@mazel  handles=[#{listed}]"
  end

  def look_pick(id, handle \\ "kai@mazel") do
    "ok  pick=#{handle}  direct=open  id=#{id}"
  end

  def look_talk, do: Room.MatchChatDirect.look_talk()
  def look_denied, do: Room.TalkNoMorph.look_denied()

  def look(pack) when is_map(pack) do
    [
      look_discovery(pack[:handles]),
      look_pick(pack[:open_id], pack[:picked]),
      look_talk(),
      look_denied()
    ]
  end

  def look(_),
    do: look(%{handles: ["kai@mazel", "nova@mazel"], picked: "kai@mazel", open_id: "session-direct-a"})

  @doc """
  Discovery lists kai + nova. pick kai → Direct id + talk.
  Morph denied. Isolated. Sibling direct / id / empty
  LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-direct-" <> random_id()
    want = Keyword.get(opts, :pick) || "kai@mazel"

    need = Room.SelfReportMatch.parse(Keyword.get(opts, :need) || "need: series-a")
    has_kai = Room.SelfReportMatch.report(:has, "series-a", handle: "kai@mazel")
    has_nova = Room.SelfReportMatch.report(:has, "series-a", handle: "nova@mazel")
    hits = Room.SelfReportMatch.match_all([has_kai, has_nova], need)
    found = Room.SessionDiscovery.handles(hits)
    picked = Room.SessionDiscovery.pick(found, want)

    with picked when is_binary(picked) <- picked,
         {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, peer} <- Room.Cards.lookup(picked),
         {:ok, opened} <-
           Room.open(prefix, :direct, [
             %{handle: ariel, role: :agent},
             %{handle: peer, role: :agent}
           ]),
         {:ok, after_talk} <- Room.talk(prefix, peer, "hello"),
         {:error, :badge_required} <- Room.propose_morph(prefix, ariel) do
      talks = Enum.filter(after_talk.events || [], &(&1.type == "talk"))
      events = Enum.map(after_talk.events || [], & &1.type)
      id = Room.SessionContext.id(after_talk)

      cond do
        not Room.Need.discovery_sink?("need@mazel") ->
          {:error, :sink_miss}

        found != ["kai@mazel", "nova@mazel"] ->
          {:error, :handle_miss}

        picked != "kai@mazel" ->
          {:error, :pick_miss}

        Room.SessionDiscovery.pick(found, "@ghost") != nil ->
          {:error, :ghost_hit}

        Room.SessionDiscovery.pick(found, "@nova") != "nova@mazel" ->
          {:error, :list_miss}

        opened.session_kind != :direct or after_talk.session_kind != :direct ->
          {:error, :not_direct}

        id != prefix or id == nil ->
          {:error, :id_miss}

        after_talk.badge != nil or "morph.commit" in events ->
          {:error, :morphed}

        length(talks) != 1 or after_talk.status != :open ->
          {:error, :talk_miss}

        humans_awake?(after_talk) ->
          {:error, :human_woke}

        true ->
          pack = %{
            handles: found,
            picked: picked,
            hits: hits,
            session: after_talk,
            open_id: id,
            denied: :badge_required
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    else
      nil -> {:error, :pick_miss}
      other -> other
    end
  end

  defp show_handle("nova@mazel"), do: "@nova"
  defp show_handle(handle), do: handle

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
