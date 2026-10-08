defmodule Room.SelfReportNeedMultiTag do
  @moduledoc """
  One Need with two tags hits Has on any shared tag.

  tags=[series-a,cto] × Has [series-a] → overlap=[series-a].
  Distinct from self_report_multi_need (two Need
  objects), self_report_overlap (Has multi / Need
  single), and self_report_match (exact single tag).
  Off PDF / badge / GH / score / wiki / morph /
  toolbelt / talk-turns.
  """

  def look_need(rec \\ %{}), do: Room.SelfReportMatch.look_need(rec)
  def look_has(rec \\ %{}), do: Room.SelfReportMatch.look_has(rec)
  def look_overlap(rec \\ %{}), do: Room.SelfReportOverlap.look_overlap(rec)
  def look_find(rec \\ %{}), do: Room.SelfReportMatch.look_find(rec)
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [
      look_need(pack.need),
      look_has(pack.has),
      look_overlap(pack.hit),
      look_find(pack.hit),
      look_complete()
    ]
  end

  def look(_), do: look(%{need: %{tags: ["series-a", "cto"]}, has: %{}, hit: %{}})

  @doc """
  Multi-tag Need × single Has. Any-tag hit. Isolated.
  Sibling multi_need / overlap / match LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-need-multi-tag-" <> random_id()

    need = Room.SelfReportMatch.parse(Keyword.get(opts, :need) || "need: series-a, cto")
    has = Room.SelfReportMatch.parse(Keyword.get(opts, :has) || "has: series-a")
    reported = Room.SelfReportMatch.report(:need, ["series-a", "cto"])
    hit = Room.SelfReportMatch.match(has, need)
    shared = Room.SelfReportMatch.overlap(has, need)

    with {:ok, found} <- Room.Find.query(hit.query || "series-a"),
         {:ok, session} <- keep_agent(prefix, hit) do
      card = List.first(found[:hits] || [])
      events = Enum.map(session.events || [], & &1.type)

      cond do
        need.source != "self_report" or has.source != "self_report" ->
          {:error, :not_self_report}

        need.tags != ["series-a", "cto"] or reported.tags != ["series-a", "cto"] ->
          {:error, :need_miss}

        has.tags != ["series-a"] ->
          {:error, :has_miss}

        shared != ["series-a"] or hit.tags != ["series-a"] ->
          {:error, :overlap_miss}

        not hit.ok or hit.handle != "kai@mazel" or hit.query != "series-a" ->
          {:error, :overlap_miss}

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
            reported: reported,
            hit: hit,
            find: found,
            session: session,
            complete: :agent
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
