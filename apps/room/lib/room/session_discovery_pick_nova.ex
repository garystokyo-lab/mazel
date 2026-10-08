defmodule Room.SessionDiscoveryPickNova do
  @moduledoc """
  Pick a later discovery handle — not first-by-order.

  need@mazel lists kai first, then nova. pick=@nova
  opens Direct talk with id=. Morph denied without a
  badge. Distinct from session_discovery_pick (picks
  kai@mazel first) and match_chat_pick (Need×Has
  pick=@nova, not discovery). Off mint / Match / wiki /
  Consent / A2A.
  """

  def look_discovery(handles \\ ["kai@mazel", "nova@mazel"]) do
    Room.SessionDiscoveryPick.look_discovery(handles)
  end

  def look_pick(id, handle \\ "@nova") do
    "ok  pick=#{show_pick(handle)}  direct=open  id=#{id}"
  end

  def look_talk, do: Room.MatchChat.look_talk(%{local: "nova"}, 1)
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
    do: look(%{handles: ["kai@mazel", "nova@mazel"], picked: "nova@mazel", open_id: "session-direct-a"})

  @doc """
  Discovery lists kai first. pick=@nova → Direct id +
  talk. Morph denied. Isolated. Sibling pick /
  match_chat_pick LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-direct-" <> random_id()
    want = Keyword.get(opts, :pick) || "@nova"

    need = Room.SelfReportMatch.parse(Keyword.get(opts, :need) || "need: series-a")
    has_kai = Room.SelfReportMatch.report(:has, "series-a", handle: "kai@mazel")
    has_nova = Room.SelfReportMatch.report(:has, "series-a", handle: "nova@mazel")
    hits = Room.SelfReportMatch.match_all([has_kai, has_nova], need)
    found = Room.SessionDiscovery.handles(hits)
    first = List.first(found)
    picked = Room.SessionDiscovery.pick(found, want)

    with picked when is_binary(picked) <- picked,
         {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, opened} <- Room.SessionDiscovery.open_picked(prefix, found, want),
         {:ok, peer} <- Room.Cards.lookup(picked),
         {:ok, after_talk} <- Room.talk(prefix, peer, "hello"),
         {:error, :badge_required} <- Room.propose_morph(prefix, ariel) do
      talks = Enum.filter(after_talk.events || [], &(&1.type == "talk"))
      events = Enum.map(after_talk.events || [], & &1.type)
      id = Room.SessionContext.id(after_talk)
      peers = Enum.map(after_talk.participants || [], &handle_id/1)

      cond do
        not Room.Need.discovery_sink?("need@mazel") ->
          {:error, :sink_miss}

        found != ["kai@mazel", "nova@mazel"] or first != "kai@mazel" ->
          {:error, :handle_miss}

        picked != "nova@mazel" or picked == first ->
          {:error, :pick_miss}

        Room.SessionDiscovery.pick(found, "kai@mazel") != "kai@mazel" ->
          {:error, :order_miss}

        Room.SessionDiscovery.pick(found, "@ghost") != nil ->
          {:error, :ghost_hit}

        opened.session_kind != :direct or after_talk.session_kind != :direct ->
          {:error, :not_direct}

        id != prefix or id == nil ->
          {:error, :id_miss}

        "kai@mazel" in peers or "nova@mazel" not in peers ->
          {:error, :peer_miss}

        after_talk.badge != nil or "morph.commit" in events ->
          {:error, :morphed}

        length(talks) != 1 or after_talk.status != :open ->
          {:error, :talk_miss}

        humans_awake?(after_talk) ->
          {:error, :human_woke}

        true ->
          pack = %{
            handles: found,
            first: first,
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

  defp handle_id(p) do
    h = p[:handle] || p.handle

    cond do
      is_map(h) -> h[:id] || h.id
      true -> h
    end
  end

  defp show_pick("nova@mazel"), do: "@nova"
  defp show_pick("@nova"), do: "@nova"
  defp show_pick(handle), do: handle

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
