defmodule Room.SelfReportTrimHas do
  @moduledoc """
  Padded Has tags trim then Need finds. Not reject.

  Distinct from self_report_trim_tags (Need-side pad),
  self_report_has_cast / match (already-clean Has), and
  self_report_ws_tags (whitespace-only Need reject).
  Off PDF / badge / GH / score / wiki / morph /
  toolbelt / talk-turns.
  """

  @chat " series-a "
  @raw [" series-a "]

  def chat, do: @chat
  def raw_tags, do: @raw

  def look_need(rec \\ %{}), do: Room.SelfReportMatch.look_need(rec)

  def look_cast(rec \\ %{}) do
    shown = rec[:raw_tags] || @raw
    trim = rec[:trim] || "series-a"
    "ok  cast=has  tags=#{inspect(shown)}  trim=#{trim}  from=chat"
  end

  def look_find(rec \\ %{}), do: Room.SelfReportMatch.look_find(rec)
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [look_need(pack.need), look_cast(pack.has), look_find(pack.hit), look_complete()]
  end

  def look(_), do: look(%{need: %{}, has: %{}, hit: %{}})

  @doc """
  Padded Has chat tag trims, then Need finds mazel'd.
  Isolated. Sibling trim_tags / has_cast / ws_tags LOOK
  stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-trim-has-" <> random_id()
    chat = Keyword.get(opts, :chat) || @chat

    need =
      Keyword.get(opts, :need) ||
        Room.SelfReportMatch.report(:need, "series-a")
    has = Room.SelfReportMatch.cast(:has, chat)
    reported = Room.SelfReportMatch.report(:has, @raw)
    hit = Room.SelfReportMatch.match(has, need)
    clean = Room.SelfReportMatch.cast(:has, "we have series-a")
    need_trim = Room.SelfReportMatch.cast(:need, @chat)
    ws = Room.SelfReportMatch.cast(:need, "   ")

    with {:ok, found} <- Room.Find.query(hit.query || "series-a"),
         {:ok, session} <- keep_agent(prefix, hit) do
      card = List.first(found[:hits] || [])
      events = Enum.map(session.events || [], & &1.type)

      cond do
        has[:from] != "chat" or has[:cast] != "has" ->
          {:error, :cast_miss}

        has.source != "self_report" or need.source != "self_report" ->
          {:error, :not_self_report}

        chat != @chat or String.length(chat) == String.length(String.trim(chat)) ->
          {:error, :pad_miss}

        has[:raw_tags] != @raw or has[:trim] != "series-a" ->
          {:error, :trim_miss}

        has.tags != ["series-a"] or has[:reject] == "empty_tags" or has[:ok] != true ->
          {:error, :tags_miss}

        has.handle != "kai@mazel" ->
          {:error, :handle_miss}

        reported[:raw_tags] != @raw or reported[:trim] != "series-a" or
            reported.tags != ["series-a"] ->
          {:error, :report_trim}

        reported[:reject] == "empty_tags" ->
          {:error, :report_reject}

        clean.tags != ["series-a"] or clean[:trim] != nil or clean[:raw_tags] != nil ->
          {:error, :sibling_cast}

        need_trim[:cast] != "need" or need_trim[:trim] != "series-a" ->
          {:error, :need_trim}

        ws[:reject] != "empty_tags" or ws.tags != [] ->
          {:error, :ws_miss}

        need.tags != ["series-a"] or need[:trim] != nil ->
          {:error, :need_miss}

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
            has: has,
            reported: reported,
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
