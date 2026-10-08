defmodule Room.SelfReportHasTagDedupe do
  @moduledoc """
  Repeated Has tags collapse, then find Need.

  tags=[series-a,series-a] → dedupe=[series-a].
  Distinct from self_report_tag_dedupe (Need-side
  repeats), self_report_has_cast / trim_has (unique Has
  tags), and self_report_need_multi_tag (distinct multi
  tags on Need). Off PDF / badge / GH / score / wiki /
  morph / toolbelt / talk-turns.
  """

  @chat "we have series-a,series-a"
  @raw ["series-a", "series-a"]
  @uniq ["series-a"]

  def chat, do: @chat
  def raw_tags, do: @raw
  def uniq, do: @uniq

  def look_cast(rec \\ %{}) do
    shown = rec[:raw_tags] || @raw
    deduped = rec[:dedupe] || rec[:tags] || @uniq
    "ok  cast=has  tags=[#{Enum.join(List.wrap(shown), ",")}]  dedupe=[#{Enum.join(List.wrap(deduped), ",")}]  from=chat"
  end

  def look_need(rec \\ %{}), do: Room.SelfReportMatch.look_need(rec)
  def look_find(rec \\ %{}), do: Room.SelfReportMatch.look_find(rec)
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [look_need(pack.need), look_cast(pack.has), look_find(pack.hit), look_complete()]
  end

  def look(_), do: look(%{has: %{}, need: %{}, hit: %{}})

  @doc """
  Need first. Repeated Has tags dedupe on the cast
  path, then mazel'd. Isolated. Sibling Need-dedupe /
  has_cast / trim_has / multi_tag LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-has-tag-dedupe-" <> random_id()
    chat = Keyword.get(opts, :chat) || @chat

    has = Room.SelfReportMatch.cast(:has, chat)
    reported = Room.SelfReportMatch.report(:has, @raw)
    need = Room.SelfReportMatch.parse(Keyword.get(opts, :need) || "need: series-a")
    hit = Room.SelfReportMatch.match(has, need)

    unique = Room.SelfReportMatch.cast(:has, "we have series-a")
    need_dup = Room.SelfReportMatch.cast(:need, "series-a,series-a")
    multi = Room.SelfReportMatch.parse("need: series-a, cto")
    cased = Room.SelfReportMatch.cast(:has, "Series-A")

    with {:ok, found} <- Room.Find.query(hit.query || "series-a"),
         {:ok, session} <- keep_agent(prefix, hit) do
      card = List.first(found[:hits] || [])
      events = Enum.map(session.events || [], & &1.type)

      cond do
        has[:from] != "chat" or has[:cast] != "has" ->
          {:error, :cast_miss}

        has.source != "self_report" or need.source != "self_report" ->
          {:error, :not_self_report}

        chat != @chat ->
          {:error, :dup_miss}

        has[:raw_tags] != @raw or has[:dedupe] != @uniq ->
          {:error, :dedupe_miss}

        has.tags != @uniq or has[:norm] != nil or has[:trim] != nil or
            has[:reject] == "empty_tags" or has[:ok] != true ->
          {:error, :tags_miss}

        reported[:raw_tags] != @raw or reported[:dedupe] != @uniq or reported.tags != @uniq ->
          {:error, :report_dedupe}

        need.tags != @uniq or need[:dedupe] != nil ->
          {:error, :need_miss}

        not hit.ok or hit.handle != "kai@mazel" or hit.tags != @uniq or hit.query != "series-a" ->
          {:error, :overlap_miss}

        unique.tags != @uniq or unique[:dedupe] != nil or unique[:raw_tags] != nil ->
          {:error, :sibling_cast}

        need_dup[:cast] != "need" or need_dup[:dedupe] != @uniq or need_dup.tags != @uniq ->
          {:error, :sibling_need}

        multi.tags != ["series-a", "cto"] or multi[:dedupe] != nil ->
          {:error, :sibling_multi}

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
            has: has,
            reported: reported,
            need: need,
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
