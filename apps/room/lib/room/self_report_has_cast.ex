defmodule Room.SelfReportHasCast do
  @moduledoc """
  Cast a self-report Has from chat tags, then match Need.

  from=chat — not parse(\"has: …\"). Distinct from
  self_report_cast (Need cast; Has pre-seeded). Off PDF /
  badge / GH / score / wiki / morph / toolbelt.
  """

  @chat "we have series-a"

  def chat, do: @chat

  def look_cast(rec \\ %{}) do
    tags = rec[:tags] || ["series-a"]
    "ok  cast=has  tags=[#{Enum.join(List.wrap(tags), ",")}]  from=chat"
  end

  def look_need(rec \\ %{}), do: Room.SelfReportMatch.look_need(rec)
  def look_find(rec \\ %{}), do: Room.SelfReportMatch.look_find(rec)
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [look_cast(pack.has), look_need(pack.need), look_find(pack.hit), look_complete()]
  end

  def look(_), do: look(%{has: %{}, need: %{}, hit: %{}})

  @doc """
  Chat → cast Has → overlapping Need → mazel'd in-agent.
  Isolated. Sibling Need-cast LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-has-cast-" <> random_id()
    chat = Keyword.get(opts, :chat) || @chat

    need = Room.SelfReportMatch.parse(Keyword.get(opts, :need) || "need: series-a")
    has = Room.SelfReportMatch.cast(:has, chat)
    claim = Room.SelfReportMatch.cast(:has, "claim: passionate visionary hunt for series-a")
    hit = Room.SelfReportMatch.match(has, need)
    missed = Room.SelfReportMatch.match(claim, need)

    with {:ok, found} <- Room.Find.query(hit.query || "series-a"),
         {:ok, session} <- keep_agent(prefix, hit) do
      card = List.first(found[:hits] || [])
      events = Enum.map(session.events || [], & &1.type)

      cond do
        has[:from] != "chat" or has[:cast] != "has" ->
          {:error, :cast_miss}

        has.source != "self_report" or need.source != "self_report" ->
          {:error, :not_self_report}

        has.tags != ["series-a"] or need.tags != ["series-a"] ->
          {:error, :tags_miss}

        not hit.ok or hit.handle != "kai@mazel" ->
          {:error, :overlap_miss}

        missed.ok or claim.curious != true or claim.tags != [] ->
          {:error, :claim_cast}

        is_nil(card) or card.handle != "kai@mazel" ->
          {:error, :find_miss}

        session.status != :open or session.badge != nil or "morph.commit" in events ->
          {:error, :session_miss}

        humans_awake?(session) ->
          {:error, :human_woke}

        true ->
          pack = %{
            has: has,
            need: need,
            hit: hit,
            claim: claim,
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
