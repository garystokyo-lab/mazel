defmodule Room.SelfReportCast do
  @moduledoc """
  Cast a self-report Need from chat tags, then match Has.

  from=chat — not parse(\"need: …\"). Distinct from
  self_report_match / overlap / why / check / need_ttl
  (Need already present). Off PDF / badge / GH / score /
  wiki / morph / toolbelt.
  """

  @chat "looking for series-a"

  def chat, do: @chat

  def look_cast(rec \\ %{}) do
    tags = rec[:tags] || ["series-a"]
    "ok  cast=need  tags=[#{Enum.join(List.wrap(tags), ",")}]  from=chat"
  end

  def look_has(rec \\ %{}), do: Room.SelfReportMatch.look_has(rec)
  def look_find(rec \\ %{}), do: Room.SelfReportMatch.look_find(rec)
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [look_cast(pack.need), look_has(pack.has), look_find(pack.hit), look_complete()]
  end

  def look(_), do: look(%{need: %{}, has: %{}, hit: %{}})

  @doc """
  Chat → cast Need → overlapping Has → mazel'd in-agent.
  Isolated. Sibling self-report LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-cast-" <> random_id()
    chat = Keyword.get(opts, :chat) || @chat

    has = Room.SelfReportMatch.parse(Keyword.get(opts, :has) || "has: series-a")
    need = Room.SelfReportMatch.cast(:need, chat)
    claim = Room.SelfReportMatch.cast(:need, "claim: passionate visionary hunt for series-a")
    hit = Room.SelfReportMatch.match(has, need)
    missed = Room.SelfReportMatch.match(has, claim)

    with {:ok, found} <- Room.Find.query(hit.query || "series-a"),
         {:ok, session} <- keep_agent(prefix, hit) do
      card = List.first(found[:hits] || [])
      events = Enum.map(session.events || [], & &1.type)

      cond do
        need[:from] != "chat" or need[:cast] != "need" ->
          {:error, :cast_miss}

        need.source != "self_report" or has.source != "self_report" ->
          {:error, :not_self_report}

        need.tags != ["series-a"] or has.tags != ["series-a"] ->
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
