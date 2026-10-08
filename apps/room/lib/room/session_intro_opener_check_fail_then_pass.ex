defmodule Room.SessionIntroOpenerCheckFailThenPass do
  @moduledoc """
  Intro: check fail, then corrected opener pass on same id.

  First agent talk starts after the fix. Distinct from
  session_intro_opener_check (pass only),
  session_intro_opener_check_fail (fail only),
  session_intro_id (talk, no check), session_intro_no_badge
  (agent=1), and session_direct_find_opener_check_fail
  (find→Direct). Intro 1-on-1 only. Off Group / wiki /
  Match-core / A2A / Trust / Consent mint-core.
  """

  @opener "hello"
  @agree "need: founders seeking series-a"
  @boast "claim: passionate visionary hunt for series-a"
  @deny "transcript: we do not do series-a"

  def opener, do: Room.MatchChatOpener.opener()

  def look_intro(id), do: Room.SessionIntroId.look_intro(id)
  def look_fail, do: Room.SessionIntroOpenerCheckFail.look_check()
  def look_none, do: Room.SessionIntroOpenerCheckFail.look_talk()
  def look_pass(text \\ @opener), do: Room.SessionIntroOpenerCheck.look_check(text)
  def look_talk, do: Room.SessionIntroId.look_talk()
  def look_denied, do: Room.SessionIntroId.look_denied()

  def look(pack) when is_map(pack) do
    [
      look_intro(pack.open_id),
      look_fail(),
      look_none(),
      look_pass(pack[:opener] || opener()),
      look_talk(),
      look_denied()
    ]
  end

  def look(_), do: look(%{open_id: "session-intro-a", opener: opener()})

  @doc """
  Intro ask. Check fail. Same id, then pass + opener talk.
  Morph denied. Isolated. Sibling fail / pass stay.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-intro-" <> random_id()

    with {:ok, asked} <-
           Room.SessionIntro.ask(
             command: Keyword.get(opts, :command) || Room.SessionIntro.command(),
             context_id: prefix
           ),
         {:ok, fail} <- Room.NeedCheck.cast(:founder_investors, transcript: @boast),
         {:ok, contradict} <- Room.NeedCheck.cast(:founder_investors, transcript: @deny),
         {:error, :curious_talk} <- talk_if_pass(prefix, asked.peer, fail),
         {:ok, after_fail} <- Room.get(prefix),
         {:ok, pass} <- Room.NeedCheck.cast(:founder_investors, transcript: @agree),
         {:ok, after_talk} <- talk_if_pass(prefix, asked.peer, pass),
         {:error, :badge_required} <- Room.propose_morph(prefix, asked.speaker) do
      fail_talks = Enum.filter(after_fail.events || [], &(&1.type == "talk"))
      talks = Enum.filter(after_talk.events || [], &(&1.type == "talk"))
      events = Enum.map(after_talk.events || [], & &1.type)
      opened_events = Enum.map(asked.session.events || [], & &1.type)
      fail_id = Room.SessionContext.id(after_fail)
      id = Room.SessionContext.id(after_talk)
      first = List.first(talks)

      cond do
        asked.cmd.session_kind != :intro or after_talk.session_kind != :intro ->
          {:error, :not_intro}

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

        look_fail() != "error  check=fail  opener=none" ->
          {:error, :check_miss}

        look_none() != "error  talk=none" ->
          {:error, :talk_miss}

        look_pass(opener()) != "ok  check=pass  opener=#{@opener}" ->
          {:error, :check_miss}

        true ->
          pack = %{
            cmd: asked.cmd,
            session: after_talk,
            opened: asked.session,
            after_fail: after_fail,
            peer: asked.peer,
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

  defp talk_if_pass(_id, _peer, %{unfit: true}), do: {:error, :curious_talk}

  defp talk_if_pass(id, peer, %{check: "pass"}) do
    Room.talk(id, peer, opener())
  end

  defp talk_if_pass(_, _, _), do: {:error, :check_miss}

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
