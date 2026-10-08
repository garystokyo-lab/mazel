defmodule Room.SelfReportWsTags do
  @moduledoc """
  Cast Need with whitespace-only tags → reject empty_tags.
  Find none. No crash.

  Distinct from self_report_empty_tags (literal tags=[]),
  and self_report_cast (real tags → find). Off PDF /
  badge / GH / score / wiki / morph / toolbelt / talk.
  """

  @chat "   "
  @raw ["   "]

  def chat, do: @chat
  def raw_tags, do: @raw

  def look_cast(rec \\ %{}) do
    shown = rec[:raw_tags] || @raw
    "error  cast=need  tags=#{inspect(shown)}  reject=empty_tags"
  end

  def look_miss, do: Room.SelfReportEmptyTags.look_miss()
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [look_cast(pack.need), look_miss(), look_complete()]
  end

  def look(_), do: look(%{need: %{}})

  @doc """
  Whitespace-only chat → Need reject after normalize.
  Find never runs. Stay in-agent. Isolated. Sibling
  empty_tags / cast LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-ws-tags-" <> random_id()
    chat = Keyword.get(opts, :chat) || @chat

    need = Room.SelfReportMatch.cast(:need, chat)
    reported = Room.SelfReportMatch.report(:need, @raw)
    has = Room.SelfReportMatch.parse(Keyword.get(opts, :has) || "has: series-a")
    hit = Room.SelfReportMatch.match(has, need)
    tagged = Room.SelfReportMatch.cast(:need, "looking for series-a")

    with {:ok, session} <- keep_agent(prefix) do
      events = Enum.map(session.events || [], & &1.type)

      cond do
        need[:from] != "chat" or need[:cast] != "need" ->
          {:error, :cast_miss}

        need.tags != [] or need[:reject] != "empty_tags" or need[:ok] != false ->
          {:error, :reject_miss}

        need[:raw_tags] != @raw ->
          {:error, :raw_miss}

        reported[:reject] != "empty_tags" or reported[:raw_tags] != @raw ->
          {:error, :report_ws}

        reported.tags != [] or reported[:ok] != false ->
          {:error, :report_ws}

        need[:curious] == true or need[:class] == "curious" ->
          {:error, :curious_hit}

        tagged.tags != ["series-a"] or tagged[:reject] == "empty_tags" ->
          {:error, :sibling_cast}

        has.source != "self_report" or has.tags != ["series-a"] ->
          {:error, :has_miss}

        hit.ok or hit.handle != nil or hit[:error] != "empty_tags" ->
          {:error, :find_hit}

        hit[:find] != :none or hit[:mazel_d] != :none ->
          {:error, :find_hit}

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
