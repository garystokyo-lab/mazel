defmodule Room.InstallRemoveTwice do
  @moduledoc """
  Remove Mazel twice. Second is noop. Still locked.

  Distinct from install_remove_without_add (never-Add),
  install_unlock_remove / install_remove_mazel (single
  remove after Add), and install_add_twice (Add
  idempotent). Off PDF / badge / GH / score / wiki /
  morph / Consent / Session / Match.
  """

  def look_add, do: Room.InstallRemoveMazel.look_add()
  def look_need(rec \\ %{}), do: Room.SelfReportToolbelt.look_need(rec)
  def look_unlocked, do: Room.SelfReportToolbelt.look_unlocked()
  def look_remove, do: Room.InstallRemoveMazel.look_remove()
  def look_locked, do: Room.InstallUnlockRemove.look_locked()
  def look_again, do: Room.InstallRemoveWithoutAdd.look_remove()
  def look_crash, do: Room.InstallRemoveWithoutAdd.look_crash()

  def look(pack) when is_map(pack) do
    [
      look_add(),
      look_need(pack.need),
      look_unlocked(),
      look_remove(),
      look_locked(),
      look_again(),
      look_locked(),
      look_crash()
    ]
  end

  def look(_), do: look(%{need: %{}})

  @doc """
  Add, unlock, remove, remove again. Second is noop.
  Isolated. Sibling without_add / unlock_remove / add_twice
  LOOK stays.
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
              "mazel-install-remove-twice-#{System.unique_integer([:positive])}"
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
         {:ok, first} <- safe_remove(root),
         {:error, :not_ready} <-
           Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root}),
         {:ok, second} <- safe_remove(root),
         {:error, :not_ready} <-
           Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root}) do
      cond do
        need.source != "self_report" or need.tags != ["series-a"] ->
          {:error, :not_self_report}

        first[:noop] != false or first.button != :gone ->
          {:error, :first_miss}

        second[:noop] != true or second.button != :gone ->
          {:error, :not_noop}

        Room.Install.added?(root) ->
          {:error, :still_added}

        not Room.Install.required?(root) ->
          {:error, :gate_gone}

        Room.Install.unlock(root) == :ok ->
          {:error, :still_open}

        Room.Install.unlock_count(root) != 0 ->
          {:error, :unlocked}

        Room.Toolbelt.proof_has_count(root) != 0 ->
          {:error, :proof_wrote}

        true ->
          pack = %{
            need: need,
            root: root,
            first: first,
            second: second,
            crash: :none
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp safe_remove(root) do
    try do
      Room.Install.remove(root)
    rescue
      e -> {:error, {:crash, e}}
    end
  end
end
