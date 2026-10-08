defmodule Room.SelfReportMultiNeed do
  @moduledoc """
  Two live Needs stay live. Find picks the matching one;
  tags are never conflated. Distinct from recast (replace)
  and from bidirectional (two people, one Need each).
  Off PDF / badge / GH / score / wiki / morph / toolbelt.
  """

  @first "looking for series-a"
  @second "looking for cto"

  def first_chat, do: @first
  def second_chat, do: @second

  def look_cast(rec \\ %{}), do: Room.SelfReportCast.look_cast(rec)
  def look_has(rec \\ %{}), do: Room.SelfReportMatch.look_has(rec)
  def look_find(rec \\ %{}), do: Room.SelfReportMatch.look_find(rec)
  def look_miss, do: "error  find=cto  match=none"
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [
      look_cast(pack.need_a),
      look_cast(pack.need_b),
      look_has(pack.has),
      look_find(pack.hit),
      look_miss(),
      look_complete()
    ]
  end

  def look(_), do: look(%{need_a: %{}, need_b: %{tags: ["cto"]}, has: %{}, hit: %{}})

  @doc """
  Cast two Needs. Find picks the overlapping one.
  Isolated. Sibling cast / recast / bidirectional stay.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-multi-need-" <> random_id()

    need_a = Room.SelfReportMatch.cast(:need, Keyword.get(opts, :first) || @first)
    need_b = Room.SelfReportMatch.cast(:need, Keyword.get(opts, :second) || @second)
    has = Room.SelfReportMatch.parse(Keyword.get(opts, :has) || "has: series-a")
    hits = Room.SelfReportMatch.match_needs(has, [need_a, need_b])
    hit = List.first(hits) || Room.SelfReportMatch.match(has, need_a)
    missed = Room.SelfReportMatch.match(has, need_b)

    with {:ok, found} <- Room.Find.query(hit.query || "series-a"),
         {:ok, session} <- keep_agent(prefix, hit) do
      card = List.first(found[:hits] || [])
      events = Enum.map(session.events || [], & &1.type)

      cond do
        need_a.tags != ["series-a"] or need_a[:from] != "chat" or need_a[:cast] != "need" ->
          {:error, :cast_a_miss}

        need_b.tags != ["cto"] or need_b[:from] != "chat" or need_b[:cast] != "need" ->
          {:error, :cast_b_miss}

        need_a[:recast] != nil or need_b[:recast] != nil or need_a[:replaces] != nil or
            need_b[:replaces] != nil ->
          {:error, :recast_hit}

        has.tags != ["series-a"] or has.source != "self_report" ->
          {:error, :has_miss}

        length(hits) != 1 or not hit.ok or hit.query != "series-a" or hit.handle != "kai@mazel" ->
          {:error, :overlap_miss}

        missed.ok or missed.tags != [] or missed.error != "no_overlap" ->
          {:error, :cto_hit}

        is_nil(card) or card.handle != "kai@mazel" ->
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
            hit: hit,
            missed: missed,
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
