defmodule Room.MatchChatMismatch do
  @moduledoc """
  Zero self-report overlap never opens match-chat.

  find=none. talk=none. No mazel'd. Distinct from match_chat_*
  (overlap assumed) and self_report_overlap (no talk gate).
  Not wiki / GH proof.
  """

  def look_has(rec \\ %{}), do: Room.MatchChat.look_has(rec)
  def look_need(rec \\ %{}), do: Room.MatchChat.look_need(rec)

  def look_find_none, do: "error  overlap=[]  find=none"
  def look_talk_none, do: "error  talk=none"

  def look(pack) when is_map(pack) do
    [look_has(pack.has), look_need(pack.need), look_find_none(), look_talk_none()]
  end

  def look(_), do: look(%{has: %{}, need: %{tags: ["impl"]}})

  @doc """
  series-a × impl never overlaps. No session. No talk.
  Isolated. Sibling match-chat / overlap LOOK stays.
  """
  def demo(opts \\ []) do
    _prefix = Keyword.get(opts, :context_id) || "match-chat-mismatch-" <> random_id()

    has = Room.SelfReportMatch.parse(Keyword.get(opts, :has) || "has: series-a")
    need = Room.SelfReportMatch.parse(Keyword.get(opts, :need) || "need: impl")
    hit = Room.SelfReportMatch.match(has, need)

    cond do
      has.source != "self_report" or need.source != "self_report" ->
        {:error, :not_self_report}

      has.tags != ["series-a"] or need.tags != ["impl"] ->
        {:error, :tags_miss}

      hit.ok or hit.tags != [] or hit.handle != nil ->
        {:error, :overlap_hit}

      true ->
        pack = %{
          has: has,
          need: need,
          hit: hit,
          session: nil,
          talks: []
        }

        {:ok, Map.put(pack, :lines, look(pack))}
    end
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end