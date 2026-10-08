defmodule Room.InstallUnpasteLast do
  @moduledoc """
  Unpaste the last brain. Brains empty. Tools stay
  unlocked. Add stays.

  Distinct from install_unpaste_one (one of two remains),
  install_unlock_remove / install_remove_* (Remove Mazel
  locks tools), and install_paste_both_stay (no unpaste).
  Off PDF / badge / GH / score / wiki / morph / Consent /
  Session / Match.
  """

  def look_add, do: Room.InstallPasteBrains.look_add()
  def look_paste, do: Room.InstallPasteBrains.look_paste(:grok)
  def look_one, do: "ok  brains=grok"
  def look_need(rec \\ %{}), do: Room.SelfReportToolbelt.look_need(rec)
  def look_unlocked, do: Room.SelfReportToolbelt.look_unlocked()
  def look_unpaste, do: "ok  unpaste=grok"
  def look_empty, do: "ok  brains="

  def look(pack) when is_map(pack) do
    [
      look_add(),
      look_paste(),
      look_one(),
      look_need(pack.need),
      look_unlocked(),
      look_unpaste(),
      look_empty(),
      look_unlocked(),
      look_add()
    ]
  end

  def look(_), do: look(%{need: %{}})

  @doc """
  Add, paste grok, Need unlocks, unpaste last brain.
  Brains empty. Add stays. Tools stay unlocked.
  Isolated. Sibling unpaste_one / unlock_remove /
  both_stay LOOK stays.
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
              "mazel-install-unpaste-last-#{System.unique_integer([:positive])}"
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
         {:ok, _} <- Room.SelfReportMatch.put(root, need),
         {:ok, _} <- Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root}),
         {:ok, dropped} <- Room.Install.unpaste(root, :grok),
         {:ok, _} <- Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root}),
         {:ok, stayed} <- Room.Install.add(root) do
      kept = Room.Install.pasted(root)

      cond do
        added.button != :ok or added.idempotent != false ->
          {:error, :add_miss}

        not Room.Install.added?(root) ->
          {:error, :add_gone}

        grok.brain != :grok or grok.snippet != :ok ->
          {:error, :grok_miss}

        grok.brains != [:grok] or grok.wipe != :none ->
          {:error, :brains_miss}

        dropped.unpaste != :grok or dropped.added != true ->
          {:error, :unpaste_miss}

        dropped.brains != [] or kept != [] ->
          {:error, :not_empty}

        :grok in kept or :hermes in kept ->
          {:error, :brain_stayed}

        stayed.button != :ok ->
          {:error, :add_gone}

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
            dropped: dropped,
            stayed: stayed,
            brains: kept
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end
end
