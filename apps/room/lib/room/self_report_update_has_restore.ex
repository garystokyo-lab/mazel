defmodule Room.SelfReportUpdateHasRestore do
  @moduledoc """
  Update Has away, then restore overlap. Find returns.

  Distinct from self_report_update_has (stops at
  find none), self_report_has_then_need (Need cast
  unlocks find), and self_report_recast (Need side
  replace). Off PDF / badge / GH / score / wiki /
  morph / toolbelt / talk-turns.
  """

  @restore "we have series-a"

  def restore_chat, do: @restore

  def look_need(rec \\ %{}), do: Room.SelfReportUpdateHas.look_need(rec)
  def look_has(rec \\ %{}), do: Room.SelfReportUpdateHas.look_has(rec)
  def look_find(rec \\ %{}), do: Room.SelfReportUpdateHas.look_find(rec)
  def look_update(rec \\ %{}), do: Room.SelfReportUpdateHas.look_update(rec)
  def look_miss, do: Room.SelfReportUpdateHas.look_miss()
  def look_complete, do: Room.SelfReportUpdateHas.look_complete()

  def look(pack) when is_map(pack) do
    Enum.take(Room.SelfReportUpdateHas.look(pack), 5) ++
      [
        look_update(pack.restored),
        look_find(pack.restored_hit),
        look_complete()
      ]
  end

  def look(_), do: look(%{need: %{}, has: %{}, hit: %{}, updated: %{}, restored: %{}, restored_hit: %{}})

  @doc """
  Update Has to cto (find none), then restore series-a.
  Find returns. Isolated. Sibling update_has /
  has_then_need / recast LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-update-has-restore-" <> random_id()

    with {:ok, prior} <-
           Room.SelfReportUpdateHas.demo(Keyword.put(opts, :context_id, prefix)),
         restored <-
           Room.SelfReportMatch.update_has(prior.updated, Keyword.get(opts, :restore) || @restore),
         {:ok, _} <- Room.SelfReportMatch.drop(prior.root, prior.updated),
         {:ok, _} <- Room.SelfReportMatch.put(prior.root, restored) do
      restored_hit = Room.SelfReportMatch.match(restored, prior.need)
      vaulted = Room.SelfReportMatch.find_vault(Room.SelfReportMatch.vault(prior.root, :has), prior.need)
      still_need = Room.SelfReportMatch.vault(prior.root, :need)
      events = Enum.map(prior.session.events || [], & &1.type)

      cond do
        prior.updated.tags != ["cto"] or prior.missed.ok ->
          {:error, :away_miss}

        restored.tags != ["series-a"] or restored[:replaced] != "cto" or
            restored[:replaces] != ["cto"] or restored[:update] != "has" ->
          {:error, :restore_miss}

        prior.need.tags != ["series-a"] or Room.SelfReportMatch.vault_need_count(prior.root) != 1 ->
          {:error, :need_moved}

        still_need == [] ->
          {:error, :need_gone}

        not restored_hit.ok or restored_hit.handle != "kai@mazel" ->
          {:error, :restore_miss}

        vaulted.ok == false or vaulted.handle != "kai@mazel" ->
          {:error, :vault_miss}

        Room.SelfReportMatch.vault_has_count(prior.root) != 1 ->
          {:error, :has_count}

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
