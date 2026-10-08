defmodule Room.SessionDirectFindOpenerCheckRetry do
  @moduledoc """
  Find→Direct: check fail, then corrected opener pass
  on the same Direct id.

  First agent talk starts after the retry. Distinct from
  session_direct_find_opener_check (cold pass),
  session_direct_find_opener_check_fail (fail only),
  and session_intro_opener_check_retry (Intro path).
  Direct 1-on-1 only. Off Group / wiki / Match-core /
  A2A / Trust / Consent mint-core.
  """

  @opener "hello"
  @agree "need: founders seeking series-a"
  @boast "claim: passionate visionary hunt for series-a"
  @deny "transcript: we do not do series-a"

  def opener, do: Room.MatchChatOpener.opener()

  def look_find(rec \\ %{}), do: Room.SessionDirectFindOpenerCheck.look_find(rec)
  def look_direct(id), do: Room.SessionDirectId.look_direct(id)
  def look_fail, do: Room.SessionIntroOpenerCheckRetry.look_fail()
  def look_pass(id, text \\ @opener), do: Room.SessionIntroOpenerCheckRetry.look_pass(id, text)
  def look_talk, do: Room.SessionDirectId.look_talk()
  def look_denied, do: Room.SessionDirectId.look_denied()

  def look(pack) when is_map(pack) do
    id = pack.open_id

    [
      look_find(pack.hit),
      look_direct(id),
      look_fail(),
      look_pass(id, pack[:opener] || opener()),
      look_talk(),
      look_denied()
    ]
  end

  def look(_), do: look(%{hit: %{}, open_id: "session-direct-a", opener: opener()})

  @doc """
  Find then Direct. Check fail. Same id, then pass + opener
  talk. Morph denied. Isolated. Sibling fail / pass stay.
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
         {:ok, fail} <- Room.NeedCheck.cast(:founder_investors, transcript: @boast),
         {:ok, contradict} <- Room.NeedCheck.cast(:founder_investors, transcript: @deny),
         {:error, :curious_talk} <- talk_if_pass(prefix, kai, fail),
         {:ok, after_fail} <- Room.get(prefix),
         {:ok, pass} <- Room.NeedCheck.cast(:founder_investors, transcript: @agree),
         {:ok, after_talk} <- talk_if_pass(prefix, kai, pass),
         {:error, :badge_required} <- Room.propose_morph(prefix, ariel) do
      fail_talks = Enum.filter(after_fail.events || [], &(&1.type == "talk"))
      talks = Enum.filter(after_talk.events || [], &(&1.type == "talk"))
      events = Enum.map(after_talk.events || [], & &1.type)
      opened_events = Enum.map(opened.events || [], & &1.type)
      fail_id = Room.SessionContext.id(after_fail)
      id = Room.SessionContext.id(after_talk)
      first = List.first(talks)

      cond do
        matched.hit.handle != "kai@mazel" ->
          {:error, :find_miss}

        opened.session_kind != :direct or after_talk.session_kind != :direct ->
          {:error, :not_direct}

        after_fail.session_kind != :direct ->
          {:error, :not_direct}

        id != prefix or fail_id != prefix or id == nil ->
          {:error, :id_miss}

        fail_id != id ->
          {:error, :id_drift}

        "talk" in opened_events ->
          {:error, :talk_early}

        fail.check == "pass" or not fail.unfit or fail.reason != "claim" ->
          {:error, :check_pass}

        not contradict.unfit or contradict.reason != "contradict" ->
          {:error, :contradict_fit}

        pass.check != "pass" or pass.unfit ->
          {:error, :check_miss}

        fail_talks != [] ->
          {:error, :talk_leaked}

        after_talk.badge != nil or "morph.commit" in events ->
          {:error, :morphed}

        length(talks) != 1 or after_talk.status != :open ->
          {:error, :talk_miss}

        first == nil or first.payload[:text] != opener() ->
          {:error, :opener_miss}

        humans_awake?(after_fail) or humans_awake?(after_talk) ->
          {:error, :human_woke}

        look_fail() != "error  check=fail  opener=none  talk=none" ->
          {:error, :check_miss}

        look_pass(id, opener()) != "ok  check=pass  opener=#{@opener}  id=#{id}  same=true" ->
          {:error, :check_miss}

        true ->
          pack = %{
            hit: matched.hit,
            matched: matched,
            session: after_talk,
            opened: opened,
            after_fail: after_fail,
            fail: fail,
            pass: pass,
            contradict: contradict,
            open_id: id,
            same: fail_id == id,
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