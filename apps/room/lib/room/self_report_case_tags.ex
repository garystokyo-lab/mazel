defmodule Room.SelfReportCaseTags do
  @moduledoc """
  Mixed-case tags normalize then match.

  Series-A ↔ series-a. Distinct from
  self_report_trim_tags / trim_has (whitespace only),
  self_report_match / cast (already lowercase), and
  self_report_tag_mismatch (different tags). Off PDF /
  badge / GH / score / wiki / morph / toolbelt /
  talk-turns.
  """

  @chat "Series-A"
  @raw ["Series-A"]
  @norm "series-a"

  def chat, do: @chat
  def raw_tags, do: @raw
  def norm, do: @norm

  def look_cast(rec \\ %{}) do
    shown = rec[:raw_tags] || @raw
    norm = rec[:norm] || @norm
    "ok  cast=need  tags=[#{Enum.join(List.wrap(shown), ",")}]  norm=#{norm}  from=chat"
  end

  def look_has(rec \\ %{}), do: Room.SelfReportMatch.look_has(rec)
  def look_find(rec \\ %{}), do: Room.SelfReportMatch.look_find(rec)
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [look_cast(pack.need), look_has(pack.has), look_find(pack.hit), look_complete()]
  end

  def look(_), do: look(%{need: %{}, has: %{}, hit: %{}})

  @doc """
  Mixed-case Need tag normalizes, then mazel'd.
  Reverse Has=[Series-A] × Need=[series-a] also hits.
  Isolated. Sibling trim_* / match / mismatch LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-case-tags-" <> random_id()
    chat = Keyword.get(opts, :chat) || @chat

    need = Room.SelfReportMatch.cast(:need, chat)
    reported = Room.SelfReportMatch.report(:need, @raw)
    has = Room.SelfReportMatch.parse(Keyword.get(opts, :has) || "has: series-a")
    hit = Room.SelfReportMatch.match(has, need)

    has_cased = Room.SelfReportMatch.cast(:has, chat)
    need_clean = Room.SelfReportMatch.report(:need, @norm)
    hit_rev = Room.SelfReportMatch.match(has_cased, need_clean)

    clean = Room.SelfReportMatch.cast(:need, "looking for series-a")
    padded = Room.SelfReportMatch.cast(:need, " series-a ")
    missed = Room.SelfReportMatch.mismatch(has, Room.SelfReportMatch.report(:need, "cto"))

    with {:ok, found} <- Room.Find.query(hit.query || @norm),
         {:ok, session} <- keep_agent(prefix, hit) do
      card = List.first(found[:hits] || [])
      events = Enum.map(session.events || [], & &1.type)

      cond do
        need[:from] != "chat" or need[:cast] != "need" ->
          {:error, :cast_miss}

        need.source != "self_report" or has.source != "self_report" ->
          {:error, :not_self_report}

        chat != @chat or chat == String.downcase(chat) ->
          {:error, :case_miss}

        need[:raw_tags] != @raw or need[:norm] != @norm ->
          {:error, :norm_miss}

        need.tags != [@norm] or need[:trim] != nil or need[:reject] == "empty_tags" or
            need[:ok] != true ->
          {:error, :tags_miss}

        reported[:raw_tags] != @raw or reported[:norm] != @norm or reported.tags != [@norm] ->
          {:error, :report_norm}

        has.tags != [@norm] ->
          {:error, :has_miss}

        not hit.ok or hit.handle != "kai@mazel" or hit.tags != [@norm] ->
          {:error, :overlap_miss}

        has_cased[:raw_tags] != @raw or has_cased[:norm] != @norm or has_cased.tags != [@norm] ->
          {:error, :has_case}

        not hit_rev.ok or hit_rev.handle != "kai@mazel" ->
          {:error, :rev_miss}

        clean.tags != [@norm] or clean[:norm] != nil or clean[:raw_tags] != nil ->
          {:error, :sibling_cast}

        padded[:trim] != @norm or padded[:norm] != nil ->
          {:error, :sibling_trim}

        missed.ok or missed.error != "no_overlap" ->
          {:error, :mismatch_hit}

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
            has_cased: has_cased,
            hit: hit,
            hit_rev: hit_rev,
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
