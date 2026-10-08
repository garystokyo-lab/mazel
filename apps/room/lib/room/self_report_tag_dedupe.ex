defmodule Room.SelfReportTagDedupe do
  @moduledoc """
  Repeated Need tags collapse, then find.

  tags=[series-a,series-a] → dedupe=[series-a].
  Distinct from self_report_need_multi_tag (distinct
  multi tags), self_report_cast / match (already unique
  tags), and self_report_case_tags (case fold, not
  dedupe). Off PDF / badge / GH / score / wiki / morph /
  toolbelt / talk-turns.
  """

  @chat "series-a,series-a"
  @raw ["series-a", "series-a"]
  @uniq ["series-a"]

  def chat, do: @chat
  def raw_tags, do: @raw
  def uniq, do: @uniq

  def look_cast(rec \\ %{}) do
    shown = rec[:raw_tags] || @raw
    deduped = rec[:dedupe] || rec[:tags] || @uniq
    "ok  cast=need  tags=[#{Enum.join(List.wrap(shown), ",")}]  dedupe=[#{Enum.join(List.wrap(deduped), ",")}]  from=chat"
  end

  def look_has(rec \\ %{}), do: Room.SelfReportMatch.look_has(rec)
  def look_find(rec \\ %{}), do: Room.SelfReportMatch.look_find(rec)
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [look_cast(pack.need), look_has(pack.has), look_find(pack.hit), look_complete()]
  end

  def look(_), do: look(%{need: %{}, has: %{}, hit: %{}})

  @doc """
  Repeated Need tags dedupe on the cast path, then
  mazel'd. Isolated. Sibling multi_tag / cast /
  case_tags LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-tag-dedupe-" <> random_id()
    chat = Keyword.get(opts, :chat) || @chat

    need = Room.SelfReportMatch.cast(:need, chat)
    reported = Room.SelfReportMatch.report(:need, @raw)
    has = Room.SelfReportMatch.parse(Keyword.get(opts, :has) || "has: series-a")
    hit = Room.SelfReportMatch.match(has, need)

    multi = Room.SelfReportMatch.parse("need: series-a, cto")
    clean = Room.SelfReportMatch.cast(:need, "looking for series-a")
    cased = Room.SelfReportMatch.cast(:need, "Series-A")

    with {:ok, found} <- Room.Find.query(hit.query || "series-a"),
         {:ok, session} <- keep_agent(prefix, hit) do
      card = List.first(found[:hits] || [])
      events = Enum.map(session.events || [], & &1.type)

      cond do
        need[:from] != "chat" or need[:cast] != "need" ->
          {:error, :cast_miss}

        need.source != "self_report" or has.source != "self_report" ->
          {:error, :not_self_report}

        chat != @chat ->
          {:error, :dup_miss}

        need[:raw_tags] != @raw or need[:dedupe] != @uniq ->
          {:error, :dedupe_miss}

        need.tags != @uniq or need[:norm] != nil or need[:trim] != nil or
            need[:reject] == "empty_tags" or need[:ok] != true ->
          {:error, :tags_miss}

        reported[:raw_tags] != @raw or reported[:dedupe] != @uniq or reported.tags != @uniq ->
          {:error, :report_dedupe}

        has.tags != @uniq ->
          {:error, :has_miss}

        not hit.ok or hit.handle != "kai@mazel" or hit.tags != @uniq or hit.query != "series-a" ->
          {:error, :overlap_miss}

        multi.tags != ["series-a", "cto"] or multi[:dedupe] != nil ->
          {:error, :sibling_multi}

        clean.tags != @uniq or clean[:dedupe] != nil or clean[:raw_tags] != nil ->
          {:error, :sibling_cast}

        cased[:norm] != "series-a" or cased[:dedupe] != nil or cased.tags != @uniq ->
          {:error, :sibling_case}

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
            reported: reported,
            has: has,
            hit: hit,
            chat: chat,
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
