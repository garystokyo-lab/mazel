defmodule Room.SelfReportEmptyTags do
  @moduledoc """
  Cast Need with empty tags → reject. Find none. No crash.

  Distinct from self_report_cast (tags present → find),
  self_report_clear (clear after cast → tags=[]),
  self_report_curious (curious/claim class), and
  self_report_empty (Need with tags, Has vault empty).
  Off PDF / badge / GH / score / wiki / morph / toolbelt.
  """

  @chat "just looking"

  def chat, do: @chat

  def look_cast(rec \\ %{}) do
    tags = List.wrap(rec[:tags])
    "error  cast=need  tags=[#{Enum.join(tags, ",")}]  reject=empty_tags"
  end

  def look_miss, do: "error  find=none  mazel'd=none"
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [look_cast(pack.need), look_miss(), look_complete()]
  end

  def look(_), do: look(%{need: %{}})

  @doc """
  Chat with no domain tags → Need reject. Find never
  runs. Stay in-agent. Isolated. Sibling cast / clear /
  curious / empty LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-empty-tags-" <> random_id()
    chat = Keyword.get(opts, :chat) || @chat

    need = Room.SelfReportMatch.cast(:need, chat)
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

        need[:curious] == true or need[:class] == "curious" ->
          {:error, :curious_hit}

        need[:cleared] == true or need[:clear] == "need" ->
          {:error, :clear_hit}

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
