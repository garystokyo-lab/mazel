defmodule Room.MatchChatReturn do
  @moduledoc """
  Self-report match + talk×1 each, then return=agent wrap.

  Morph is denied without a badge. Distinct from match_chat
  (no return=) and talk_return (no self-report lead-in).
  Not wiki / GH proof.
  """

  def look_has(rec \\ %{}), do: Room.MatchChat.look_has(rec)
  def look_need(rec \\ %{}), do: Room.MatchChat.look_need(rec)
  def look_find(rec \\ %{}), do: Room.MatchChat.look_find(rec)
  def look_talk(rec \\ %{}, n \\ 1), do: Room.MatchChat.look_talk(rec, n)
  def look_denied, do: Room.MatchChat.look_denied()
  def look_return(wrapped \\ nil), do: Room.Return.look(wrapped)

  def look(pack) when is_map(pack) do
    Room.MatchChat.look(pack) ++ [look_return(pack[:wrapped])]
  end

  def look(_), do: look(%{has: %{}, need: %{}, hit: %{}, turn_a: %{local: "ariel"}, turn_b: %{local: "kai"}})

  @doc """
  Match-chat strip, then wrap back to agent.
  Isolated. Sibling match_chat / talk_return LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "match-chat-return-" <> random_id()

    with {:ok, chat} <- Room.MatchChat.demo(context_id: prefix <> "-chat"),
         {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup(chat.hit.handle || "@kai"),
         {:ok, badge} <- pull_stamp(ariel),
         {:ok, wrapped} <- wrap_after(chat.session.context_id, ariel, kai, badge) do
      cond do
        chat.has.source != "self_report" or chat.denied != :badge_required ->
          {:error, :chat_miss}

        wrapped.status != :returned or wrapped.morph != "closed" ->
          {:error, :no_return}

        wrapped.session != "agent" ->
          {:error, :session_miss}

        true ->
          pack =
            chat
            |> Map.put(:wrapped, wrapped)
            |> Map.put(:badge, badge)

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
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
