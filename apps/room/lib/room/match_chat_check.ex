defmodule Room.MatchChatCheck do
  @moduledoc """
  Prompt-check before match-chat talk opens.

  check=pass → one talk each. Claim / contradict → talk=none.
  Distinct from match_chat_* (no check gate) and prompt_check /
  agent_complete_check (no match→talk path). Not wiki / GH.
  """

  def look_has(rec \\ %{}), do: Room.MatchChat.look_has(rec)
  def look_need(rec \\ %{}), do: Room.MatchChat.look_need(rec)
  def look_find(rec \\ %{}), do: Room.MatchChat.look_find(rec)
  def look_talk(rec \\ %{}, n \\ 1), do: Room.MatchChat.look_talk(rec, n)

  def look_pass, do: "ok  check=pass"
  def look_claim, do: "error  claim→curious  talk=none"
  def look_contradict, do: "error  contradict→curious  talk=none"

  def look(pack) when is_map(pack) do
    [
      look_has(pack.has),
      look_need(pack.need),
      look_find(pack.hit),
      look_pass(),
      look_talk(pack.turn_a, 1),
      look_talk(pack.turn_b, 1),
      look_claim(),
      look_contradict()
    ]
  end

  def look(_),
    do: look(%{has: %{}, need: %{}, hit: %{}, turn_a: %{local: "ariel"}, turn_b: %{local: "kai"}})

  @agree "need: founders seeking series-a"
  @boast "claim: passionate visionary hunt for series-a"
  @deny "transcript: we do not do series-a"

  @doc """
  Self-report match, then check. Pass talks. Curious never chats.
  Isolated. Sibling match-chat / prompt-check LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "match-chat-check-" <> random_id()

    with {:ok, matched} <- Room.SelfReportMatch.demo(context_id: prefix),
         {:ok, pass} <- Room.NeedCheck.cast(:founder_investors, transcript: @agree),
         {:ok, claim} <- Room.NeedCheck.cast(:founder_investors, transcript: @boast),
         {:ok, contradict} <- Room.NeedCheck.cast(:founder_investors, transcript: @deny),
         {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup(matched.hit.handle || "@kai"),
         {:ok, session} <- talk_if_pass(matched.session.context_id, ariel, kai, pass) do
      talks = Enum.filter(session.events || [], &(&1.type == "talk"))

      cond do
        matched.has.source != "self_report" ->
          {:error, :not_self_report}

        pass.check != "pass" or pass.unfit ->
          {:error, :check_miss}

        not claim.unfit or claim.reason != "claim" ->
          {:error, :claim_fit}

        not contradict.unfit or contradict.reason != "contradict" ->
          {:error, :contradict_fit}

        length(talks) != 2 ->
          {:error, :talk_miss}

        true ->
          pack = %{
            has: matched.has,
            need: matched.need,
            hit: matched.hit,
            turn_a: %{handle: ariel.id, local: "ariel"},
            turn_b: %{handle: kai.id, local: "kai"},
            session: session,
            pass: pass,
            claim: claim,
            contradict: contradict
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp talk_if_pass(_id, _ariel, _kai, %{unfit: true}), do: {:error, :curious_talk}

  defp talk_if_pass(id, ariel, kai, %{check: "pass"}) do
    with {:ok, _} <- Room.talk(id, ariel, "series-a"),
         {:ok, state} <- Room.talk(id, kai, "has") do
      {:ok, state}
    end
  end

  defp talk_if_pass(_, _, _, _), do: {:error, :check_miss}

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
