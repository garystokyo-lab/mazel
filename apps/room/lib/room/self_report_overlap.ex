defmodule Room.SelfReportOverlap do
  @moduledoc """
  Partial tag overlap on a self-report Need × Has.

  Shared tags still match. Empty overlap never matches.
  Distinct from self_report_match (equal tag sets, no
  overlap= beat). Not proof. Off wiki.
  """

  def look_has(rec \\ %{}), do: Room.SelfReportMatch.look_has(rec)
  def look_need(rec \\ %{}), do: Room.SelfReportMatch.look_need(rec)
  def look_find(rec \\ %{}), do: Room.SelfReportMatch.look_find(rec)

  def look_overlap(rec \\ %{}) do
    tags = rec[:tags] || rec[:overlap] || ["series-a"]
    "ok  overlap=[#{Enum.join(List.wrap(tags), ",")}]"
  end

  def look_none, do: "error  overlap=[]  match=none"

  def look(pack) when is_map(pack) do
    [look_has(pack.has), look_need(pack.need), look_overlap(pack.hit), look_find(pack.hit), look_none()]
  end

  def look(_), do: look(%{has: %{tags: ["series-a", "cto"]}, need: %{}, hit: %{}})

  @doc """
  Partial overlap → mazel'd. Zero overlap misses.
  Isolated. Sibling match LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-overlap-" <> random_id()

    has = Room.SelfReportMatch.parse(Keyword.get(opts, :has) || "has: series-a, cto")
    need = Room.SelfReportMatch.parse(Keyword.get(opts, :need) || "need: series-a")
    miss_need = Room.SelfReportMatch.parse("need: impl")
    hit = Room.SelfReportMatch.match(has, need)
    none = Room.SelfReportMatch.match(has, miss_need)

    with {:ok, found} <- Room.Find.query(hit.query || "series-a"),
         {:ok, session} <- keep_agent(prefix, hit) do
      card = List.first(found[:hits] || [])

      cond do
        has.tags != ["series-a", "cto"] or need.tags != ["series-a"] ->
          {:error, :tags_miss}

        not hit.ok or hit.tags != ["series-a"] or hit.handle != "kai@mazel" ->
          {:error, :overlap_miss}

        none.ok or none.tags != [] ->
          {:error, :empty_hit}

        is_nil(card) or card.handle != "kai@mazel" ->
          {:error, :find_miss}

        true ->
          pack = %{
            has: has,
            need: need,
            hit: hit,
            none: none,
            find: found,
            session: session
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

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
