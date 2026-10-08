defmodule Room.MatchChatPick do
  @moduledoc """
  One Need, two Has peers, pick a later peer.

  pick=@nova mazel'd — not first-by-order (kai).
  Both still talk without morph. Distinct from
  match_chat_multi (first = kai). Not wiki / GH.
  """

  def look_need(rec \\ %{}), do: Room.MatchChatMulti.look_need(rec)
  def look_has(rec \\ %{}), do: Room.MatchChatMulti.look_has(rec)
  def look_talk(rec \\ %{}), do: Room.MatchChatMulti.look_talk(rec)

  def look_pick(rec \\ %{}) do
    peer = rec[:handle] || "nova@mazel"
    who = local_of(peer)
    "ok  pick=@#{who}  find=series-a→#{peer}  #{Room.Find.mazel_d(peer)}"
  end

  def look(pack) when is_map(pack) do
    [
      look_need(pack.need),
      look_has(pack.has_kai),
      look_has(pack.has_nova),
      look_pick(pack.hit),
      look_talk(pack.talk_kai),
      look_talk(pack.talk_nova)
    ]
  end

  def look(_),
    do:
      look(%{
        need: %{},
        has_kai: %{handle: "kai@mazel"},
        has_nova: %{handle: "nova@mazel"},
        hit: %{handle: "nova@mazel"},
        talk_kai: %{local: "kai"},
        talk_nova: %{local: "nova"}
      })

  @doc """
  Same two-peer overlap as multi. pick nova. Both talk.
  Isolated. Sibling multi LOOK stays (kai first, no pick=).
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "match-chat-pick-" <> random_id()
    want = Keyword.get(opts, :pick) || "nova@mazel"

    need = Room.SelfReportMatch.parse(Keyword.get(opts, :need) || "need: series-a")
    has_kai = Room.SelfReportMatch.report(:has, "series-a", handle: "kai@mazel")
    has_nova = Room.SelfReportMatch.report(:has, "series-a", handle: "nova@mazel")
    hits = Room.SelfReportMatch.match_all([has_kai, has_nova], need)
    first = List.first(hits)
    picked = Room.SelfReportMatch.pick(hits, want)

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("kai@mazel"),
         {:ok, nova} <- Room.Cards.lookup("nova@mazel"),
         {:ok, kai_room} <- talk_peer(prefix <> "-kai", ariel, kai, "has-kai"),
         {:ok, nova_room} <- talk_peer(prefix <> "-nova", ariel, nova, "has-nova") do
      cond do
        need.source != "self_report" or need.tags != ["series-a"] ->
          {:error, :not_self_report}

        length(hits) != 2 or is_nil(first) or first.handle != "kai@mazel" ->
          {:error, :order_miss}

        is_nil(picked) or picked.handle != "nova@mazel" ->
          {:error, :pick_miss}

        morphed?(kai_room) or morphed?(nova_room) ->
          {:error, :morphed}

        talk_count(kai_room) != 1 or talk_count(nova_room) != 1 ->
          {:error, :talk_miss}

        true ->
          pack = %{
            need: need,
            has_kai: has_kai,
            has_nova: has_nova,
            hit: picked,
            first: first,
            hits: hits,
            pick: want,
            talk_kai: %{handle: kai.id, local: "kai"},
            talk_nova: %{handle: nova.id, local: "nova"},
            kai_room: kai_room,
            nova_room: nova_room
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp talk_peer(id, ariel, peer, text) do
    with {:ok, _} <-
           Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: peer, role: :agent}]),
         {:ok, state} <- Room.talk(id, peer, text) do
      {:ok, state}
    end
  end

  defp talk_count(state) do
    Enum.count(state.events || [], &(&1.type == "talk"))
  end

  defp morphed?(state) do
    state.badge != nil or Enum.any?(state.events || [], &(&1.type == "morph.commit"))
  end

  defp local_of(handle) do
    handle
    |> to_string()
    |> String.trim_leading("@")
    |> String.split("@")
    |> hd()
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
