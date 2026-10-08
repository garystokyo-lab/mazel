defmodule Room.MatchChatOpener do
  @moduledoc """
  Self-report match, then first talk carries a short opener.

  Morph denied without a badge. Distinct from match_chat /
  match_chat_return / match_chat_turns (no opener=).
  Not wiki / GH proof.
  """

  @opener "hello"

  def opener, do: @opener

  def look_has(rec \\ %{}), do: Room.MatchChat.look_has(rec)
  def look_need(rec \\ %{}), do: Room.MatchChat.look_need(rec)
  def look_find(rec \\ %{}), do: Room.MatchChat.look_find(rec)
  def look_talk(rec \\ %{}, n \\ 1), do: Room.MatchChat.look_talk(rec, n)
  def look_denied, do: Room.MatchChat.look_denied()

  def look_opener(rec \\ %{}, n \\ 1) do
    who = rec[:local] || "ariel"
    text = rec[:opener] || rec[:text] || @opener
    "ok  talk=@#{who}  turn=#{n}  opener=#{text}"
  end

  def look(pack) when is_map(pack) do
    [
      look_has(pack.has),
      look_need(pack.need),
      look_find(pack.hit),
      look_opener(pack.turn_a, 1),
      look_talk(pack.turn_b, 1),
      look_denied()
    ]
  end

  def look(_),
    do:
      look(%{
        has: %{},
        need: %{},
        hit: %{},
        turn_a: %{local: "ariel", opener: @opener},
        turn_b: %{local: "kai"}
      })

  @doc """
  Match → opener talk → reply → denied.
  Isolated. Sibling one-turn LOOK stays (no opener=).
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "match-chat-opener-" <> random_id()

    with {:ok, matched} <- Room.SelfReportMatch.demo(context_id: prefix),
         {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup(matched.hit.handle || "@kai"),
         {:ok, _} <- Room.talk(matched.session.context_id, ariel, @opener),
         {:ok, after_b} <- Room.talk(matched.session.context_id, kai, "has"),
         {:error, :badge_required} <- Room.propose_morph(matched.session.context_id, ariel) do
      talks = Enum.filter(after_b.events || [], &(&1.type == "talk"))
      first = List.first(talks)

      cond do
        matched.has.source != "self_report" ->
          {:error, :not_self_report}

        length(talks) != 2 ->
          {:error, :talk_miss}

        first == nil or first.payload[:text] != @opener ->
          {:error, :opener_miss}

        after_b.badge != nil ->
          {:error, :morphed}

        true ->
          pack = %{
            has: matched.has,
            need: matched.need,
            hit: matched.hit,
            turn_a: %{handle: ariel.id, local: "ariel", opener: @opener},
            turn_b: %{handle: kai.id, local: "kai"},
            session: after_b,
            opener: @opener,
            denied: :badge_required
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
