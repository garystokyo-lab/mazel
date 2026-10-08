defmodule Room.SelfReportHasMultiTag do
  @moduledoc """
  One Has with two tags hits Need on any shared tag.

  tags=[series-a,cto] × Need [series-a] → overlap=[series-a].
  Distinct from self_report_need_multi_tag (Need multi /
  Has single), self_report_overlap (Has-first + miss
  beat), and self_report_match (exact single tag).
  Off PDF / badge / GH / score / wiki / morph /
  toolbelt / talk-turns.
  """

  @chat "we have series-a,cto"

  def chat, do: @chat

  def look_need(rec \\ %{}), do: Room.SelfReportMatch.look_need(rec)
  def look_has(rec \\ %{}), do: Room.SelfReportMatch.look_has(rec)
  def look_overlap(rec \\ %{}), do: Room.SelfReportOverlap.look_overlap(rec)
  def look_find(rec \\ %{}), do: Room.SelfReportMatch.look_find(rec)
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [
      look_need(pack.need),
      look_has(pack.has),
      look_overlap(pack.hit),
      look_find(pack.hit),
      look_complete()
    ]
  end

  def look(_), do: look(%{need: %{}, has: %{tags: ["series-a", "cto"]}, hit: %{}})

  @doc """
  Multi-tag Has (cast path) × single Need. Any-tag hit.
  Isolated. Sibling need_multi_tag / overlap / match
  LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-has-multi-tag-" <> random_id()
    chat = Keyword.get(opts, :chat) || @chat

    need = Room.SelfReportMatch.parse(Keyword.get(opts, :need) || "need: series-a")
    has = Room.SelfReportMatch.cast(:has, chat)
    reported = Room.SelfReportMatch.report(:has, ["series-a", "cto"])
    hit = Room.SelfReportMatch.match(has, need)
    shared = Room.SelfReportMatch.overlap(has, need)

    with {:ok, found} <- Room.Find.query(hit.query || "series-a"),
         {:ok, session} <- keep_agent(prefix, hit) do
      card = List.first(found[:hits] || [])
      events = Enum.map(session.events || [], & &1.type)

      cond do
        has[:from] != "chat" or has[:cast] != "has" ->
          {:error, :cast_miss}

        need.source != "self_report" or has.source != "self_report" ->
          {:error, :not_self_report}

        need.tags != ["series-a"] ->
          {:error, :need_miss}

        has.tags != ["series-a", "cto"] or reported.tags != ["series-a", "cto"] ->
          {:error, :has_miss}

        shared != ["series-a"] or hit.tags != ["series-a"] ->
          {:error, :overlap_miss}

        not hit.ok or hit.handle != "kai@mazel" or hit.query != "series-a" ->
          {:error, :overlap_miss}

        is_nil(card) or card.handle != "kai@mazel" ->
          {:error, :find_miss}

        session.status != :open or session.badge != nil or "morph.commit" in events ->
          {:error, :session_miss}

        "talk" in events ->
          {:error, :talked}

        humans_awake?(session) ->
          {:error, :human_woke}

        look_need(%{}) == Room.SelfReportNeedMultiTag.look_need(%{tags: ["series-a", "cto"]}) ->
          {:error, :need_multi}

        look_has(%{tags: ["series-a", "cto"]}) == Room.SelfReportNeedMultiTag.look_has(%{}) ->
          {:error, :need_multi}

        look_complete() == Room.SelfReportOverlap.look_none() ->
          {:error, :overlap_look}

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