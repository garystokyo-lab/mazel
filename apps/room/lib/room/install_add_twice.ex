defmodule Room.InstallAddTwice do
  @moduledoc """
  Add Mazel twice is idempotent. Tools stay unlocked once.

  Distinct from install_add_mazel / install_gate (single
  Add) and install_remove_* (remove paths). Off PDF /
  badge / GH / score / wiki / morph / Consent / Session /
  Match features.
  """

  def look_add, do: Room.InstallRemoveMazel.look_add()
  def look_need(rec \\ %{}), do: Room.SelfReportToolbelt.look_need(rec)
  def look_unlocked, do: Room.SelfReportToolbelt.look_unlocked()
  def look_again, do: "ok  add=mazel  idempotent=true"
  def look_count(n \\ 1), do: "ok  unlock_count=#{n}"

  def look(pack \\ %{}) do
    [
      look_add(),
      look_need(pack[:need] || %{}),
      look_unlocked(),
      look_again(),
      look_unlocked(),
      look_count(pack[:unlock_count] || 1)
    ]
  end

  @doc """
  Add, Need unlocks, Add again. Still unlocked once.
  Isolated. Sibling add / gate / remove LOOK stays.
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
              "mazel-install-add-twice-#{System.unique_integer([:positive])}"
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

    with {:ok, first} <- Room.Install.add(root),
         {:ok, _} <- Room.SelfReportMatch.put(root, need),
         {:ok, _} <- Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root}),
         {:ok, second} <- Room.Install.add(root),
         {:ok, _} <- Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root}) do
      count = Room.Install.unlock_count(root)

      cond do
        need.source != "self_report" or need.tags != ["series-a"] ->
          {:error, :not_self_report}

        first[:idempotent] != false or first.button != :ok ->
          {:error, :first_miss}

        second[:idempotent] != true or second.button != :ok ->
          {:error, :not_idempotent}

        not Room.Install.added?(root) ->
          {:error, :add_miss}

        Room.Install.unlock(root) != :ok ->
          {:error, :locked}

        Room.Toolbelt.proof_has_count(root) != 0 ->
          {:error, :proof_wrote}

        count != 1 ->
          {:error, :double_unlock}

        true ->
          pack = %{
            root: root,
            need: need,
            first: first,
            second: second,
            unlock_count: count
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end
end
