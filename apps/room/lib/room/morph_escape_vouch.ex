defmodule Room.MorphEscapeVouch do
  @moduledoc """
  Vouch stamp opens the morph escape hatch.

  Same in-agent complete default. stamp=none stays soft_no /
  asleep. Other-vouch + dual consent → morph.commit + return.
  Self-vouch still fails. Distinct from morph_escape (pull_match)
  and morph_escape_invite (invite). Not Needs-import.
  """

  def look_find, do: "ok  find=series-a→kai@mazel  mazel'd @kai"

  def look_complete, do: "ok  complete=agent  morph=none  session=agent"

  def look_denied, do: "error  escape=human  stamp=none  agent=soft_no  human=asleep"

  def look_escape(badge \\ %{}) do
    source = badge["source"] || badge[:source] || "vouch"
    kind = badge["kind"] || badge[:kind] || "vouch"
    "ok  escape=human  stamp=#{source}  badge=#{kind}  consent=dual"
  end

  def look_morph, do: "ok  morph=morph.commit"

  def look_warm, do: "warm  from=ariel@mazel  peer=kai@mazel"

  def look_return, do: "ok  return=agent  morph=closed  session=agent"

  def look(pack) when is_map(pack) do
    [
      look_find(),
      look_complete(),
      look_denied(),
      look_escape(pack.badge),
      look_morph(),
      look_warm(),
      look_return()
    ]
  end

  def look(_), do: look(%{badge: %{}})

  @doc """
  Other-vouch postage opens the hatch. Isolated.
  pull_match / invite sibling LOOK stays. Self-vouch stays closed.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "morph-escape-vouch-" <> random_id()

    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-morph-escape-vouch-#{System.unique_integer([:positive])}")
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
         {:error, :self_vouch} <-
           Room.Badge.mint(:vouch, voucher: kai, subject: kai, note: "I know me."),
         {:ok, session} <- keep_agent(prefix <> "-stay", ariel, kai),
         {:ok, none} <- keep_agent(prefix <> "-none", ariel, kai),
         {:ok, :soft_no} <- Room.SoftNo.agent(none),
         {:error, :human_asleep} <- Room.SoftNo.wake(none),
         {:error, :badge_required} <- Room.propose_morph(prefix <> "-none", ariel),
         {:ok, badge} <-
           Room.Badge.mint(:vouch, voucher: ariel, subject: kai, note: "vouch-from-other"),
         {:ok, state} <- escape_human(prefix <> "-go", ariel, kai, badge),
         {:ok, wrapped} <- Room.Return.wrap(state.context_id) do
      hit = List.first(found[:hits] || [])
      events = Enum.map(session.events || [], & &1.type)
      last = state.events |> Enum.map(& &1.type) |> List.last()

      cond do
        is_nil(hit) or hit.handle != "kai@mazel" ->
          {:error, :find_miss}

        not match.ok or match.handle != "kai@mazel" ->
          {:error, :match_miss}

        session.status != :open or session.badge != nil or "morph.commit" in events ->
          {:error, :stay_morphed}

        humans_awake?(session) or humans_awake?(none) ->
          {:error, :human_woke}

        badge["source"] != "vouch" or badge["kind"] != "vouch" ->
          {:error, :vouch_miss}

        last != "morph.commit" or not state.dual_consent ->
          {:error, :no_commit}

        wrapped.status != :returned or wrapped.morph != "closed" or wrapped.session != "agent" ->
          {:error, :no_return}

        "pow" in Room.Badge.mint_sources() ->
          {:error, :pow_in_sources}

        Room.Badge.mint_sources() != ~w(pull_match vouch invite) ->
          {:error, :mint_sources}

        true ->
          pack = %{
            find: found,
            match: match,
            session: session,
            none: none,
            badge: badge,
            state: state,
            wrapped: wrapped,
            complete: :agent,
            self: :self_vouch
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp keep_agent(id, ariel, kai) do
    Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}])
  end

  defp escape_human(id, ariel, kai, badge) do
    excerpt = [%{text: "Ariel is up."}]

    with {:ok, _} <- keep_agent(id, ariel, kai),
         {:ok, _} <- Room.submit_badge(id, badge),
         {:ok, _} <- Room.propose_morph(id, ariel),
         {:ok, _} <- Room.consent(id, ariel),
         {:ok, _} <- Room.consent(id, kai) do
      Room.commit_morph(id, "Human needed. Vouch opened the hatch.", excerpt)
    end
  end

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
