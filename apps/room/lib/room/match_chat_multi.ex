defmodule Room.MatchChatMulti do
  @moduledoc """
  One self-report Need matches two Has peers.

  First mazel'd by given tag order (kai before nova).
  Both talk without morph. Distinct from match_chat_*
  (single peer) and match_chat_mismatch (zero overlap).
  Not wiki / GH proof.
  """

  def look_need(rec \\ %{}), do: Room.MatchChat.look_need(rec)

  def look_has(rec \\ %{}) do
    who = local_of(rec[:handle] || "kai@mazel")
    tags = rec[:tags] || ["series-a"]
    "ok  has=@#{who}  tags=[#{Enum.join(List.wrap(tags), ",")}]"
  end

  def look_find(rec \\ %{}), do: Room.MatchChat.look_find(rec)

  def look_talk(rec \\ %{}) do
    who = rec[:local] || local_of(rec[:handle] || "kai@mazel")
    "ok  talk=@#{who}  morph=none"
  end

  def look(pack) when is_map(pack) do
    [
      look_need(pack.need),
      look_has(pack.has_kai),
      look_has(pack.has_nova),
      look_find(pack.hit),
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
        hit: %{},
        talk_kai: %{local: "kai"},
        talk_nova: %{local: "nova"}
      })

  @doc """
  Need × [kai, nova] → first find is kai. Both talk.
  No morph. Isolated. Sibling match-chat LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "match-chat-multi-" <> random_id()

    need = Room.SelfReportMatch.parse(Keyword.get(opts, :need) || "need: series-a")
    has_kai = Room.SelfReportMatch.report(:has, "series-a", handle: "kai@mazel")
    has_nova = Room.SelfReportMatch.report(:has, "series-a", handle: "nova@mazel")
    hits = Room.SelfReportMatch.match_all([has_kai, has_nova], need)
    first = List.first(hits)

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("kai@mazel"),
         {:ok, nova} <- Room.Cards.lookup("nova@mazel"),
         {:ok, kai_room} <- talk_peer(prefix <> "-kai", ariel, kai, "has-kai"),
         {:ok, nova_room} <- talk_peer(prefix <> "-nova", ariel, nova, "has-nova") do
      cond do
        need.source != "self_report" or need.tags != ["series-a"] ->
          {:error, :not_self_report}

        length(hits) != 2 ->
          {:error, :peer_miss}

        is_nil(first) or first.handle != "kai@mazel" ->
          {:error, :order_miss}

        Enum.at(hits, 1).handle != "nova@mazel" ->
          {:error, :order_miss}

        morphed?(kai_room) or morphed?(nova_room) ->
          {:error, :morphed}

        talk_count(kai_room) != 1 or talk_count(nova_room) != 1 ->
          {:error, :talk_miss}

        true ->
          pack = %{
            need: need,
            has_kai: has_kai,
            has_nova: has_nova,
            hit: first,
            hits: hits,
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
