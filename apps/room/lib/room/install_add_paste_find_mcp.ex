defmodule Room.InstallAddPasteFindMcp do
  @moduledoc """
  Add Mazel, paste, unlock, then find on the MCP LOOK path.

  Same path as install_add_paste_find; find beat is
  `Room.Mcp.find_look` only. No live mazel_wing.
  Distinct from install_add_paste_find (mix find=),
  install_add_then_paste (no find beat), and mcp
  (mcp=mazel_find / wing; no add/paste).
  Off Group / Trust / HTTP / Match rewrite.
  """

  def look_add, do: Room.InstallAddPasteFind.look_add()
  def look_paste, do: Room.InstallAddPasteFind.look_paste()
  def look_need(rec \\ %{}), do: Room.InstallAddPasteFind.look_need(rec)
  def look_unlocked, do: Room.InstallAddPasteFind.look_unlocked()

  def look_find(found \\ %{handle: "kai@mazel"}) do
    Room.Mcp.find_look("series-a", found)
  end

  def look(pack) when is_map(pack) do
    Room.InstallAddThenPaste.look(pack) ++ [look_find(pack.find)]
  end

  def look(_), do: look(%{need: %{}, find: %{handle: "kai@mazel"}})

  @doc """
  Add, paste grok, Need unlocks mazel_find, then MCP find LOOK.
  Isolated. Sibling add_paste_find / add_then_paste / mcp stay.
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
              "mazel-install-add-paste-find-mcp-#{System.unique_integer([:positive])}"
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
    with {:ok, found} <- Room.InstallAddPasteFind.demo(root: root) do
      cond do
        not match?(%{ok: true, hits: [%{handle: "kai@mazel"}]}, found.find) ->
          {:error, :find_miss}

        true ->
          {:ok, Map.put(found, :lines, look(found))}
      end
    end
  end
end
