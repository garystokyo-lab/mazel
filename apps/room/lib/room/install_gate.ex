defmodule Room.InstallGate do
  @moduledoc """
  Need / Have alone stay locked until Add Mazel.

  Distinct from install_add_mazel (add first, then empty,
  then unlock) and self_report_toolbelt (no gate). Off
  PDF / badge / GH / score / wiki / morph / Consent /
  Session / Match features.
  """

  def look_has(rec \\ %{}), do: Room.SelfReportToolbelt.look_has(rec)
  def look_need(rec \\ %{}), do: Room.SelfReportToolbelt.look_need(rec)
  def look_none, do: Room.InstallAddMazel.look_none()
  def look_add, do: Room.InstallRemoveMazel.look_add()
  def look_unlocked, do: Room.SelfReportToolbelt.look_unlocked()

  def look(pack) when is_map(pack) do
    [
      look_has(pack.has),
      look_none(),
      look_need(pack.need),
      look_none(),
      look_add(),
      look_unlocked()
    ]
  end

  def look(_), do: look(%{has: %{}, need: %{}})

  @doc """
  Gate on. Has / Need persist. Tools stay locked until
  Add Mazel. Isolated. Sibling add / remove / toolbelt stay.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path =
            Path.join(System.tmp_dir!(), "mazel-install-gate-#{System.unique_integer([:positive])}")

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
    File.mkdir_p!(Room.Install.gate_dir(root))

    has = Room.SelfReportMatch.parse("has: series-a")
    need = Room.SelfReportMatch.parse("need: series-a")

    with {:ok, _} <- Room.SelfReportMatch.put(root, has),
         {:error, :not_ready} <-
           Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root}),
         {:ok, _} <- Room.SelfReportMatch.put(root, need),
         {:error, :not_ready} <-
           Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root}),
         {:ok, _} <- Room.Install.add(root),
         {:ok, _} <- Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root}) do
      cond do
        has.source != "self_report" or need.source != "self_report" ->
          {:error, :not_self_report}

        not Room.Install.required?(root) ->
          {:error, :gate_miss}

        not Room.Toolbelt.ready?(root) ->
          {:error, :belt_miss}

        not Room.Install.added?(root) ->
          {:error, :add_miss}

        Room.Install.unlock(root) != :ok ->
          {:error, :still_locked}

        Room.Toolbelt.proof_has_count(root) != 0 ->
          {:error, :proof_wrote}

        true ->
          pack = %{has: has, need: need, root: root}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end
end
