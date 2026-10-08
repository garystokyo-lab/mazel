defmodule Room.MatchChatTurns do
  @moduledoc """
  Self-report match, then three free talk turns each.

  Morph denied without a badge. Then return=agent wrap.
  Distinct from match_chat / match_chat_return (one turn).
  Not wiki / GH proof.
  """

  def look_has(rec \\ %{}), do: Room.MatchChat.look_has(rec)
  def look_need(rec \\ %{}), do: Room.MatchChat.look_need(rec)
  def look_find(rec \\ %{}), do: Room.MatchChat.look_find(rec)
  def look_talk(rec \\ %{}, n \\ 1), do: Room.MatchChat.look_talk(rec, n)
  def look_denied, do: Room.MatchChat.look_denied()
  def look_return(wrapped \\ nil), do: Room.Return.look(wrapped)

  def look(pack) when is_map(pack) do
    talks =
      Enum.flat_map(1..3, fn n ->
        [look_talk(pack.turn_a, n), look_talk(pack.turn_b, n)]
      end)

    [look_has(pack.has), look_need(pack.need), look_find(pack.hit)] ++
      talks ++ [look_denied(), look_return(pack[:wrapped])]
  end

  def look(_),
    do: look(%{has: %{}, need: %{}, hit: %{}, turn_a: %{local: "ariel"}, turn_b: %{local: "kai"}})

  @doc """
  Match → three talks each → denied → wrap.
  Isolated. Sibling one-turn LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "match-chat-turns-" <> random_id()

    with {:ok, matched} <- Room.SelfReportMatch.demo(context_id: prefix),
         {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup(matched.hit.handle || "@kai"),
         {:ok, session} <- talk_three(matched.session.context_id, ariel, kai),
         {:error, :badge_required} <- Room.propose_morph(matched.session.context_id, ariel),
         {:ok, badge} <- pull_stamp(ariel),
         {:ok, wrapped} <- wrap_after(matched.session.context_id, ariel, kai, badge) do
      talks = Enum.filter(session.events || [], &(&1.type == "talk"))

      cond do
        matched.has.source != "self_report" ->
          {:error, :not_self_report}

        length(talks) != 6 ->
          {:error, :talk_miss}

        wrapped.status != :returned or wrapped.session != "agent" ->
          {:error, :no_return}

        true ->
          pack = %{
            has: matched.has,
            need: matched.need,
            hit: matched.hit,
            turn_a: %{handle: ariel.id, local: "ariel"},
            turn_b: %{handle: kai.id, local: "kai"},
            session: session,
            denied: :badge_required,
            wrapped: wrapped
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp talk_three(id, ariel, kai) do
    Enum.reduce_while(1..3, {:ok, nil}, fn n, _ ->
      with {:ok, _} <- Room.talk(id, ariel, "series-a-#{n}"),
           {:ok, state} <- Room.talk(id, kai, "has-#{n}") do
        {:cont, {:ok, state}}
      else
        err -> {:halt, err}
      end
    end)
  end

  defp wrap_after(id, ariel, kai, badge) do
    with {:ok, _} <- Room.submit_badge(id, badge),
         {:ok, _} <- Room.propose_morph(id, ariel),
         {:ok, _} <- Room.consent(id, ariel),
         {:ok, _} <- Room.consent(id, kai),
         {:ok, _} <- Room.commit_morph(id, "Match talk wrapped.", []),
         {:ok, wrapped} <- Room.Return.wrap(id) do
      {:ok, wrapped}
    end
  end

  defp pull_stamp(actor) do
    Room.Badge.mint(:pull_match,
      need: %{id: "need-enterprise-ai", topic: "enterprise-ai"},
      open: %{id: "open-enterprise-ai", handle: "kai@mazel", topic: "enterprise-ai"},
      match: %{id: "open-enterprise-ai", topic: "enterprise-ai", score: 1.0, handle: "kai@mazel"},
      actor: actor
    )
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
