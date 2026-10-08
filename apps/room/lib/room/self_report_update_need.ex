defmodule Room.SelfReportUpdateNeed do
  @moduledoc """
  Update Need tags while Has stays fixed. Find is none.

  Need replaces tags; Has is unchanged. Distinct from
  self_report_recast (Need→cto AND Has already has cto
  → find hits), self_report_update_has / restore (Has
  side moves), and self_report_clear (Need cleared).
  Off PDF / badge / GH / score / wiki / morph /
  toolbelt / talk-turns.
  """

  @fresh "looking for cto"

  def fresh_chat, do: @fresh

  def look_need(rec \\ %{}), do: Room.SelfReportMatch.look_need(rec)
  def look_has(rec \\ %{}), do: Room.SelfReportMatch.look_has(rec)
  def look_find(rec \\ %{}), do: Room.SelfReportMatch.look_find(rec)

  def look_update(rec \\ %{}) do
    tags = rec[:tags] || ["cto"]
    old = rec[:replaced] || List.first(List.wrap(rec[:replaces])) || "series-a"
    "ok  update=need  tags=[#{Enum.join(List.wrap(tags), ",")}]  replaces=#{old}"
  end

  def look_miss_fresh, do: "error  find=cto  match=none  mazel'd=none"
  def look_miss_old, do: "error  find=series-a  match=none"
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [
      look_need(pack.need),
      look_has(pack.has),
      look_find(pack.hit),
      look_update(pack.updated),
      look_has(pack.has),
      look_miss_fresh(),
      look_miss_old(),
      look_complete()
    ]
  end

  def look(_), do: look(%{need: %{}, has: %{}, hit: %{}, updated: %{}})

  @doc """
  Match, update Need to cto, Has stays, find none.
  Isolated. Sibling recast / update_has / clear LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-update-need-" <> random_id()
    root = Keyword.get(opts, :root) || Path.join(System.tmp_dir!(), prefix)

    File.mkdir_p!(root)

    need = Room.SelfReportMatch.parse(Keyword.get(opts, :need) || "need: series-a")
    has = Room.SelfReportMatch.parse(Keyword.get(opts, :has) || "has: series-a")
    hit = Room.SelfReportMatch.match(has, need)
    updated = Room.SelfReportMatch.update_need(need, Keyword.get(opts, :fresh) || @fresh)

    with {:ok, _} <- Room.SelfReportMatch.put(root, need),
         {:ok, _} <- Room.SelfReportMatch.put(root, has),
         {:ok, found} <- Room.Find.query(hit.query || "series-a"),
         {:ok, _} <- Room.SelfReportMatch.drop_need(root, need),
         {:ok, _} <- Room.SelfReportMatch.put(root, updated),
         {:ok, session} <- keep_agent(prefix, hit) do
      missed = Room.SelfReportMatch.match(has, updated)
      vaulted = Room.SelfReportMatch.find_vault(Room.SelfReportMatch.vault(root, :has), updated)
      still_has = Room.SelfReportMatch.vault(root, :has)
      events = Enum.map(session.events || [], & &1.type)
      card = List.first(found[:hits] || [])

      cond do
        need.source != "self_report" or need.tags != ["series-a"] ->
          {:error, :need_miss}

        has.source != "self_report" or has.tags != ["series-a"] ->
          {:error, :has_miss}

        not hit.ok or hit.handle != "kai@mazel" ->
          {:error, :overlap_miss}

        updated.tags != ["cto"] or updated[:replaced] != "series-a" or
            updated[:replaces] != ["series-a"] or updated[:update] != "need" ->
          {:error, :update_miss}

        Room.SelfReportMatch.update_need(has, @fresh).tags != ["series-a"] ->
          {:error, :has_updated}

        missed.ok or missed.tags != [] or missed.error != "no_overlap" ->
          {:error, :stale_hit}

        vaulted.ok or vaulted.error != "no_overlap" ->
          {:error, :stale_vault}

        Room.SelfReportMatch.vault_need_count(root) != 1 ->
          {:error, :need_gone}

        still_has == [] or Room.SelfReportMatch.vault_has_count(root) != 1 ->
          {:error, :has_gone}

        Enum.any?(still_has, &(&1.tags != ["series-a"])) ->
          {:error, :has_moved}

        is_nil(card) or card.handle != "kai@mazel" ->
          {:error, :find_miss}

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
            updated: updated,
            missed: missed,
            vaulted: vaulted,
            find: found,
            session: session,
            complete: :agent,
            root: root
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
