defmodule Room.SelfReportHasEmptyTags do
  @moduledoc """
  Cast Has with empty tags → reject. Find not called.

  Distinct from self_report_empty_tags (Need-side
  reject / find=none), self_report_has_cast (Has with
  real tags), and self_report_ws_tags (Need
  whitespace-only). Off PDF / badge / GH / score /
  wiki / morph / toolbelt / talk-turns.
  """

  @chat "just looking"

  def chat, do: @chat

  def look_cast(rec \\ %{}) do
    tags = List.wrap(rec[:tags])
    "error  cast=has  tags=[#{Enum.join(tags, ",")}]  reject=empty_tags"
  end

  def look_skip, do: Room.SelfReportHasNoNeed.look_skip()
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [look_cast(pack.has), look_skip(), look_complete()]
  end

  def look(_), do: look(%{has: %{}})

  @doc """
  Chat with no domain tags → Has reject. Find never
  runs. Stay in-agent. Isolated. Sibling empty_tags /
  has_cast / ws_tags LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-has-empty-tags-" <> random_id()
    chat = Keyword.get(opts, :chat) || @chat

    has = Room.SelfReportMatch.cast(:has, chat)
    need = Room.SelfReportMatch.parse(Keyword.get(opts, :need) || "need: series-a")
    hit = Room.SelfReportMatch.match(has, need)
    tagged = Room.SelfReportMatch.cast(:has, "we have series-a")

    with {:ok, session} <- keep_agent(prefix) do
      events = Enum.map(session.events || [], & &1.type)

      cond do
        has[:from] != "chat" or has[:cast] != "has" ->
          {:error, :cast_miss}

        has.tags != [] or has[:reject] != "empty_tags" or has[:ok] != false ->
          {:error, :reject_miss}

        has[:curious] == true or has[:class] == "curious" ->
          {:error, :curious_hit}

        has[:cleared] == true or has[:clear] == "has" ->
          {:error, :clear_hit}

        tagged.tags != ["series-a"] or tagged[:reject] == "empty_tags" ->
          {:error, :sibling_cast}

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
