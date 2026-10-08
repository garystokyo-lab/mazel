defmodule Room.A2aDirectTalkBadgeMorph do
  @moduledoc """
  Resolve kai, Direct JSON-RPC talk, then badge mint unlocks morph.

  Talk first. Join after clearance. Distinct from
  a2a_direct_talk_no_badge (talk ok + morph denied),
  a2a_direct_talk (talk only), and
  agent_stay_direct_pull_badge (no A2A card resolve).
  Off Group / wiki / Trust / Consent LOOK restyle.
  """

  def look_resolve(rec \\ %{}), do: Room.A2aDirectTalk.look_resolve(rec)
  def look_direct, do: Room.A2aDirectTalk.look_direct()
  def look_talk, do: Room.A2aDirectTalk.look_talk()
  def look_badge, do: "ok  badge=mint"
  def look_join, do: "ok  morph=ok  join=ok"

  def look(pack) when is_map(pack) do
    [look_resolve(pack.hit), look_direct(), look_talk(), look_badge(), look_join()]
  end

  def look(_), do: look(%{hit: %{handle: "kai@mazel", card_url: Room.A2aCard.card_url("kai@mazel")}})

  @doc """
  Resolve + Direct JSON-RPC talk, then mint unlocks morph.
  Isolated. Sibling no_badge / talk / two_handle stay.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-direct-a2a-talk-badge-" <> random_id()

    with {:ok, prior} <- Room.A2aDirectTalk.demo(Keyword.put(opts, :context_id, prefix)),
         {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:error, :badge_required} <- Room.propose_morph(prefix, ariel),
         {:ok, badge} <- pull_stamp(ariel),
         {:ok, _} <- Room.submit_badge(prefix, badge),
         {:ok, _} <- Room.propose_morph(prefix, ariel),
         {:ok, _} <- Room.consent(prefix, ariel),
         {:ok, _} <- Room.consent(prefix, prior.peer),
         {:ok, joined} <- Room.commit_morph(prefix, "A2A Direct talk badge morph.", []) do
      prior_events = Enum.map(prior.session.events || [], & &1.type)
      later_events = Enum.map(joined.events || [], & &1.type)
      humans = Room.SessionPresence.humans(joined)
      agents = Room.SessionPresence.agents(joined)

      cond do
        prior.hit.handle != "kai@mazel" ->
          {:error, :resolve_miss}

        prior.hit.card_url != Room.A2aCard.card_url("kai@mazel") ->
          {:error, :resolve_miss}

        prior.sent.status != :ok or prior.sent.method != "message/send" ->
          {:error, :talk_miss}

        prior.session.badge != nil or "morph.commit" in prior_events ->
          {:error, :early_morph}

        prior.session.session_kind != :direct or joined.session_kind != :direct ->
          {:error, :not_direct}

        badge["source"] != "pull_match" or badge["kind"] != "pull_intent" ->
          {:error, :stamp_miss}

        joined.status != :morphed or not joined.dual_consent ->
          {:error, :morph_miss}

        "morph.commit" not in later_events ->
          {:error, :morph_miss}

        humans != ["ariel@mazel", "kai@mazel"] ->
          {:error, :human_miss}

        "ariel@mazel" not in agents or "kai@mazel" not in agents ->
          {:error, :agent_miss}

        look_badge() != "ok  badge=mint" ->
          {:error, :stamp_miss}

        look_join() != "ok  morph=ok  join=ok" ->
          {:error, :join_miss}

        true ->
          pack =
            Map.merge(prior, %{
              badge: badge,
              joined: joined,
              humans: humans,
              agents: agents
            })

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
