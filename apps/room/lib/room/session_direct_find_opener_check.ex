defmodule Room.SessionDirectFindOpenerCheck do
  @moduledoc """
  Find→Direct: prompt-check + opener before first agent talk.

  check=pass opens one talk. Claim / contradict stay talk=none.
  Distinct from session_direct_after_find (no opener/check),
  match_chat_opener / match_chat_check (match path, not
  find→Direct), and session_direct_find_badge_return
  (badge/morph/return). Direct 1-on-1 only. Off Group /
  wiki / Match-core / A2A / Trust / Consent mint-core.
  """

  @opener "hello"
  @agree "need: founders seeking series-a"
  @boast "claim: passionate visionary hunt for series-a"
  @deny "transcript: we do not do series-a"

  def opener, do: Room.MatchChatOpener.opener()

  def look_find(rec \\ %{}), do: Room.SessionDirectFindBadgeReturn.look_find(rec)
  def look_direct(id), do: Room.SessionDirectId.look_direct(id)
  def look_check(text \\ @opener), do: "ok  check=pass  opener=#{text}"
  def look_talk, do: Room.SessionDirectId.look_talk()
  def look_denied, do: Room.SessionDirectId.look_denied()

  def look(pack) when is_map(pack) do
    [
      look_find(pack.hit),
      look_direct(pack.open_id),
      look_check(pack[:opener] || opener()),
      look_talk(),
      look_denied()
    ]
  end

  def look(_), do: look(%{hit: %{}, open_id: "session-direct-a", opener: opener()})

  @doc """
  Find then Direct. Check pass + opener talk. Morph denied.
  Isolated. Sibling after_find / opener / check / badge stay.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-direct-" <> random_id()

    with {:ok, matched} <- Room.SelfReportMatch.demo(context_id: prefix <> "-find"),
         {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup(matched.hit.handle || "@kai"),
         {:ok, opened} <-
           Room.open(prefix, :direct, [
             %{handle: ariel, role: :agent},
             %{handle: kai, role: :agent}
           ]),
         {:ok, pass} <- Room.NeedCheck.cast(:founder_investors, transcript: @agree),
         {:ok, claim} <- Room.NeedCheck.cast(:founder_investors, transcript: @boast),
         {:ok, contradict} <- Room.NeedCheck.cast(:founder_investors, transcript: @deny),
         {:ok, after_talk} <- talk_if_pass(prefix, kai, pass),
         {:error, :badge_required} <- Room.propose_morph(prefix, ariel) do
      talks = Enum.filter(after_talk.events || [], &(&1.type == "talk"))
      events = Enum.map(after_talk.events || [], & &1.type)
      opened_events = Enum.map(opened.events || [], & &1.type)
      id = Room.SessionContext.id(after_talk)
      first = List.first(talks)

      cond do
        matched.hit.handle != "kai@mazel" ->
          {:error, :find_miss}

        opened.session_kind != :direct or after_talk.session_kind != :direct ->
          {:error, :not_direct}

        id != prefix or id == nil ->
          {:error, :id_miss}

        "talk" in opened_events ->
          {:error, :talk_early}

        pass.check != "pass" or pass.unfit ->
          {:error, :check_miss}

        not claim.unfit or claim.reason != "claim" ->
          {:error, :claim_fit}

        not contradict.unfit or contradict.reason != "contradict" ->
          {:error, :contradict_fit}

        after_talk.badge != nil or "morph.commit" in events ->
          {:error, :morphed}

        length(talks) != 1 or after_talk.status != :open ->
          {:error, :talk_miss}

        first == nil or first.payload[:text] != opener() ->
          {:error, :opener_miss}

        humans_awake?(after_talk) ->
          {:error, :human_woke}

        look_check(opener()) != "ok  check=pass  opener=#{@opener}" ->
          {:error, :check_miss}

        true ->
          pack = %{
            hit: matched.hit,
            matched: matched,
            session: after_talk,
            opened: opened,
            pass: pass,
            claim: claim,
            contradict: contradict,
            open_id: id,
            opener: opener(),
            denied: :badge_required
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp talk_if_pass(_id, _kai, %{unfit: true}), do: {:error, :curious_talk}

  defp talk_if_pass(id, kai, %{check: "pass"}) do
    Room.talk(id, kai, opener())
  end

  defp talk_if_pass(_, _, _), do: {:error, :check_miss}

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
