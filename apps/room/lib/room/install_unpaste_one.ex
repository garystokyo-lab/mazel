defmodule Room.InstallUnpasteOne do
  @moduledoc """
  Unpaste one of two brains. The other stays. Tools stay
  unlocked. Add stays.

  Distinct from install_paste_both_stay (two stay; no
  unpaste), install_second_brain_remove /
  install_unlock_remove (Remove Mazel locks tools), and
  install_paste_same_twice (idempotent same paste). Off
  PDF / badge / GH / score / wiki / morph / Consent /
  Session / Match.
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

  def look(pack) when is_map(pack) do
    [look_add()] ++
      Enum.map(@brains, &look_paste/1) ++
      [look_both(), look_need(pack.need), look_unlocked(), look_unpaste(), look_kept(), look_unlocked()]
  end

  def look(_), do: look(%{need: %{}})

  @doc """
  Add, paste grok then hermes, Need unlocks, unpaste grok.
  Hermes stays. Tools stay unlocked. Isolated. Sibling
  both_stay / second_brain_remove / same_twice /
  unlock_remove LOOK stays.
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
              "mazel-install-unpaste-one-#{System.unique_integer([:positive])}"
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
         {:ok, dropped} <- Room.Install.unpaste(root, :grok),
         {:ok, _} <- Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root}) do
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

        dropped.unpaste != :grok or dropped.added != true ->
          {:error, :unpaste_miss}

        dropped.brains != [:hermes] or kept != [:hermes] ->
          {:error, :kept_miss}

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
            brains: kept
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end
end
