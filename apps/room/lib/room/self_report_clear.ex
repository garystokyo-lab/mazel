defmodule Room.SelfReportClear do
  @moduledoc """
  Clear Need → find=none until a later recast.

  Distinct from self_report_cast / recast (those keep a
  live Need). Off PDF / badge / GH / score / wiki /
  morph / toolbelt.
  """

  @chat "looking for series-a"

  def chat, do: @chat

  def look_cast(rec \\ %{}), do: Room.SelfReportCast.look_cast(rec)
  def look_has(rec \\ %{}), do: Room.SelfReportMatch.look_has(rec)
  def look_find(rec \\ %{}), do: Room.SelfReportMatch.look_find(rec)
  def look_clear(_rec \\ %{}), do: "ok  clear=need  tags=[]"
  def look_miss, do: "error  find=series-a  match=none"

  def look_recast(rec \\ %{}) do
    tags = rec[:tags] || ["series-a"]
    "ok  recast=need  tags=[#{Enum.join(List.wrap(tags), ",")}]  from=chat"
  end

  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [
      look_cast(pack.need),
      look_has(pack.has),
      look_find(pack.hit),
      look_clear(pack.cleared),
      look_miss(),
      look_recast(pack.fresh),
      look_find(pack.again),
      look_complete()
    ]
  end

  def look(_) do
    look(%{
      need: %{},
      has: %{},
      hit: %{},
      cleared: %{},
      fresh: %{},
      again: %{}
    })
  end

  @doc """
  Cast → match → clear → miss → recast → match.
  Isolated. Sibling cast / recast LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-clear-" <> random_id()
    chat = Keyword.get(opts, :chat) || @chat

    has = Room.SelfReportMatch.parse(Keyword.get(opts, :has) || "has: series-a")
    need = Room.SelfReportMatch.cast(:need, chat)
    hit = Room.SelfReportMatch.match(has, need)
    cleared = Room.SelfReportMatch.clear(need)
    missed = Room.SelfReportMatch.match(has, cleared)
    fresh = Room.SelfReportMatch.recast(:need, chat, cleared)
    again = Room.SelfReportMatch.match(has, fresh)

    with {:ok, found} <- Room.Find.query(hit.query || "series-a"),
         {:ok, found_again} <- Room.Find.query(again.query || "series-a"),
         {:ok, session} <- keep_agent(prefix, again) do
      card = List.first(found[:hits] || [])
      card_again = List.first(found_again[:hits] || [])
      events = Enum.map(session.events || [], & &1.type)

      cond do
        need.tags != ["series-a"] or need[:from] != "chat" ->
          {:error, :cast_miss}

        has.tags != ["series-a"] or has.source != "self_report" ->
          {:error, :has_miss}

        not hit.ok or hit.handle != "kai@mazel" ->
          {:error, :overlap_miss}

        cleared.tags != [] or cleared[:cleared] != true or cleared[:clear] != "need" ->
          {:error, :clear_miss}

        missed.ok or missed.tags != [] ->
          {:error, :cleared_hit}

        fresh.tags != ["series-a"] or fresh[:recast] != "need" or fresh[:from] != "chat" ->
          {:error, :recast_miss}

        not again.ok or again.handle != "kai@mazel" ->
          {:error, :again_miss}

        is_nil(card) or card.handle != "kai@mazel" ->
          {:error, :find_miss}

        is_nil(card_again) or card_again.handle != "kai@mazel" ->
          {:error, :find_again_miss}

        session.status != :open or session.badge != nil or "morph.commit" in events ->
          {:error, :session_miss}

        humans_awake?(session) ->
          {:error, :human_woke}

        true ->
          pack = %{
            need: need,
            has: has,
            hit: hit,
            cleared: cleared,
            missed: missed,
            fresh: fresh,
            again: again,
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
