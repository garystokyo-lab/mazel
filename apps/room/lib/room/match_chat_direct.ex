defmodule Room.MatchChatDirect do
  @moduledoc """
  Direct by handle opens talk without Need×Has find.

  Morph still denied without a badge. Distinct from
  match_chat_* (find / mazel'd) and discovery (no talk).
  Off wiki / GH. Off Needs-import.
  """

  def look_direct, do: "ok  direct=@kai  find=none"
  def look_talk, do: Room.MatchChat.look_talk(%{local: "kai"}, 1)
  def look_denied, do: Room.TalkNoMorph.look_denied()

  def look(_pack \\ nil) do
    [look_direct(), look_talk(), look_denied()]
  end

  @doc """
  Open Direct @kai. One talk. Morph denied. Isolated.
  Sibling match_chat / discovery LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "match-chat-direct-" <> random_id()

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
         {:ok, opened} <-
           Room.open(prefix, :direct, [
             %{handle: ariel, role: :agent},
             %{handle: kai, role: :agent}
           ]),
         {:ok, after_talk} <- Room.talk(prefix, kai, "hello"),
         {:error, :badge_required} <- Room.propose_morph(prefix, ariel) do
      talks = Enum.filter(after_talk.events || [], &(&1.type == "talk"))
      events = Enum.map(after_talk.events || [], & &1.type)

      cond do
        opened.session_kind != :direct or after_talk.session_kind != :direct ->
          {:error, :not_direct}

        after_talk.badge != nil or "morph.commit" in events ->
          {:error, :morphed}

        length(talks) != 1 ->
          {:error, :talk_miss}

        after_talk.status != :open ->
          {:error, :session_miss}

        humans_awake?(after_talk) ->
          {:error, :human_woke}

        true ->
          pack = %{
            peer: kai,
            session: after_talk,
            denied: :badge_required
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
