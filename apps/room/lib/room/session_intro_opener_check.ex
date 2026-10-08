defmodule Room.SessionIntroOpenerCheck do
  @moduledoc """
  Intro: prompt-check + opener before first agent talk.

  Mirror of session_direct_find_opener_check (Direct pass).
  check=pass opens one talk. Claim / contradict stay talk=none.
  Distinct from session_intro_id (talk, no check),
  session_intro_no_badge (agent=1 / join blocked),
  session_direct_find_opener_check (find→Direct), and
  match_chat_opener / match_chat_check (match path).
  Intro 1-on-1 only. Off Group / wiki / Match-core / A2A /
  Trust / Consent mint-core.
  """

  @opener "hello"
  @agree "need: founders seeking series-a"
  @boast "claim: passionate visionary hunt for series-a"
  @deny "transcript: we do not do series-a"

  def opener, do: Room.MatchChatOpener.opener()

  def look_intro(id), do: Room.SessionIntroId.look_intro(id)
  def look_check(text \\ @opener), do: Room.SessionDirectFindOpenerCheck.look_check(text)
  def look_talk, do: Room.SessionIntroId.look_talk()
  def look_denied, do: Room.SessionIntroId.look_denied()

  def look(pack) when is_map(pack) do
    [
      look_intro(pack.open_id),
      look_check(pack[:opener] || opener()),
      look_talk(),
      look_denied()
    ]
  end

  def look(_), do: look(%{open_id: "session-intro-a", opener: opener()})

  @doc """
  Intro ask. Check pass + opener talk. Morph denied.
  Isolated. Sibling intro_id / opener_check / no_badge stay.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-intro-" <> random_id()

    with {:ok, asked} <-
           Room.SessionIntro.ask(
             command: Keyword.get(opts, :command) || Room.SessionIntro.command(),
             context_id: prefix
           ),
         {:ok, pass} <- Room.NeedCheck.cast(:founder_investors, transcript: @agree),
         {:ok, claim} <- Room.NeedCheck.cast(:founder_investors, transcript: @boast),
         {:ok, contradict} <- Room.NeedCheck.cast(:founder_investors, transcript: @deny),
         {:ok, after_talk} <- talk_if_pass(prefix, asked.peer, pass),
         {:error, :badge_required} <- Room.propose_morph(prefix, asked.speaker) do
      talks = Enum.filter(after_talk.events || [], &(&1.type == "talk"))
      events = Enum.map(after_talk.events || [], & &1.type)
      opened_events = Enum.map(asked.session.events || [], & &1.type)
      id = Room.SessionContext.id(after_talk)
      first = List.first(talks)

      cond do
        asked.cmd.session_kind != :intro or after_talk.session_kind != :intro ->
          {:error, :not_intro}

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
            cmd: asked.cmd,
            session: after_talk,
            opened: asked.session,
            peer: asked.peer,
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
