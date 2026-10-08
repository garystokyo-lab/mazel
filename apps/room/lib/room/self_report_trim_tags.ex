defmodule Room.SelfReportTrimTags do
  @moduledoc """
  Padded Need tags trim then match. Not reject.

  Distinct from self_report_ws_tags (whitespace-only →
  reject=empty_tags) and self_report_cast / match
  (already-clean tags). Off PDF / badge / GH / score /
  wiki / morph / toolbelt / talk-turns.
  """

  @chat " series-a "
  @raw [" series-a "]

  def chat, do: @chat
  def raw_tags, do: @raw

  def look_cast(rec \\ %{}) do
    shown = rec[:raw_tags] || @raw
    trim = rec[:trim] || "series-a"
    "ok  cast=need  tags=#{inspect(shown)}  trim=#{trim}  from=chat"
  end

  def look_has(rec \\ %{}), do: Room.SelfReportMatch.look_has(rec)
  def look_find(rec \\ %{}), do: Room.SelfReportMatch.look_find(rec)
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [look_cast(pack.need), look_has(pack.has), look_find(pack.hit), look_complete()]
  end

  def look(_), do: look(%{need: %{}, has: %{}, hit: %{}})

  @doc """
  Padded chat tag trims to a real Need, then mazel'd.
  Isolated. Sibling ws_tags / cast / empty_tags LOOK
  stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-trim-tags-" <> random_id()
    chat = Keyword.get(opts, :chat) || @chat

    need = Room.SelfReportMatch.cast(:need, chat)
    reported = Room.SelfReportMatch.report(:need, @raw)
    has = Room.SelfReportMatch.parse(Keyword.get(opts, :has) || "has: series-a")
    hit = Room.SelfReportMatch.match(has, need)
    ws = Room.SelfReportMatch.cast(:need, "   ")
    clean = Room.SelfReportMatch.cast(:need, "looking for series-a")

    with {:ok, found} <- Room.Find.query(hit.query || "series-a"),
         {:ok, session} <- keep_agent(prefix, hit) do
      card = List.first(found[:hits] || [])
      events = Enum.map(session.events || [], & &1.type)

      cond do
        need[:from] != "chat" or need[:cast] != "need" ->
          {:error, :cast_miss}

        need.source != "self_report" or has.source != "self_report" ->
          {:error, :not_self_report}

        chat != @chat or String.length(chat) == String.length(String.trim(chat)) ->
          {:error, :pad_miss}

        need[:raw_tags] != @raw or need[:trim] != "series-a" ->
          {:error, :trim_miss}

        need.tags != ["series-a"] or need[:reject] == "empty_tags" or need[:ok] != true ->
          {:error, :tags_miss}

        reported[:raw_tags] != @raw or reported[:trim] != "series-a" or
            reported.tags != ["series-a"] ->
          {:error, :report_trim}

        reported[:reject] == "empty_tags" ->
          {:error, :report_reject}

        ws[:reject] != "empty_tags" or ws.tags != [] ->
          {:error, :ws_miss}

        clean.tags != ["series-a"] or clean[:trim] != nil or clean[:raw_tags] != nil ->
          {:error, :sibling_cast}

        has.tags != ["series-a"] ->
          {:error, :has_miss}

        not hit.ok or hit.handle != "kai@mazel" ->
          {:error, :overlap_miss}

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
