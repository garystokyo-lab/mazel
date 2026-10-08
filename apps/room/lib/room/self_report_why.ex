defmodule Room.SelfReportWhy do
  @moduledoc """
  Double-magic why on a self-report tag match.

  why need= / why has= from overlapping tags. No score.
  Distinct from self_report_match / self_report_overlap
  (no why). Not proof. Off wiki.
  """

  def look_has(rec \\ %{}), do: Room.SelfReportMatch.look_has(rec)
  def look_need(rec \\ %{}), do: Room.SelfReportMatch.look_need(rec)
  def look_find(rec \\ %{}), do: Room.SelfReportMatch.look_find(rec)
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look_why(rec \\ %{}) do
    id = rec[:why_need] || rec[:why_has] || List.first(List.wrap(rec[:tags])) || "series-a"
    ["why  need=#{id}", "why  has=#{rec[:why_has] || id}"]
  end

  def look(pack) when is_map(pack) do
    [look_has(pack.has), look_need(pack.need), look_find(pack.hit)] ++
      look_why(pack.why) ++ [look_complete()]
  end

  def look(_), do: look(%{has: %{}, need: %{}, hit: %{}, why: %{}})

  @doc """
  Self-report match + why need/has. Isolated.
  Sibling match / overlap LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-why-" <> random_id()

    with {:ok, matched} <- Room.SelfReportMatch.demo(context_id: prefix) do
      why = why_ids(matched.need, matched.hit)

      cond do
        matched.has.source != "self_report" or matched.need.source != "self_report" ->
          {:error, :not_self_report}

        not matched.hit.ok or matched.hit.tags != ["series-a"] ->
          {:error, :overlap_miss}

        why.why_need != "series-a" or why.why_has != "series-a" ->
          {:error, :why_miss}

        true ->
          pack = %{
            has: matched.has,
            need: matched.need,
            hit: matched.hit,
            why: why,
            session: matched.session,
            complete: :agent,
            matched: matched
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp why_ids(need, hit) do
    id = List.first(List.wrap(hit[:tags])) || List.first(List.wrap(need[:tags])) || "series-a"
    %{why_need: id, why_has: id, tags: [id]}
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
