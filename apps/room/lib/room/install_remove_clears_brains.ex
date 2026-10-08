defmodule Room.InstallRemoveClearsBrains do
  @moduledoc """
  Remove Mazel locks tools and clears pasted brains.

  Distinct from install_unlock_remove /
  install_second_brain_remove (Remove locks; no brains=
  clear beat), install_unpaste_* /
  install_repaste_after_empty (Add stays; tools unlocked),
  and install_paste_both_stay (two stay; no Remove).
  Off PDF / badge / GH / score / wiki / morph / Consent /
  Session / Match.
  """

  @brains [:grok, :hermes]

  def brains, do: @brains

  def look_add, do: Room.InstallPasteBrains.look_add()
  def look_paste(brain), do: Room.InstallPasteBrains.look_paste(brain)
  def look_brains, do: "ok  brains=grok,hermes"
  def look_need(rec \\ %{}), do: Room.SelfReportToolbelt.look_need(rec)
  def look_unlocked, do: Room.SelfReportToolbelt.look_unlocked()
  def look_remove, do: Room.InstallUnlockRemove.look_remove()
  def look_locked, do: Room.InstallUnlockRemove.look_locked()
  def look_empty, do: Room.InstallUnpasteLast.look_empty()

  def look(pack) when is_map(pack) do
    [look_add()] ++
      Enum.map(@brains, &look_paste/1) ++
      [
        look_brains(),
        look_need(pack.need),
        look_unlocked(),
        look_remove(),
        look_locked(),
        look_empty()
      ]
  end

  def look(_), do: look(%{need: %{}})

  @doc """
  Add, paste grok+hermes, Need unlocks, Remove locks
  and clears brains. Isolated. Sibling unlock_remove /
  second_brain_remove / both_stay / unpaste_last LOOK
  stays.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path =
            Path.join(
              System.tmp_dir!(),
              "mazel-install-remove-clears-brains-#{System.unique_integer([:positive])}"
            )

          File.mkdir_p!(path)
          {path, true}
      end

    try do
      demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp demo_on(root) do
    File.mkdir_p!(root)
    need = Room.SelfReportMatch.parse("need: series-a")

    with {:ok, added} <- Room.Install.add(root),
         {:ok, grok} <- Room.Install.paste(root, :grok),
         {:ok, hermes} <- Room.Install.paste(root, :hermes),
         {:ok, _} <- Room.SelfReportMatch.put(root, need),
         {:ok, _} <- Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root}),
         {:ok, removed} <- Room.Install.remove(root),
         {:error, :not_ready} <-
           Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root}) do
      kept = Room.Install.pasted(root)

      cond do
        added.button != :ok or added.idempotent != false ->
          {:error, :add_miss}

        grok.brain != :grok or grok.snippet != :ok ->
          {:error, :grok_miss}

        hermes.brain != :hermes or hermes.snippet != :ok ->
          {:error, :hermes_miss}

        hermes.brains != @brains ->
          {:error, :brains_miss}

        need.source != "self_report" or need.tags != ["series-a"] ->
          {:error, :not_self_report}

        not Room.Toolbelt.ready?(root) ->
          {:error, :belt_dropped}

        Room.SelfReportMatch.vault_need_count(root) < 1 ->
          {:error, :need_gone}

        removed.button != :gone or removed.added != false ->
          {:error, :remove_miss}

        Room.Install.added?(root) ->
          {:error, :still_added}

        not Room.Install.required?(root) ->
          {:error, :gate_gone}

        Room.Install.unlock(root) == :ok ->
          {:error, :still_open}

        kept != [] or :grok in kept or :hermes in kept ->
          {:error, :brains_stayed}

        Room.Install.paste(root, :grok) != {:error, :not_added} ->
          {:error, :paste_after_remove}

        look_brains() == Room.InstallPasteBothStay.look_stay() ->
          {:error, :look_same}

        look_empty() != "ok  brains=" ->
          {:error, :empty_miss}

        Room.Toolbelt.proof_has_count(root) != 0 ->
          {:error, :proof_wrote}

        true ->
          pack = %{
            root: root,
            need: need,
            added: added,
            grok: grok,
            hermes: hermes,
            removed: removed,
            brains: kept
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end
end