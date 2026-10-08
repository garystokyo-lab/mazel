defmodule Room.Toolbelt do
  @moduledoc """
  Add-Mazel as soon as one proof Has, one Need, or one
  self-report Has/Need exists.

  Capability in chat first. No network, badge, or morph gate.
  Curious never counts as Has. Vibe never counts as Need.
  Expired Need (hard TTL dead) never unlocks.
  """

  def ready_line, do: "Mazel is ready."

  def proof_has_count(root) do
    root
    |> Room.Index.load("has")
    |> Enum.count(&proof_has?/1)
  end

  def need_count(root, now \\ DateTime.utc_now()) do
    root
    |> Room.Index.load("need")
    |> Enum.count(&need?(&1, now))
  end

  def ready?(root) do
    proof_has_count(root) >= 1 or need_count(root) >= 1 or
      Room.SelfReportMatch.vault_has_count(root) >= 1 or
      Room.SelfReportMatch.vault_need_count(root) >= 1
  end

  def look(root) when is_binary(root) do
    look(%{has: proof_has_count(root), need: need_count(root)})
  end

  def look(%{has: has, need: need}) do
    []
    |> then(&if has >= 1, do: &1 ++ ["ok  has=1 → mazel ready"], else: &1)
    |> then(&if need >= 1, do: &1 ++ ["ok  need=1 → mazel ready"], else: &1)
    |> then(&if has >= 1 or need >= 1, do: &1 ++ [ready_line()], else: &1)
  end

  def look(_), do: []

  @doc """
  One proof Has + one Need unlocks Add-Mazel. Isolated tmp.
  No badge, morph, or network.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-toolbelt-#{System.unique_integer([:positive])}")
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

    with {:ok, need} <- Room.Need.seed("founders-investors", root: root) do
      has = proof_has_count(root)
      needs = need_count(root)
      lines = look(root)

      cond do
        has < 1 or needs < 1 ->
          {:error, :not_ready}

        need.kind != "need" ->
          {:error, :need_miss}

        lines != [
          "ok  has=1 → mazel ready",
          "ok  need=1 → mazel ready",
          "Mazel is ready."
        ] ->
          {:error, :look_miss}

        true ->
          {:ok, %{has: has, need: needs, lines: lines}}
      end
    end
  end

  defp proof_has?(row) do
    kind = row[:kind] || row["kind"]
    status = row[:status] || row["status"]

    to_string(kind) == "has" and to_string(status) == "has"
  end

  defp need?(row, now) do
    kind = row[:kind] || row["kind"]
    to_string(kind) == "need" and not Room.Index.expired?(row, now)
  end
end
