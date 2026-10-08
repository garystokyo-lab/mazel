defmodule Room.InstallPasteUnknownBrainsStay do
  @moduledoc """
  Unknown paste rejects. Pasted list stays. No crash.

  Distinct from install_paste_unknown_unlocked (unknown
  reject; tools stay unlocked; no brains= before/after),
  install_paste_brains (unknown reject alone; no prior
  paste list stay), and install_unpaste_missing (unpaste
  missing noop). Off PDF / badge / GH / score / wiki /
  morph / Consent / Session / Match.
  """

  def look_add, do: Room.InstallPasteBrains.look_add()
  def look_paste, do: Room.InstallPasteBrains.look_paste(:grok)
  def look_brains, do: "ok  brains=grok"
  def look_need(rec \\ %{}), do: Room.SelfReportToolbelt.look_need(rec)
  def look_unlocked, do: Room.SelfReportToolbelt.look_unlocked()
  def look_unknown, do: Room.InstallPasteBrains.look_unknown()
  def look_crash, do: "ok  crash=none"

  def look(pack) when is_map(pack) do
    [
      look_add(),
      look_paste(),
      look_brains(),
      look_need(pack.need),
      look_unlocked(),
      look_unknown(),
      look_brains(),
      look_unlocked(),
      look_crash()
    ]
  end

  def look(_), do: look(%{need: %{}})

  @doc """
  Add, paste grok, Need unlocks, unknown paste rejects.
  Grok stays. Tools stay unlocked. No crash. Isolated.
  Sibling unknown_unlocked / paste_brains /
  unpaste_missing LOOK stays.
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
              "mazel-install-paste-unknown-brains-stay-#{System.unique_integer([:positive])}"
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
         {:ok, :unsupported_brain} <- safe_unknown(root),
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

        :unknown in kept or :ghost in kept ->
          {:error, :unknown_wrote}

        Room.Install.paste(root, :ghost) != {:error, :unsupported_brain} ->
          {:error, :ghost_leaked}

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
            paste: :unsupported_brain,
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

  defp safe_unknown(root) do
    try do
      case Room.Install.paste(root, "unknown") do
        {:error, :unsupported_brain} -> {:ok, :unsupported_brain}
        other -> other
      end
    rescue
      e -> {:error, {:crash, e}}
    end
  end
end
