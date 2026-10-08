defmodule Room.InstallAddMazel do
  @moduledoc """
  Add Mazel button unlocks mazel tools on the self-report path.

  add=none stays locked. Empty vault stays locked. One
  self-report Has or Need unlocks after the button.
  Distinct from install / toolbelt / toolbelt_ready (proof
  Has / Switzerland paste) and self_report_toolbelt (no
  Add Mazel gate). Off PDF / badge / GH / score / wiki / morph.
  """

  def look_none, do: "error  add=none  tools=locked  mazel_find=0"

  def look_add do
    brains = Room.Install.brains() |> Enum.map(&to_string/1) |> Enum.join("|")
    "ok  add=mazel  button=ok  paste=#{brains}"
  end

  def look_empty, do: Room.SelfReportToolbelt.look_empty()
  def look_has(rec \\ %{}), do: Room.SelfReportToolbelt.look_has(rec)
  def look_need(rec \\ %{}), do: Room.SelfReportToolbelt.look_need(rec)
  def look_unlocked, do: Room.SelfReportToolbelt.look_unlocked()

  def look(pack) when is_map(pack) do
    [
      look_none(),
      look_add(),
      look_empty(),
      look_has(pack.has),
      look_unlocked(),
      look_need(pack.need),
      look_unlocked()
    ]
  end

  def look(_), do: look(%{has: %{}, need: %{}})

  @doc """
  Gate on, no button → locked. Button, empty → locked.
  Self-report Has or Need unlocks. Isolated.
  Sibling install / toolbelt / self_report_toolbelt LOOK stays.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path =
            Path.join(System.tmp_dir!(), "mazel-install-add-#{System.unique_integer([:positive])}")

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
    none = Path.join(root, "none")
    empty = Path.join(root, "empty")
    has_root = Path.join(root, "has")
    need_root = Path.join(root, "need")
    File.mkdir_p!(none)
    File.mkdir_p!(empty)
    File.mkdir_p!(has_root)
    File.mkdir_p!(need_root)

    has = Room.SelfReportMatch.parse("has: series-a")
    need = Room.SelfReportMatch.parse("need: series-a")
    claim = Room.SelfReportMatch.parse("claim: passionate visionary hunt for series-a")

    File.mkdir_p!(Room.Install.gate_dir(none))

    with {:ok, _} <- Room.SelfReportMatch.put(none, has),
         {:error, :not_ready} <-
           Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => none}),
         {:ok, _} <- Room.Install.add(empty),
         {:ok, _} <- Room.Install.add(has_root),
         {:ok, _} <- Room.Install.add(need_root),
         {:error, :curious} <- Room.SelfReportMatch.put(empty, claim),
         {:error, :not_ready} <-
           Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => empty}),
         {:ok, _} <- Room.SelfReportMatch.put(has_root, has),
         {:ok, _} <- Room.SelfReportMatch.put(need_root, need),
         {:ok, _} <- Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => has_root}),
         {:ok, _} <- Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => need_root}) do
      cond do
        not Room.Toolbelt.ready?(none) or Room.Install.added?(none) ->
          {:error, :none_miss}

        Room.Install.unlock(none) == :ok ->
          {:error, :gate_miss}

        true ->
          check_rest(has, need, none, empty, has_root, need_root, claim)
      end
    end
  end

  defp check_rest(has, need, none, empty, has_root, need_root, claim) do
    cond do
      has.source != "self_report" or need.source != "self_report" ->
        {:error, :not_self_report}

      Room.Install.added?(empty) != true or Room.Toolbelt.ready?(empty) ->
        {:error, :empty_ready}

      Room.Install.unlock(empty) == :ok ->
        {:error, :empty_ready}

      not Room.Install.added?(has_root) or not Room.Toolbelt.ready?(has_root) ->
        {:error, :has_locked}

      Room.Install.unlock(has_root) != :ok ->
        {:error, :has_locked}

      Room.Toolbelt.proof_has_count(has_root) != 0 or Room.Toolbelt.need_count(has_root) != 0 ->
        {:error, :proof_wrote}

      not Room.Install.added?(need_root) or not Room.Toolbelt.ready?(need_root) ->
        {:error, :need_locked}

      Room.Install.unlock(need_root) != :ok ->
        {:error, :need_locked}

      Room.Toolbelt.proof_has_count(need_root) != 0 ->
        {:error, :proof_wrote}

      claim.curious != true or claim.tags != [] ->
        {:error, :claim_wrote}

      Room.Install.brains() != [:cursor, :grok, :hermes, :muse] ->
        {:error, :brains_miss}

      true ->
        pack = %{has: has, need: need, none: none, empty: empty}
        {:ok, Map.put(pack, :lines, look(pack))}
    end
  end
end
