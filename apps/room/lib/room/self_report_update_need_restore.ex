defmodule Room.SelfReportUpdateNeedRestore do
  @moduledoc """
  Update Need away, then restore overlap. Find returns.

  Distinct from self_report_update_need (stops at
  find none), self_report_update_has_restore (Has
  side restore), and self_report_recast (Need→cto
  with Has already cto → hit). Off PDF / badge /
  GH / score / wiki / morph / toolbelt / talk-turns.
  """

  @restore "looking for series-a"

  def restore_chat, do: @restore

  def look_need(rec \\ %{}), do: Room.SelfReportUpdateNeed.look_need(rec)
  def look_has(rec \\ %{}), do: Room.SelfReportUpdateNeed.look_has(rec)
  def look_find(rec \\ %{}), do: Room.SelfReportUpdateNeed.look_find(rec)
  def look_update(rec \\ %{}), do: Room.SelfReportUpdateNeed.look_update(rec)
  def look_miss, do: Room.SelfReportUpdateNeed.look_miss_fresh()
  def look_complete, do: Room.SelfReportUpdateNeed.look_complete()

  def look(pack) when is_map(pack) do
    [
      look_need(pack.need),
      look_has(pack.has),
      look_find(pack.hit),
      look_update(pack.updated),
      look_miss(),
      look_update(pack.restored),
      look_find(pack.restored_hit),
      look_complete()
    ]
  end

  def look(_) do
    look(%{need: %{}, has: %{}, hit: %{}, updated: %{}, restored: %{}, restored_hit: %{}})
  end

  @doc """
  Update Need to cto (find none), then restore series-a.
  Find returns. Isolated. Sibling update_need /
  update_has_restore / recast LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-update-need-restore-" <> random_id()

    with {:ok, prior} <-
           Room.SelfReportUpdateNeed.demo(Keyword.put(opts, :context_id, prefix)),
         restored <-
           Room.SelfReportMatch.update_need(prior.updated, Keyword.get(opts, :restore) || @restore),
         {:ok, _} <- Room.SelfReportMatch.drop_need(prior.root, prior.updated),
         {:ok, _} <- Room.SelfReportMatch.put(prior.root, restored) do
      restored_hit = Room.SelfReportMatch.match(prior.has, restored)

      vaulted =
        Room.SelfReportMatch.find_vault(Room.SelfReportMatch.vault(prior.root, :has), restored)

      still_has = Room.SelfReportMatch.vault(prior.root, :has)
      events = Enum.map(prior.session.events || [], & &1.type)

      cond do
        prior.updated.tags != ["cto"] or prior.missed.ok ->
          {:error, :away_miss}

        restored.tags != ["series-a"] or restored[:replaced] != "cto" or
            restored[:replaces] != ["cto"] or restored[:update] != "need" ->
          {:error, :restore_miss}

        prior.has.tags != ["series-a"] or Room.SelfReportMatch.vault_has_count(prior.root) != 1 ->
          {:error, :has_moved}

        still_has == [] or Enum.any?(still_has, &(&1.tags != ["series-a"])) ->
          {:error, :has_gone}

        not restored_hit.ok or restored_hit.handle != "kai@mazel" ->
          {:error, :restore_miss}

        vaulted.ok == false or vaulted.handle != "kai@mazel" ->
          {:error, :vault_miss}

        Room.SelfReportMatch.vault_need_count(prior.root) != 1 ->
          {:error, :need_count}

        prior.session.status != :open or prior.session.badge != nil or
            "morph.commit" in events ->
          {:error, :session_miss}

        "talk" in events ->
          {:error, :talked}

        humans_awake?(prior.session) ->
          {:error, :human_woke}

        true ->
          pack =
            Map.merge(prior, %{
              restored: restored,
              restored_hit: restored_hit,
              restored_vault: vaulted
            })

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end