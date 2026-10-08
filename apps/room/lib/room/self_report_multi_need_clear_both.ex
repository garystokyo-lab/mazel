defmodule Room.SelfReportMultiNeedClearBoth do
  @moduledoc """
  Two live Needs; clear both. Find is none on either.

  Distinct from multi_need_clear (clear one; other still
  matches), from clear (single Need → tags=[] + recast),
  and from multi_need (no clear). Off PDF / badge / GH /
  score / wiki / morph / toolbelt.
  """

  @first "looking for series-a"
  @second "looking for cto"

  def first_chat, do: @first
  def second_chat, do: @second

  def look_cast(rec \\ %{}), do: Room.SelfReportCast.look_cast(rec)
  def look_has(rec \\ %{}), do: Room.SelfReportMatch.look_has(rec)
  def look_find(rec \\ %{}), do: Room.SelfReportMatch.look_find(rec)

  def look_clear(rec \\ %{}) do
    tags = rec[:dropped] || ["series-a", "cto"]
    "ok  clear=need  tags=[#{Enum.join(List.wrap(tags), ",")}]"
  end

  def look_miss(tag \\ "series-a"), do: "error  find=#{tag}  match=none"
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [
      look_cast(pack.need_a),
      look_cast(pack.need_b),
      look_has(pack.has),
      look_find(pack.hit_a),
      look_find(pack.hit_b),
      look_clear(pack.cleared),
      look_miss("series-a"),
      look_miss("cto"),
      look_complete()
    ]
  end

  def look(_) do
    look(%{
      need_a: %{},
      need_b: %{tags: ["cto"]},
      has: %{tags: ["series-a", "cto"]},
      hit_a: %{query: "series-a"},
      hit_b: %{query: "cto"},
      cleared: %{dropped: ["series-a", "cto"]}
    })
  end

  @doc """
  Cast two Needs. Both match. Clear both; both find none.
  Isolated. Sibling multi_need / clear_one / clear stay.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-multi-need-clear-both-" <> random_id()

    need_a = Room.SelfReportMatch.cast(:need, Keyword.get(opts, :first) || @first)
    need_b = Room.SelfReportMatch.cast(:need, Keyword.get(opts, :second) || @second)
    has = Room.SelfReportMatch.parse(Keyword.get(opts, :has) || "has: series-a,cto")
    hits = Room.SelfReportMatch.match_needs(has, [need_a, need_b])
    hit_a = Enum.find(hits, &(&1.query == "series-a")) || Room.SelfReportMatch.match(has, need_a)
    hit_b = Enum.find(hits, &(&1.query == "cto")) || Room.SelfReportMatch.match(has, need_b)
    [cleared_a, cleared_b] = Room.SelfReportMatch.clear_both([need_a, need_b])
    missed_a = Room.SelfReportMatch.match(has, cleared_a)
    missed_b = Room.SelfReportMatch.match(has, cleared_b)
    after_hits = Room.SelfReportMatch.match_needs(has, [cleared_a, cleared_b])
    dropped = Enum.flat_map([cleared_a, cleared_b], &List.wrap(&1[:dropped]))

    with {:ok, found_a} <- Room.Find.query(hit_a.query || "series-a"),
         {:ok, found_b} <- Room.Find.query(hit_b.query || "cto"),
         {:ok, session} <- keep_agent(prefix, has) do
      card_a = List.first(found_a[:hits] || [])
      card_b = List.first(found_b[:hits] || [])
      events = Enum.map(session.events || [], & &1.type)
      cleared = %{dropped: dropped, cleared: true, tags: []}

      cond do
        need_a.tags != ["series-a"] or need_b.tags != ["cto"] ->
          {:error, :cast_miss}

        need_a[:from] != "chat" or need_b[:from] != "chat" ->
          {:error, :cast_miss}

        has.tags != ["series-a", "cto"] or has.source != "self_report" ->
          {:error, :has_miss}

        length(hits) != 2 or not hit_a.ok or not hit_b.ok ->
          {:error, :overlap_miss}

        hit_a.handle != "kai@mazel" or hit_b.handle != "kai@mazel" ->
          {:error, :overlap_miss}

        cleared_a[:cleared] != true or cleared_b[:cleared] != true ->
          {:error, :clear_miss}

        cleared_a.tags != [] or cleared_b.tags != [] ->
          {:error, :clear_miss}

        cleared_a[:dropped] != ["series-a"] or cleared_b[:dropped] != ["cto"] ->
          {:error, :clear_miss}

        dropped != ["series-a", "cto"] ->
          {:error, :clear_miss}

        missed_a.ok or missed_b.ok or after_hits != [] ->
          {:error, :cleared_hit}

        is_nil(card_a) or card_a.handle != "kai@mazel" ->
          {:error, :find_miss}

        is_nil(card_b) or card_b.handle != "kai@mazel" ->
          {:error, :find_miss}

        session.status != :open or session.badge != nil or "morph.commit" in events ->
          {:error, :session_miss}

        humans_awake?(session) ->
          {:error, :human_woke}

        true ->
          pack = %{
            need_a: need_a,
            need_b: need_b,
            has: has,
            hits: hits,
            hit_a: hit_a,
            hit_b: hit_b,
            cleared: cleared,
            cleared_a: cleared_a,
            cleared_b: cleared_b,
            missed_a: missed_a,
            missed_b: missed_b,
            after_hits: after_hits,
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
