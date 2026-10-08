defmodule Room.MorphEscapeOneConsent do
  @moduledoc """
  One consent on the morph escape hatch stays soft_no.

  Same in-agent complete default. Stamp + one grant is not
  dual — morph denied, human stays asleep. Distinct from
  morph_escape (consent=dual → morph.commit) and
  consent_soft_no (no find / complete=agent). Not Needs-import.
  """

  def look_find, do: "ok  find=series-a→kai@mazel  mazel'd @kai"

  def look_complete, do: "ok  complete=agent  morph=none  session=agent"

  def look_escape(badge \\ %{}) do
    source = badge["source"] || badge[:source] || "pull_match"
    kind = badge["kind"] || badge[:kind] || "pull_intent"
    "ok  escape=human  stamp=#{source}  badge=#{kind}  consent=one"
  end

  def look_denied, do: "error  morph=denied  agent=soft_no  human=asleep"

  def look(pack) when is_map(pack) do
    [look_find(), look_complete(), look_escape(pack.badge), look_denied()]
  end

  def look(_), do: look(%{badge: %{}})

  @doc """
  Pull stamp + one consent does not open the hatch. Isolated.
  Dual sibling LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "morph-escape-one-" <> random_id()

    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path =
            Path.join(System.tmp_dir!(), "mazel-morph-escape-one-#{System.unique_integer([:positive])}")

          File.mkdir_p!(Path.join(path, "index/has"))
          {path, true}
      end

    try do
      demo_on(root, prefix)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp demo_on(root, prefix) do
    File.cp!(
      Path.join(Room.Index.repo_root(), "index/has/kai.md"),
      Path.join(root, "index/has/kai.md")
    )

    agree = "need: founders seeking series-a"

    with {:ok, found} <- Room.Find.query("series-a"),
         {:ok, need} <- Room.NeedCheck.cast(:founder_investors, transcript: agree),
         {:ok, match} <- Room.Need.match_has(need, root: root, transcript: agree),
         {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
         {:ok, session} <- keep_agent(prefix <> "-stay", ariel, kai),
         {:ok, badge} <- pull_stamp(ariel),
         {:ok, one} <- escape_one(prefix <> "-one", ariel, kai, badge),
         {:ok, :soft_no} <- Room.ConsentSoftNo.agent(one),
         {:error, :human_asleep} <- Room.ConsentSoftNo.wake(one) do
      denied =
        case Room.commit_morph(one.context_id, "one consent is not enough", []) do
          {:error, :dual_consent_required} -> :dual_consent_required
          other -> other
        end

      hit = List.first(found[:hits] || [])
      events = Enum.map(session.events || [], & &1.type)
      one_events = Enum.map(one.events || [], & &1.type)

      cond do
        is_nil(hit) or hit.handle != "kai@mazel" ->
          {:error, :find_miss}

        not match.ok or match.handle != "kai@mazel" ->
          {:error, :match_miss}

        session.status != :open or session.badge != nil or "morph.commit" in events ->
          {:error, :stay_morphed}

        badge["source"] != "pull_match" or badge["kind"] != "pull_intent" ->
          {:error, :stamp_miss}

        one.dual_consent or "morph.commit" in one_events ->
          {:error, :one_committed}

        denied != :dual_consent_required ->
          {:error, :one_committed}

        humans_awake?(session) or humans_awake?(one) ->
          {:error, :human_woke}

        true ->
          pack = %{
            find: found,
            match: match,
            session: session,
            badge: badge,
            one: one,
            denied: denied,
            complete: :agent
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp keep_agent(id, ariel, kai) do
    Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}])
  end

  defp escape_one(id, ariel, kai, badge) do
    with {:ok, _} <- keep_agent(id, ariel, kai),
         {:ok, _} <- Room.submit_badge(id, badge),
         {:ok, _} <- Room.propose_morph(id, ariel),
         {:ok, one} <- Room.consent(id, ariel) do
      {:ok, one}
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

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
