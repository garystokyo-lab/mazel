defmodule Room.InstallRemoveWithoutAdd do
  @moduledoc """
  Remove Mazel with no prior Add is a noop.

  Stays locked. No crash. Distinct from
  install_remove_mazel / unlock_remove / second_brain
  (Add first) and install_gate (Need/Have before Add;
  no remove). Off PDF / badge / GH / score / wiki /
  morph / Consent / Session / Match.
  """

  def look_none, do: Room.InstallAddMazel.look_none()
  def look_remove, do: "ok  remove=mazel  noop=true"
  def look_locked, do: Room.InstallUnlockRemove.look_locked()
  def look_crash, do: "ok  crash=none"

  def look(_pack \\ %{}) do
    [look_none(), look_remove(), look_locked(), look_crash()]
  end

  @doc """
  No Add, remove is noop, still locked, no crash.
  Isolated. Sibling remove / gate LOOK stays.
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
              "mazel-install-remove-without-add-#{System.unique_integer([:positive])}"
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

    with {:error, :not_ready} <-
           Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root}),
         {:ok, removed} <- safe_remove(root),
         {:error, :not_ready} <-
           Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root}) do
      cond do
        Room.Install.added?(root) ->
          {:error, :still_added}

        Room.Install.required?(root) ->
          {:error, :gate_wrote}

        removed[:noop] != true ->
          {:error, :not_noop}

        Room.Install.unlock(root) == :ok ->
          {:error, :still_open}

        Room.Toolbelt.proof_has_count(root) != 0 ->
          {:error, :proof_wrote}

        true ->
          pack = %{root: root, removed: removed, crash: :none}
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
