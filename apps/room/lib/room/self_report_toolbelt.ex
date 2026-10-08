defmodule Room.SelfReportToolbelt do
  @moduledoc """
  One self-report Need or Has unlocks mazel_find.

  Empty vault stays locked. Persists under index/self_report/
  — never proof Has. Distinct from self_report_match / overlap
  / why / check / need_ttl (no tools=). Off PDF / badge / GH /
  score / wiki / morph.
  """

  def look_has(rec \\ %{}), do: Room.SelfReportMatch.look_has(rec)
  def look_need(rec \\ %{}), do: Room.SelfReportMatch.look_need(rec)
  def look_unlocked, do: "ok  tools=unlocked  mazel_find=1"
  def look_empty, do: "error  vault=empty  tools=locked  mazel_find=0"

  def look(pack) when is_map(pack) do
    [
      look_has(pack.has),
      look_unlocked(),
      look_empty(),
      look_need(pack.need),
      look_unlocked()
    ]
  end

  def look(_), do: look(%{has: %{}, need: %{}})

  @doc """
  Has-only vault unlocks. Empty locks. Need-only unlocks.
  Isolated. Sibling self-report LOOK stays.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path =
            Path.join(System.tmp_dir!(), "mazel-self-report-toolbelt-#{System.unique_integer([:positive])}")

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
    empty = Path.join(root, "empty")
    need_root = Path.join(root, "need")
    File.mkdir_p!(has_root)
    File.mkdir_p!(empty)
    File.mkdir_p!(need_root)

    has = Room.SelfReportMatch.parse("has: series-a")
    need = Room.SelfReportMatch.parse("need: series-a")
    claim = Room.SelfReportMatch.parse("claim: passionate visionary hunt for series-a")

    with {:ok, _} <- Room.SelfReportMatch.put(has_root, has),
         {:error, :curious} <- Room.SelfReportMatch.put(empty, claim),
         {:ok, _} <- Room.SelfReportMatch.put(need_root, need),
         {:ok, _} <- Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => has_root}),
         {:error, :not_ready} <-
           Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => empty}),
         {:ok, _} <- Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => need_root}) do
      cond do
        has.source != "self_report" or need.source != "self_report" ->
          {:error, :not_self_report}

        Room.SelfReportMatch.vault_has_count(has_root) != 1 or
            Room.SelfReportMatch.vault_need_count(has_root) != 0 ->
          {:error, :has_miss}

        Room.Toolbelt.proof_has_count(has_root) != 0 or Room.Toolbelt.need_count(has_root) != 0 ->
          {:error, :proof_wrote}

        not Room.Toolbelt.ready?(has_root) ->
          {:error, :has_locked}

        Room.Toolbelt.ready?(empty) or Room.SelfReportMatch.vault_has_count(empty) != 0 or
            Room.SelfReportMatch.vault_need_count(empty) != 0 ->
          {:error, :empty_ready}

        Room.SelfReportMatch.vault_need_count(need_root) != 1 or
            Room.SelfReportMatch.vault_has_count(need_root) != 0 ->
          {:error, :need_miss}

        Room.Toolbelt.proof_has_count(need_root) != 0 ->
          {:error, :proof_wrote}

        not Room.Toolbelt.ready?(need_root) ->
          {:error, :need_locked}

        claim.curious != true or claim.tags != [] ->
          {:error, :claim_wrote}

        true ->
          pack = %{has: has, need: need, empty: empty}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end
end
