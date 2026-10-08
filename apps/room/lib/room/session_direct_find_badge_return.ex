defmodule Room.SessionDirectFindBadgeReturn do
  @moduledoc """
  After find, Direct with badge present morphs then returns.

  Same Direct id. Human talk while morphed. Return-to-agent.
  Distinct from session_direct_after_find (morph denied,
  no badge), session_direct_after_find_return (Add→paste
  + mint strip), and match_chat_return (return after match
  talk; no badge/morph.commit / id=). Direct 1-on-1 only.
  Off Group / wiki / Match-core / A2A / Trust.
  """

  def look_find(rec \\ %{}), do: Room.SelfReportMatch.look_find(rec)
  def look_direct(id), do: Room.SessionDirectId.look_direct(id)
  def look_badge, do: "ok  badge=present  morph=morph.commit"
  def look_talk, do: "ok  talk=@kai  human=1  turn=1"
  def look_return(id), do: "ok  return=agent  id=#{id}  same=true"

  def look(pack) when is_map(pack) do
    [
      look_find(pack.hit),
      look_direct(pack.open_id),
      look_badge(),
      look_talk(),
      look_return(pack.open_id)
    ]
  end

  def look(_), do: look(%{hit: %{}, open_id: "session-direct-a"})

  @doc """
  Find then Direct with badge present. Morph, human talk,
  return same id. Isolated. Sibling after_find / return /
  match_chat_return stay.
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
         {:ok, badge} <- pull_stamp(ariel),
         {:ok, stamped} <- Room.submit_badge(prefix, badge),
         {:ok, _} <- Room.propose_morph(prefix, ariel),
         {:ok, _} <- Room.consent(prefix, ariel),
         {:ok, _} <- Room.consent(prefix, kai),
         {:ok, morphed} <- Room.commit_morph(prefix, "Find Direct badge return.", []),
         {:ok, human_talk} <- Room.talk(prefix, kai, "hello from human"),
         {:ok, wrapped} <- Room.Return.wrap(prefix) do
      id = Room.SessionContext.id(opened)
      humans = Room.SessionPresence.humans(morphed)
      after_humans = Room.SessionPresence.humans(human_talk)
      back_humans = Room.SessionPresence.humans(wrapped)
      talks = Enum.filter(human_talk.events || [], &(&1.type == "talk"))
      opened_events = Enum.map(opened.events || [], & &1.type)

      cond do
        matched.hit.handle != "kai@mazel" ->
          {:error, :find_miss}

        opened.session_kind != :direct or opened.badge != nil ->
          {:error, :not_direct}

        "morph.commit" in opened_events ->
          {:error, :early_morph}

        stamped.badge == nil ->
          {:error, :badge_miss}

        badge["source"] != "pull_match" or badge["kind"] != "pull_intent" ->
          {:error, :stamp_miss}

        morphed.status != :morphed or not morphed.dual_consent ->
          {:error, :morph_miss}

        humans != ["ariel@mazel", "kai@mazel"] ->
          {:error, :human_miss}

        human_talk.status != :morphed or after_humans != ["ariel@mazel", "kai@mazel"] ->
          {:error, :talk_miss}

        length(talks) != 1 ->
          {:error, :talk_miss}

        wrapped.status != :returned or wrapped.session != "agent" or wrapped.morph != "closed" ->
          {:error, :return_miss}

        wrapped.session_kind != :direct ->
          {:error, :not_direct}

        Room.SessionContext.id(wrapped) != id or id != prefix ->
          {:error, :id_drift}

        not Room.SessionContext.same?(opened, wrapped) ->
          {:error, :id_drift}

        back_humans != [] ->
          {:error, :human_lingers}

        true ->
          pack = %{
            hit: matched.hit,
            matched: matched,
            session: opened,
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
