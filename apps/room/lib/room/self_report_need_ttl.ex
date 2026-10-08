defmodule Room.SelfReportNeedTtl do
  @moduledoc """
  Need TTL on the self-report tag-match path.

  Fresh Need + overlapping Has → mazel'd. Expired Need
  never finds — even when tags would overlap.
  Built into SelfReportMatch.match. Distinct from
  self_report_match / overlap / why / check (no need_ttl=).
  Off score. Off wiki. Off morph.
  """

  def look_has(rec \\ %{}), do: Room.SelfReportMatch.look_has(rec)

  def look_need(rec \\ %{}) do
    tags = rec[:tags] || ["series-a"]
    ttl = rec[:need_ttl] || :fresh
    "ok  need=self_report  tags=[#{Enum.join(List.wrap(tags), ",")}]  need_ttl=#{ttl}"
  end

  def look_find(rec \\ %{}), do: Room.SelfReportMatch.look_find(rec)
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look_expired, do: "error  need_ttl=expired  find=none  mazel'd=none"

  def look(pack) when is_map(pack) do
    [
      look_has(pack.has),
      look_need(pack.need),
      look_find(pack.hit),
      look_expired(),
      look_complete()
    ]
  end

  def look(_), do: look(%{has: %{}, need: %{need_ttl: :fresh}, hit: %{}})

  @doc """
  Fresh self-report Need mazel'd. Expired never opens.
  Isolated. Sibling match / overlap / why / check LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-need-ttl-" <> random_id()
    now = Keyword.get(opts, :now) || DateTime.utc_now()

    has = Room.SelfReportMatch.parse(Keyword.get(opts, :has) || "has: series-a")
    need = Room.SelfReportMatch.stamp_ttl(Room.SelfReportMatch.parse("need: series-a"), :fresh, now)
    dead = Room.SelfReportMatch.stamp_ttl(Room.SelfReportMatch.parse("need: series-a"), :expired, now)
    hit = Room.SelfReportMatch.match(has, need, now: now)
    missed = Room.SelfReportMatch.match(has, dead, now: now)
    would = Room.SelfReportMatch.overlap(has, dead)

    with {:ok, found} <- Room.Find.query(hit.query || "series-a"),
         {:ok, session} <- keep_if_fresh(prefix, hit) do
      card = List.first(found[:hits] || [])
      events = Enum.map(session.events || [], & &1.type)

      cond do
        has.source != "self_report" or need.source != "self_report" ->
          {:error, :not_self_report}

        need.need_ttl != :fresh or hit[:need_ttl] != :fresh or not hit.ok ->
          {:error, :fresh_miss}

        would != ["series-a"] ->
          {:error, :tags_miss}

        missed.ok or missed[:need_ttl] != :expired or missed.error != "expired" ->
          {:error, :expired_hit}

        is_nil(card) or card.handle != "kai@mazel" ->
          {:error, :find_miss}

        session.status != :open or session.badge != nil or "morph.commit" in events ->
          {:error, :session_miss}

        humans_awake?(session) ->
          {:error, :human_woke}

        true ->
          pack = %{
            has: has,
            need: need,
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

  defp keep_if_fresh(_id, %{ok: false}), do: {:error, :expired_mazeld}

  defp keep_if_fresh(id, hit) do
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
