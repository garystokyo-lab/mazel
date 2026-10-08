defmodule Room.SelfReportHasWsTags do
  @moduledoc """
  Cast Has with whitespace-only tags → reject empty_tags.
  Find not called. No crash.

  Distinct from self_report_ws_tags (Need-side
  whitespace-only / find=none), self_report_has_empty_tags
  (Has literal tags=[]), and self_report_trim_has (padded
  real Has tag trims then finds). Off PDF / badge / GH /
  score / wiki / morph / toolbelt / talk-turns.
  """

  @chat "   "
  @raw ["   "]

  def chat, do: @chat
  def raw_tags, do: @raw

  def look_cast(rec \\ %{}) do
    shown = rec[:raw_tags] || @raw
    "error  cast=has  tags=#{inspect(shown)}  reject=empty_tags"
  end

  def look_skip, do: Room.SelfReportHasNoNeed.look_skip()
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [look_cast(pack.has), look_skip(), look_complete()]
  end

  def look(_), do: look(%{has: %{}})

  @doc """
  Whitespace-only chat → Has reject after normalize.
  Find never runs. Stay in-agent. Isolated. Sibling
  ws_tags / has_empty_tags / trim_has LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-has-ws-tags-" <> random_id()
    chat = Keyword.get(opts, :chat) || @chat

    has = Room.SelfReportMatch.cast(:has, chat)
    reported = Room.SelfReportMatch.report(:has, @raw)
    need = Room.SelfReportMatch.parse(Keyword.get(opts, :need) || "need: series-a")
    hit = Room.SelfReportMatch.match(has, need)
    tagged = Room.SelfReportMatch.cast(:has, "we have series-a")
    need_ws = Room.SelfReportMatch.cast(:need, @chat)
    empty = Room.SelfReportMatch.cast(:has, "just looking")
    padded = Room.SelfReportMatch.cast(:has, " series-a ")

    with {:ok, session} <- keep_agent(prefix) do
      events = Enum.map(session.events || [], & &1.type)

      cond do
        has[:from] != "chat" or has[:cast] != "has" ->
          {:error, :cast_miss}

        has.tags != [] or has[:reject] != "empty_tags" or has[:ok] != false ->
          {:error, :reject_miss}

        has[:raw_tags] != @raw ->
          {:error, :raw_miss}

        reported[:reject] != "empty_tags" or reported[:raw_tags] != @raw ->
          {:error, :report_ws}

        reported.tags != [] or reported[:ok] != false ->
          {:error, :report_ws}

        has[:curious] == true or has[:class] == "curious" ->
          {:error, :curious_hit}

        has[:cleared] == true or has[:clear] == "has" ->
          {:error, :clear_hit}

        tagged.tags != ["series-a"] or tagged[:reject] == "empty_tags" ->
          {:error, :sibling_cast}

        need_ws[:cast] != "need" or need_ws[:reject] != "empty_tags" ->
          {:error, :need_ws}

        empty[:cast] != "has" or empty[:reject] != "empty_tags" or empty[:raw_tags] != nil ->
          {:error, :empty_miss}

        padded.tags != ["series-a"] or padded[:reject] == "empty_tags" or
            padded[:trim] != "series-a" ->
          {:error, :trim_miss}

        need.source != "self_report" or need.tags != ["series-a"] ->
          {:error, :need_miss}

        hit.ok or hit.handle != nil or hit[:error] != "empty_tags" ->
          {:error, :find_hit}

        hit[:find] != :not_called or hit[:mazel_d] != :none ->
          {:error, :find_hit}

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
            tagged: tagged,
            chat: chat,
            session: session,
            complete: :agent
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp keep_agent(id) do
    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai") do
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
