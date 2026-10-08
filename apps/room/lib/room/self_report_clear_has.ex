defmodule Room.SelfReportClearHas do
  @moduledoc """
  Clear Has while Need stays live. Find is none.

  No stale match. Distinct from self_report_clear /
  multi_need_clear (clear Need; Has may remain),
  self_report_empty (Has never present), and
  self_report_has_no_need (no Need). Off PDF / badge /
  GH / score / wiki / morph / toolbelt / talk-turns.
  """

  def look_need(rec \\ %{}), do: Room.SelfReportMatch.look_need(rec)
  def look_has(rec \\ %{}), do: Room.SelfReportMatch.look_has(rec)
  def look_find(rec \\ %{}), do: Room.SelfReportMatch.look_find(rec)
  def look_clear(_rec \\ %{}), do: "ok  clear=has  tags=[]"
  def look_miss, do: Room.SelfReportCurious.look_miss()
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [
      look_need(pack.need),
      look_has(pack.has),
      look_find(pack.hit),
      look_clear(pack.cleared),
      look_need(pack.need),
      look_miss(),
      look_complete()
    ]
  end

  def look(_), do: look(%{need: %{}, has: %{}, hit: %{}, cleared: %{}})

  @doc """
  Match, clear Has, Need stays, find none. Isolated.
  Sibling clear / empty / has_no_need LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-clear-has-" <> random_id()
    root = Keyword.get(opts, :root) || Path.join(System.tmp_dir!(), prefix)

    File.mkdir_p!(root)

    need = Room.SelfReportMatch.parse(Keyword.get(opts, :need) || "need: series-a")
    has = Room.SelfReportMatch.parse(Keyword.get(opts, :has) || "has: series-a")
    hit = Room.SelfReportMatch.match(has, need)

    with {:ok, _} <- Room.SelfReportMatch.put(root, need),
         {:ok, _} <- Room.SelfReportMatch.put(root, has),
         {:ok, found} <- Room.Find.query(hit.query || "series-a"),
         {:ok, cleared} <- Room.SelfReportMatch.drop(root, has),
         {:ok, session} <- keep_agent(prefix, hit) do
      missed = Room.SelfReportMatch.match(cleared, need)
      vaulted = Room.SelfReportMatch.find_vault(Room.SelfReportMatch.vault(root, :has), need)
      still_need = Room.SelfReportMatch.vault(root, :need)
      events = Enum.map(session.events || [], & &1.type)
      card = List.first(found[:hits] || [])

      cond do
        need.source != "self_report" or need.tags != ["series-a"] ->
          {:error, :need_miss}

        has.source != "self_report" or has.tags != ["series-a"] ->
          {:error, :has_miss}

        not hit.ok or hit.handle != "kai@mazel" ->
          {:error, :overlap_miss}

        cleared.tags != [] or cleared[:cleared] != true or cleared[:clear] != "has" ->
          {:error, :clear_miss}

        Room.SelfReportMatch.clear_has(need).tags != ["series-a"] ->
          {:error, :need_cleared}

        missed.ok or missed.tags != [] ->
          {:error, :stale_hit}

        vaulted.ok or vaulted.error != "empty" ->
          {:error, :stale_vault}

        Room.SelfReportMatch.vault_has_count(root) != 0 ->
          {:error, :has_lingers}

        still_need == [] or Room.SelfReportMatch.vault_need_count(root) != 1 ->
          {:error, :need_gone}

        is_nil(card) or card.handle != "kai@mazel" ->
          {:error, :find_miss}

        session.status != :open or session.badge != nil or "morph.commit" in events ->
          {:error, :session_miss}

        "talk" in events ->
          {:error, :talked}

        humans_awake?(session) ->
          {:error, :human_woke}

        true ->
          pack = %{
            need: need,
            has: has,
            hit: hit,
            cleared: cleared,
            missed: missed,
            vaulted: vaulted,
            find: found,
            session: session,
            complete: :agent,
            root: root
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp keep_agent(id, hit) do
    peer = hit[:handle] || "kai@mazel"

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup(peer) do
      Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}])
    end
  end

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
