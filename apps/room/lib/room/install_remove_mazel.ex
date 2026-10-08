defmodule Room.InstallRemoveMazel do
  @moduledoc """
  Remove Add Mazel. Tools lock again.

  Need / Has stay. Distinct from install_add_mazel
  (add unlocks). Off PDF / badge / GH / score / wiki /
  morph / Consent / Session / Match features.
  """

  def look_add, do: "ok  add=mazel  button=ok"
  def look_has(rec \\ %{}), do: Room.SelfReportToolbelt.look_has(rec)
  def look_need(rec \\ %{}), do: Room.SelfReportToolbelt.look_need(rec)
  def look_unlocked, do: Room.SelfReportToolbelt.look_unlocked()
  def look_remove, do: "ok  remove=mazel  button=gone"
  def look_locked_has, do: "error  tools=locked  mazel_find=0  has=self_report"
  def look_locked_need, do: "error  tools=locked  mazel_find=0  need=self_report"

  def look(pack) when is_map(pack) do
    [
      look_add(),
      look_has(pack.has),
      look_unlocked(),
      look_remove(),
      look_locked_has(),
      look_need(pack.need),
      look_locked_need()
    ]
  end

  def look(_), do: look(%{has: %{}, need: %{}})

  @doc """
  Add Mazel, self-report unlocks, remove locks again.
  Need / Has remain. Isolated. Sibling add LOOK stays.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path =
            Path.join(System.tmp_dir!(), "mazel-install-remove-#{System.unique_integer([:positive])}")

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
    has_root = Path.join(root, "has")
    need_root = Path.join(root, "need")
    File.mkdir_p!(has_root)
    File.mkdir_p!(need_root)

    has = Room.SelfReportMatch.parse("has: series-a")
    need = Room.SelfReportMatch.parse("need: series-a")

    with {:ok, _} <- Room.Install.add(has_root),
         {:ok, _} <- Room.Install.add(need_root),
         {:ok, _} <- Room.SelfReportMatch.put(has_root, has),
         {:ok, _} <- Room.SelfReportMatch.put(need_root, need),
         {:ok, _} <- Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => has_root}),
         {:ok, _} <- Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => need_root}),
         {:ok, _} <- Room.Install.remove(has_root),
         {:ok, _} <- Room.Install.remove(need_root),
         {:error, :not_ready} <-
           Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => has_root}),
         {:error, :not_ready} <-
           Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => need_root}) do
      cond do
        has.source != "self_report" or need.source != "self_report" ->
          {:error, :not_self_report}

        not Room.Toolbelt.ready?(has_root) or not Room.Toolbelt.ready?(need_root) ->
          {:error, :belt_dropped}

        Room.SelfReportMatch.vault_has_count(has_root) < 1 ->
          {:error, :has_gone}

        Room.SelfReportMatch.vault_need_count(need_root) < 1 ->
          {:error, :need_gone}

        Room.Install.added?(has_root) or Room.Install.added?(need_root) ->
          {:error, :still_added}

        not Room.Install.required?(has_root) or not Room.Install.required?(need_root) ->
          {:error, :gate_gone}

        Room.Install.unlock(has_root) == :ok or Room.Install.unlock(need_root) == :ok ->
          {:error, :still_open}

        Room.Toolbelt.proof_has_count(has_root) != 0 or Room.Toolbelt.proof_has_count(need_root) != 0 ->
          {:error, :proof_wrote}

        true ->
          pack = %{has: has, need: need, has_root: has_root, need_root: need_root}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end
end
