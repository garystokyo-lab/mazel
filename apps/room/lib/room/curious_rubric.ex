defmodule Room.CuriousRubric do
  @moduledoc """
  One-strip classify: has (proof) vs needs (clear hunt) vs curious.

  Agent emits grades. Curious never paths. Does not rewrite
  need / harp / prompt_check LOOK.
  """

  def look_has(rec) when is_map(rec) do
    proof = rec[:proof] || rec[:skills] || ["series-a"]
    id = proof |> List.wrap() |> List.first() || "series-a"
    handle = rec[:handle] || "kai@mazel"
    "ok  grade=has  peer=#{handle}  proof=#{id}"
  end

  def look_has(_), do: "ok  grade=has  peer=kai@mazel  proof=series-a"

  def look_needs(rec) when is_map(rec) do
    shape = rec[:shape] || rec[:id] || :icp_pain
    "ok  grade=needs  shape=#{shape}  hunt=clear"
  end

  def look_needs(_), do: "ok  grade=needs  shape=icp_pain  hunt=clear"

  def look_curious(rec) when is_map(rec) do
    kind = rec[:curious_kind] || "vibe"
    "ok  grade=curious  kind=#{kind}  match=never"
  end

  def look_curious(_), do: "ok  grade=curious  kind=vibe  match=never"

  def look_unfit, do: "error  curious→unfit"

  def look(pack) when is_map(pack) do
    [look_has(pack.has), look_needs(pack.need), look_curious(pack.curious), look_unfit()]
  end

  def look(_), do: look(%{has: %{}, need: %{}, curious: %{}})

  @doc """
  Real Has proof, clear Need hunt, vibe/claim curious — one strip.
  Curious never matches. Isolated. Sibling LOOK stays.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-curious-rubric-#{System.unique_integer([:positive])}")
          File.mkdir_p!(Path.join(path, "index/has"))
          File.mkdir_p!(Path.join(path, "index/needs"))
          {path, true}
      end

    try do
      demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp demo_on(root) do
    File.cp!(
      Path.join(Room.Index.repo_root(), "index/has/kai.md"),
      Path.join(root, "index/has/kai.md")
    )

    with {:ok, has} <- load_has(root, "kai"),
         {:ok, need} <- Room.Need.Shape.cast(:icp_pain),
         {:ok, vibe} <- Room.Need.Shape.cast("vibe: passionate visionary energy"),
         {:ok, refused} <- Room.Need.match_has(vibe, root: root) do
      claim = "claim: I am a passionate visionary thought leader."

      cond do
        Room.Need.classify(has) != :has ->
          {:error, :has_not_has}

        Room.Need.classify(need) != :need ->
          {:error, :need_not_need}

        Room.Need.classify(vibe) != :curious or Room.Need.classify(claim) != :curious ->
          {:error, :curious_miss}

        Room.Need.classify(has) == Room.Need.classify(need) ->
          {:error, :grades_collide}

        not refused.unfit or refused.error != "curious" or refused.ok ->
          {:error, :curious_matched}

        true ->
          has = Map.put(has, :proof, proof_ids(has))
          curious = Map.merge(vibe, %{curious_kind: "vibe"})
          pack = %{has: has, need: need, curious: curious, refused: refused}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp load_has(root, local) do
    rec =
      root
      |> Room.Index.load("has")
      |> Enum.find(fn row ->
        to_string(row[:id] || "") == local or
          to_string(row[:handle] || "") |> String.starts_with?(local)
      end)

    if is_nil(rec) do
      {:error, :has_miss}
    else
      {:ok, rec}
    end
  end

  defp proof_ids(rec) do
    body = rec[:body] || ""

    case Regex.run(~r/^proof:\s*(.+)$/m, body) do
      [_, csv] ->
        csv
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      _ ->
        ["series-a"]
    end
  end
end