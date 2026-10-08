defmodule Room.SelfReportNeedTtlExpire do
  @moduledoc """
  One Need expires in-path. Fresh find, then none.

  Distinct from self_report_need_ttl (parallel fresh vs
  expired Needs) and self_report_cast (no need_ttl=).
  Off PDF / badge / GH / score / wiki / morph / toolbelt.
  """

  @chat "looking for series-a"

  def chat, do: @chat

  def look_cast(rec \\ %{}) do
    tags = rec[:tags] || ["series-a"]
    ttl = rec[:need_ttl] || :fresh
    "ok  cast=need  tags=[#{Enum.join(List.wrap(tags), ",")}]  need_ttl=#{ttl}  from=chat"
  end

  def look_has(rec \\ %{}), do: Room.SelfReportMatch.look_has(rec)
  def look_find(rec \\ %{}), do: Room.SelfReportMatch.look_find(rec)
  def look_expire, do: "ok  need_ttl=expired"
  def look_miss, do: "error  find=series-a  match=none  mazel'd=none"
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [
      look_cast(pack.need),
      look_has(pack.has),
      look_find(pack.hit),
      look_expire(),
      look_miss(),
      look_complete()
    ]
  end

  def look(_), do: look(%{need: %{need_ttl: :fresh}, has: %{}, hit: %{}})

  @doc """
  Cast Need, find while fresh, expire, find none.
  Isolated. Sibling need_ttl / cast LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-need-ttl-expire-" <> random_id()
    now = Keyword.get(opts, :now) || DateTime.utc_now()
    chat = Keyword.get(opts, :chat) || @chat

    has = Room.SelfReportMatch.parse(Keyword.get(opts, :has) || "has: series-a")
    need = Room.SelfReportMatch.stamp_ttl(Room.SelfReportMatch.cast(:need, chat), :fresh, now)
    hit = Room.SelfReportMatch.match(has, need, now: now)
    dead = Room.SelfReportMatch.stamp_ttl(need, :expired, now)
    missed = Room.SelfReportMatch.match(has, dead, now: now)
    would = Room.SelfReportMatch.overlap(has, dead)

    with {:ok, found} <- Room.Find.query(hit.query || "series-a"),
         {:ok, session} <- keep_if_fresh(prefix, hit) do
      card = List.first(found[:hits] || [])
      events = Enum.map(session.events || [], & &1.type)

      cond do
        need[:from] != "chat" or need[:cast] != "need" ->
          {:error, :cast_miss}

        need.source != "self_report" or has.source != "self_report" ->
          {:error, :not_self_report}

        need.tags != ["series-a"] or has.tags != ["series-a"] ->
          {:error, :tags_miss}

        need.need_ttl != :fresh or hit[:need_ttl] != :fresh or not hit.ok ->
          {:error, :fresh_miss}

        hit.handle != "kai@mazel" ->
          {:error, :overlap_miss}

        dead.need_ttl != :expired ->
          {:error, :expire_miss}

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
            dead: dead,
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