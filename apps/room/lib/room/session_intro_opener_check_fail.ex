defmodule Room.SessionIntroOpenerCheckFail do
  @moduledoc """
  Intro: prompt-check fail blocks first agent talk.

  Negative of session_intro_opener_check (check=pass +
  opener talk). Claim / contradict stay talk=none.
  Distinct from session_intro_id (talk, no check),
  session_intro_no_badge (agent=1 / join blocked),
  session_direct_find_opener_check_fail (find→Direct),
  and match_chat_opener / match_chat_check (match path).
  Intro 1-on-1 only. Off Group / wiki / Match-core / A2A /
  Trust / Consent mint-core.
  """

  @boast "claim: passionate visionary hunt for series-a"
  @deny "transcript: we do not do series-a"

  def opener, do: Room.MatchChatOpener.opener()

  def look_intro(id), do: Room.SessionIntroId.look_intro(id)
  def look_check, do: Room.SessionDirectFindOpenerCheckFail.look_check()
  def look_talk, do: Room.SessionDirectFindOpenerCheckFail.look_talk()
  def look_denied, do: Room.SessionIntroId.look_denied()

  def look(pack) when is_map(pack) do
    [
      look_intro(pack.open_id),
      look_check(),
      look_talk(),
      look_denied()
    ]
  end

  def look(_), do: look(%{open_id: "session-intro-a"})

  @doc """
  Intro ask. Check fail. No opener talk. Morph denied.
  Isolated. Sibling intro_id / opener_check / no_badge stay.
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
         {:error, :badge_required} <- Room.propose_morph(prefix, asked.speaker),
         {:ok, after_fail} <- Room.get(prefix) do
      talks = Enum.filter(after_fail.events || [], &(&1.type == "talk"))
      events = Enum.map(after_fail.events || [], & &1.type)
      opened_events = Enum.map(asked.session.events || [], & &1.type)
      id = Room.SessionContext.id(after_fail)

      cond do
        asked.cmd.session_kind != :intro or after_fail.session_kind != :intro ->
          {:error, :not_intro}

        id != prefix or id == nil ->
          {:error, :id_miss}

        "talk" in opened_events ->
          {:error, :talk_early}

        fail.check == "pass" or not fail.unfit or fail.reason != "claim" ->
          {:error, :check_pass}

        not contradict.unfit or contradict.reason != "contradict" ->
          {:error, :contradict_fit}

        after_fail.badge != nil or "morph.commit" in events ->
          {:error, :morphed}

        talks != [] or after_fail.status != :open ->
          {:error, :talk_leaked}

        humans_awake?(after_fail) ->
          {:error, :human_woke}

        look_check() != "error  check=fail  opener=none" ->
          {:error, :check_miss}

        look_talk() != "error  talk=none" ->
          {:error, :talk_miss}

        true ->
          pack = %{
            cmd: asked.cmd,
            session: after_fail,
            opened: asked.session,
            peer: asked.peer,
            fail: fail,
            contradict: contradict,
            open_id: id,
            opener: nil,
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
