defmodule Room.SelfReportRecast do
  @moduledoc """
  Recast Need with new tags replaces the old Need.

  Fresh tags drive find. Old tags miss. Distinct from
  self_report_cast (single cast, no replace). Off PDF /
  badge / GH / score / wiki / morph / toolbelt.
  """

  @first "looking for series-a"
  @fresh "looking for cto"

  def first_chat, do: @first
  def fresh_chat, do: @fresh

  def look_cast(rec \\ %{}), do: Room.SelfReportCast.look_cast(rec)

  def look_recast(rec \\ %{}) do
    tags = rec[:tags] || ["cto"]
    old = rec[:replaced] || List.first(List.wrap(rec[:replaces])) || "series-a"
    "ok  recast=need  tags=[#{Enum.join(List.wrap(tags), ",")}]  replaces=#{old}"
  end

  def look_has(rec \\ %{}), do: Room.SelfReportMatch.look_has(rec)
  def look_find(rec \\ %{}), do: Room.SelfReportMatch.look_find(rec)
  def look_miss, do: "error  find=series-a  match=none"
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [
      look_cast(pack.first),
      look_recast(pack.need),
      look_has(pack.has),
      look_find(pack.hit),
      look_miss(),
      look_complete()
    ]
  end

  def look(_), do: look(%{first: %{}, need: %{tags: ["cto"], replaced: "series-a"}, has: %{tags: ["cto"]}, hit: %{query: "cto"}})

  @doc """
  Cast, recast, match fresh Has. Old tags miss.
  Isolated. Sibling cast LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-recast-" <> random_id()

    first = Room.SelfReportMatch.cast(:need, Keyword.get(opts, :first) || @first)
    need = Room.SelfReportMatch.recast(:need, Keyword.get(opts, :fresh) || @fresh, first)
    has = Room.SelfReportMatch.parse(Keyword.get(opts, :has) || "has: cto")
    hit = Room.SelfReportMatch.match(has, need)
    missed = Room.SelfReportMatch.match(has, first)

    with {:ok, found} <- Room.Find.query(hit.query || "cto"),
         {:ok, session} <- keep_agent(prefix, hit) do
      card = List.first(found[:hits] || [])
      events = Enum.map(session.events || [], & &1.type)

      cond do
        first.tags != ["series-a"] or first[:from] != "chat" ->
          {:error, :cast_miss}

        need.tags != ["cto"] or need[:replaced] != "series-a" or need[:replaces] != ["series-a"] ->
          {:error, :recast_miss}

        has.tags != ["cto"] or has.source != "self_report" ->
          {:error, :has_miss}

        not hit.ok or hit.query != "cto" or hit.handle != "kai@mazel" ->
          {:error, :overlap_miss}

        missed.ok or missed.tags != [] ->
          {:error, :old_hit}

        is_nil(card) or card.handle != "kai@mazel" ->
          {:error, :find_miss}

        session.status != :open or session.badge != nil or "morph.commit" in events ->
          {:error, :session_miss}

        humans_awake?(session) ->
          {:error, :human_woke}

        true ->
          pack = %{
            first: first,
            need: need,
            has: has,
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
