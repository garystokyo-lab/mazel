defmodule Room.InstallAddPasteFind do
  @moduledoc """
  Add Mazel, paste, unlock, then find.

  Same path as install_add_then_paste plus the find beat
  mazel_find already ran. Distinct from
  install_add_then_paste (stops at unlock; no find=),
  install_add_mazel / install_gate (no paste-then-find),
  and mcp (mcp=mazel_find / wing; no add/paste).
  Off Group / Trust / HTTP / Match rewrite.
  """

  def look_add, do: Room.InstallAddThenPaste.look_add()
  def look_paste, do: Room.InstallAddThenPaste.look_paste()
  def look_need(rec \\ %{}), do: Room.InstallAddThenPaste.look_need(rec)
  def look_unlocked, do: Room.InstallAddThenPaste.look_unlocked()
  def look_find(rec \\ %{}), do: Room.SelfReportMatch.look_find(rec)

  def look(pack) when is_map(pack) do
    Room.InstallAddThenPaste.look(pack) ++ [look_find(pack.hit)]
  end

  def look(_), do: look(%{need: %{}, hit: %{}})

  @doc """
  Add, paste grok, Need unlocks mazel_find, then find kai.
  Isolated. Sibling add_then_paste / add_mazel / mcp stay.
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
              "mazel-install-add-paste-find-#{System.unique_integer([:positive])}"
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
    with {:ok, pasted} <- Room.InstallAddThenPaste.demo(root: root),
         {:ok, find} <- Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root}) do
      cond do
        not match?(%{ok: true, hits: [%{handle: "kai@mazel"}]}, find) ->
          {:error, :find_miss}

        true ->
          hit = %{handle: "kai@mazel", query: "series-a", tags: pasted.need.tags}
          pack = Map.merge(pasted, %{find: find, hit: hit})
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end
end
