defmodule Room.InstallPasteBlank do
  @moduledoc """
  Blank / empty paste rejects. Pasted list stays.

  Distinct from install_paste_unknown_brains_stay
  (unknown id; unsupported_brain),
  install_paste_unknown_unlocked / paste_brains
  (unsupported_brain), and install_unpaste_missing
  (unpaste missing noop). Off PDF / badge / GH /
  score / wiki / morph / Consent / Session / Match.
  """

  def look_add, do: Room.InstallPasteBrains.look_add()
  def look_paste, do: Room.InstallPasteBrains.look_paste(:grok)
  def look_brains, do: "ok  brains=grok"
  def look_need(rec \\ %{}), do: Room.SelfReportToolbelt.look_need(rec)
  def look_unlocked, do: Room.SelfReportToolbelt.look_unlocked()
  def look_blank, do: "error  paste=  error=blank_brain"
  def look_crash, do: "ok  crash=none"

  def look(pack) when is_map(pack) do
    [
      look_add(),
      look_paste(),
      look_brains(),
      look_need(pack.need),
      look_unlocked(),
      look_blank(),
      look_brains(),
      look_unlocked(),
      look_crash()
    ]
  end

  def look(_), do: look(%{need: %{}})

  @doc """
  Add, paste grok, Need unlocks, blank paste rejects.
  Grok stays. Tools stay unlocked. No crash. Isolated.
  Sibling unknown_brains_stay / unknown_unlocked /
  paste_brains / unpaste_missing LOOK stays.
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
              "mazel-install-paste-blank-#{System.unique_integer([:positive])}"
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
         {:ok, _} <- find(root),
         {:ok, :blank_brain} <- safe_blank(root, ""),
         {:ok, _} <- find(root) do
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

        kept != [:grok] ->
          {:error, :list_changed}

        Room.Install.paste(root, "   ") != {:error, :blank_brain} ->
          {:error, :ws_leaked}

        Room.Install.paste(root, "unknown") != {:error, :unsupported_brain} ->
          {:error, :unknown_miss}

        Room.Install.pasted(root) != [:grok] ->
          {:error, :list_changed}

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
            paste: :blank_brain,
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

  defp safe_blank(root, brain) do
    try do
      case Room.Install.paste(root, brain) do
        {:error, :blank_brain} -> {:ok, :blank_brain}
        other -> other
      end
    rescue
      e -> {:error, {:crash, e}}
    end
  end
end
