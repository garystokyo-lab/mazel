defmodule Room.SelfReportShapeMismatch do
  @moduledoc """
  Wrong Need / Has shapes still tag-match.

  LOOK labels shape=mismatch. Not a hard block. Distinct
  from self_report_shape (matching shape). Off PDF / badge /
  GH / score / wiki / morph / toolbelt.
  """

  @chat "looking for series-a"
  @need_shape :founder_investors
  @has_shape :icp_pain

  def chat, do: @chat
  def need_shape, do: @need_shape
  def has_shape, do: @has_shape

  def look_cast(rec \\ %{}) do
    Room.SelfReportShape.look_cast(rec)
  end

  def look_has(rec \\ %{}) do
    tags = rec[:tags] || ["series-a"]
    shape = rec[:shape] || @has_shape
    "ok  has=self_report  tags=[#{Enum.join(List.wrap(tags), ",")}]  shape=#{shape}"
  end

  def look_find(rec \\ %{}), do: Room.SelfReportMatch.look_find(rec)

  def look_mismatch(rec \\ %{}) do
    need = rec[:need_shape] || rec[:need][:shape] || @need_shape
    has = rec[:has_shape] || rec[:has][:shape] || @has_shape
    "error  shape=mismatch  need=#{need}  has=#{has}"
  end

  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [
      look_cast(pack.need),
      look_has(pack.has),
      look_find(pack.hit),
      look_mismatch(pack),
      look_complete()
    ]
  end

  def look(_), do: look(%{need: %{}, has: %{}, hit: %{}})

  @doc """
  Chat Need shape ≠ Has shape. Tags still mazel'd.
  Isolated. Sibling shape LOOK stays (no mismatch).
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-shape-mismatch-" <> random_id()
    chat = Keyword.get(opts, :chat) || @chat
    need_shape = Keyword.get(opts, :need_shape) || @need_shape
    has_shape = Keyword.get(opts, :has_shape) || @has_shape

    has = Room.SelfReportMatch.cast(:has, Keyword.get(opts, :has_chat) || "we have series-a", shape: has_shape)
    need = Room.SelfReportMatch.cast(:need, chat, shape: need_shape)
    claim = Room.SelfReportMatch.cast(:need, "claim: passionate visionary hunt for series-a", shape: need_shape)
    hit = Room.SelfReportMatch.match(has, need)
    missed = Room.SelfReportMatch.match(has, claim)

    with {:ok, found} <- Room.Find.query(hit.query || "series-a"),
         {:ok, session} <- keep_agent(prefix, hit) do
      card = List.first(found[:hits] || [])
      events = Enum.map(session.events || [], & &1.type)

      cond do
        need[:shape] != need_shape or has[:shape] != has_shape ->
          {:error, :shape_miss}

        need.tags != ["series-a"] or has.tags != ["series-a"] ->
          {:error, :tags_miss}

        not hit.ok or hit.handle != "kai@mazel" ->
          {:error, :blocked}

        hit.shape != :mismatch or hit.shape_fit != false ->
          {:error, :mismatch_miss}

        hit.need_shape != need_shape or hit.has_shape != has_shape ->
          {:error, :mismatch_miss}

        missed.ok or claim.curious != true ->
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
            need_shape: need_shape,
            has_shape: has_shape,
            claim: claim,
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
