defmodule Room.SessionIntroBadgeReturn do
  @moduledoc """
  Intro ask with badge present morphs, then returns same id.

  Human talk while morphed. Return-to-agent. Distinct from
  session_intro_id (morph denied, no badge),
  session_direct_find_badge_return (Direct, not Intro),
  and intro_e2e (mint/warm; no id= / same=true).
  Intro 1-on-1 only. Off Group / wiki / Match-core / A2A / Trust.
  """

  def look_intro(id), do: Room.SessionIntroId.look_intro(id)
  def look_badge, do: Room.SessionDirectFindBadgeReturn.look_badge()
  def look_talk, do: Room.SessionDirectFindBadgeReturn.look_talk()
  def look_return(id), do: Room.SessionDirectFindBadgeReturn.look_return(id)

  def look(pack) when is_map(pack) do
    [look_intro(pack.open_id), look_badge(), look_talk(), look_return(pack.open_id)]
  end

  def look(_), do: look(%{open_id: "session-intro-a"})

  @doc """
  Intro ask, badge present, morph, human talk, return same id.
  Isolated. Sibling intro_id / Direct find-badge / e2e stay.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-intro-" <> random_id()

    with {:ok, asked} <-
           Room.SessionIntro.ask(
             command: Keyword.get(opts, :command) || Room.SessionIntro.command(),
             context_id: prefix
           ),
         {:ok, badge} <- pull_stamp(asked.speaker),
         {:ok, stamped} <- Room.submit_badge(prefix, badge),
         {:ok, _} <- Room.propose_morph(prefix, asked.speaker),
         {:ok, _} <- Room.consent(prefix, asked.speaker),
         {:ok, _} <- Room.consent(prefix, asked.peer),
         {:ok, morphed} <- Room.commit_morph(prefix, "Intro badge return.", []),
         {:ok, human_talk} <- Room.talk(prefix, asked.peer, "hello from human"),
         {:ok, wrapped} <- Room.Return.wrap(prefix) do
      id = Room.SessionContext.id(asked.session)
      humans = Room.SessionPresence.humans(morphed)
      after_humans = Room.SessionPresence.humans(human_talk)
      back_humans = Room.SessionPresence.humans(wrapped)
      talks = Enum.filter(human_talk.events || [], &(&1.type == "talk"))
      asked_events = Enum.map(asked.session.events || [], & &1.type)

      cond do
        asked.cmd.session_kind != :intro or asked.session.session_kind != :intro ->
          {:error, :not_intro}

        asked.session.badge != nil or "morph.commit" in asked_events ->
          {:error, :early_morph}

        stamped.badge == nil ->
          {:error, :badge_miss}

        badge["source"] != "pull_match" or badge["kind"] != "pull_intent" ->
          {:error, :stamp_miss}

        morphed.status != :morphed or not morphed.dual_consent ->
          {:error, :morph_miss}

        morphed.session_kind != :intro ->
          {:error, :not_intro}

        humans != ["ariel@mazel", "kai@mazel"] ->
          {:error, :human_miss}

        human_talk.status != :morphed or after_humans != ["ariel@mazel", "kai@mazel"] ->
          {:error, :talk_miss}

        length(talks) != 1 ->
          {:error, :talk_miss}

        wrapped.status != :returned or wrapped.session != "agent" or wrapped.morph != "closed" ->
          {:error, :return_miss}

        wrapped.session_kind != :intro ->
          {:error, :not_intro}

        Room.SessionContext.id(wrapped) != id or id != prefix ->
          {:error, :id_drift}

        not Room.SessionContext.same?(asked.session, wrapped) ->
          {:error, :id_drift}

        back_humans != [] ->
          {:error, :human_lingers}

        true ->
          pack = %{
            cmd: asked.cmd,
            session: asked.session,
            badge: badge,
            stamped: stamped,
            morphed: morphed,
            human_talk: human_talk,
            wrapped: wrapped,
            open_id: id
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
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
