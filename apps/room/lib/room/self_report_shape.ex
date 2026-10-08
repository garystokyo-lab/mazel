defmodule Room.SelfReportShape do
  @moduledoc """
  Cast a self-report Need that carries a Need shape.

  shape=founder_investors on from=chat. Find still tag-
  overlaps. Distinct from self_report_cast (no shape=)
  and need_shape (fields / need×has). Off PDF / badge /
  GH / score / wiki / morph / toolbelt.
  """

  @chat "looking for series-a"
  @shape :founder_investors

  def chat, do: @chat
  def shape, do: @shape

  def look_cast(rec \\ %{}) do
    tags = rec[:tags] || ["series-a"]
    shape = rec[:shape] || @shape
    "ok  cast=need  shape=#{shape}  tags=[#{Enum.join(List.wrap(tags), ",")}]  from=chat"
  end

  def look_has(rec \\ %{}), do: Room.SelfReportMatch.look_has(rec)
  def look_find(rec \\ %{}), do: Room.SelfReportMatch.look_find(rec)
  def look_shape(rec \\ %{}) do
    shape = rec[:shape] || @shape
    "ok  shape=#{shape}"
  end

  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [
      look_cast(pack.need),
      look_has(pack.has),
      look_find(pack.hit),
      look_shape(pack.need),
      look_complete()
    ]
  end

  def look(_), do: look(%{need: %{}, has: %{}, hit: %{}})

  @doc """
  Chat → cast Need with a shape preset → overlapping Has
  → mazel'd in-agent. Isolated. Sibling cast / Need.Shape
  LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-shape-" <> random_id()
    chat = Keyword.get(opts, :chat) || @chat
    shape = Keyword.get(opts, :shape) || @shape

    has = Room.SelfReportMatch.parse(Keyword.get(opts, :has) || "has: series-a")
    need = Room.SelfReportMatch.cast(:need, chat, shape: shape)
    claim = Room.SelfReportMatch.cast(:need, "claim: passionate visionary hunt for series-a", shape: shape)
    hit = Room.SelfReportMatch.match(has, need)
    missed = Room.SelfReportMatch.match(has, claim)

    with {:ok, found} <- Room.Find.query(hit.query || "series-a"),
         {:ok, session} <- keep_agent(prefix, hit) do
      card = List.first(found[:hits] || [])
      events = Enum.map(session.events || [], & &1.type)

      cond do
        need[:from] != "chat" or need[:cast] != "need" ->
          {:error, :cast_miss}

        need[:shape] != shape ->
          {:error, :shape_miss}

        need.source != "self_report" or has.source != "self_report" ->
          {:error, :not_self_report}

        need.tags != ["series-a"] or has.tags != ["series-a"] ->
          {:error, :tags_miss}

        not hit.ok or hit.handle != "kai@mazel" ->
          {:error, :overlap_miss}

        missed.ok or claim.curious != true or claim.tags != [] or claim[:shape] != nil ->
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
            shape: shape,
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
