defmodule Room.InstallUnlockRemove do
  @moduledoc """
  After Add Mazel unlocks, Remove Mazel locks again.

  Thin unlock → remove → lock. Distinct from
  install_remove_mazel (Has/Need stay labeled on lock
  lines), install_gate (Need/Have-before-Add, no remove),
  and install_add_mazel (add path only). Off PDF / badge /
  GH / score / wiki / morph / Consent / Session / Match.
  """

  def look_add, do: Room.InstallRemoveMazel.look_add()
  def look_need(rec \\ %{}), do: Room.SelfReportToolbelt.look_need(rec)
  def look_unlocked, do: Room.SelfReportToolbelt.look_unlocked()
  def look_remove, do: Room.InstallRemoveMazel.look_remove()
  def look_locked, do: "error  tools=locked  mazel_find=0"

  def look(pack) when is_map(pack) do
    [look_add(), look_need(pack.need), look_unlocked(), look_remove(), look_locked()]
  end

  def look(_), do: look(%{need: %{}})

  @doc """
  Add Mazel, Need unlocks, remove locks. Isolated.
  Sibling remove / gate / add LOOK stays.
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
              "mazel-install-unlock-remove-#{System.unique_integer([:positive])}"
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

    with {:ok, _} <- Room.Install.add(root),
         {:ok, _} <- Room.SelfReportMatch.put(root, need),
         {:ok, _} <- Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root}),
         {:ok, _} <- Room.Install.remove(root),
         {:error, :not_ready} <-
           Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root}) do
      cond do
        need.source != "self_report" or need.tags != ["series-a"] ->
          {:error, :not_self_report}

        not Room.Toolbelt.ready?(root) ->
          {:error, :belt_dropped}

        Room.SelfReportMatch.vault_need_count(root) < 1 ->
          {:error, :need_gone}

        Room.Install.added?(root) ->
          {:error, :still_added}

        not Room.Install.required?(root) ->
          {:error, :gate_gone}

        Room.Install.unlock(root) == :ok ->
          {:error, :still_open}

        Room.Toolbelt.proof_has_count(root) != 0 ->
          {:error, :proof_wrote}

        true ->
          pack = %{need: need, root: root}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end
end
