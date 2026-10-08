defmodule Room.InstallUnpasteTwice do
  @moduledoc """
  Unpaste the same brain twice. Second is noop.

  List and unlock stay. No crash. Distinct from
  install_unpaste_one (single unpaste of one of two),
  install_unpaste_last (unpaste last → empty),
  install_unpaste_missing (never-pasted noop), and
  install_remove_twice (Remove Mazel twice). Off PDF /
  badge / GH / score / wiki / morph / Consent / Session /
  Match.
  """

  @brains [:grok, :hermes]

  def brains, do: @brains

  def look_add, do: Room.InstallPasteBrains.look_add()
  def look_paste(brain), do: Room.InstallPasteBrains.look_paste(brain)
  def look_both, do: "ok  brains=grok,hermes"
  def look_need(rec \\ %{}), do: Room.SelfReportToolbelt.look_need(rec)
  def look_unlocked, do: Room.SelfReportToolbelt.look_unlocked()
  def look_unpaste, do: "ok  unpaste=grok"
  def look_kept, do: "ok  brains=hermes"
  def look_again, do: "ok  unpaste=grok  noop=true"
  def look_crash, do: "ok  crash=none"

  def look(pack) when is_map(pack) do
    [look_add()] ++
      Enum.map(@brains, &look_paste/1) ++
      [
        look_both(),
        look_need(pack.need),
        look_unlocked(),
        look_unpaste(),
        look_kept(),
        look_again(),
        look_kept(),
        look_unlocked(),
        look_crash()
      ]
  end

  def look(_), do: look(%{need: %{}})

  @doc """
  Add, paste grok then hermes, Need unlocks, unpaste
  grok, unpaste grok again. Second is noop. Hermes
  stays. Tools stay unlocked. Isolated. Sibling
  unpaste_one / unpaste_last / unpaste_missing /
  remove_twice LOOK stays.
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
              "mazel-install-unpaste-twice-#{System.unique_integer([:positive])}"
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
         {:ok, _} <- find(root),
         {:ok, dropped} <- safe_unpaste(root, :grok),
         {:ok, again} <- safe_unpaste(root, :grok),
         {:ok, _} <- find(root) do
      kept = Room.Install.pasted(root)

      cond do
        added.button != :ok or added.idempotent != false ->
          {:error, :add_miss}

        not Room.Install.added?(root) ->
          {:error, :add_gone}

        grok.brain != :grok or grok.snippet != :ok ->
          {:error, :grok_miss}

        hermes.brain != :hermes or hermes.snippet != :ok ->
          {:error, :hermes_miss}

        grok.wipe != :none or hermes.wipe != :none ->
          {:error, :wiped}

        hermes.brains != @brains ->
          {:error, :both_miss}

        dropped.unpaste != :grok or dropped[:noop] == true ->
          {:error, :unpaste_miss}

        dropped.brains != [:hermes] or dropped.added != true ->
          {:error, :kept_miss}

        again.unpaste != :grok or again.noop != true ->
          {:error, :not_noop}

        again.added != true or again.brains != [:hermes] ->
          {:error, :list_changed}

        kept != [:hermes] ->
          {:error, :list_changed}

        :grok in kept ->
          {:error, :grok_stayed}

        :hermes not in kept ->
          {:error, :hermes_gone}

        need.source != "self_report" or need.tags != ["series-a"] ->
          {:error, :not_self_report}

        not Room.Toolbelt.ready?(root) ->
          {:error, :belt_miss}

        Room.Install.unlock(root) != :ok ->
          {:error, :locked}

        Room.Install.unlock_count(root) != 1 ->
          {:error, :unlock_count}

        Room.Toolbelt.proof_has_count(root) != 0 ->
          {:error, :proof_wrote}

        true ->
          pack = %{
            root: root,
            need: need,
            added: added,
            grok: grok,
            hermes: hermes,
            dropped: dropped,
            again: again,
            brains: kept,
            crash: :none
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp find(root) do
    Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root})
  end

  defp safe_unpaste(root, brain) do
    try do
      Room.Install.unpaste(root, brain)
    rescue
      e -> {:error, {:crash, e}}
    end
  end
end