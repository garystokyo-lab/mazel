defmodule Room.InstallAddMazelTool do
  @moduledoc """
  Adapter paste wraps the human Add Mazel pack.

  Tool is docs/ADD_MAZEL_TOOL.md (no mix). Wraps
  docs/ADD_MAZEL.md. Steps add→paste→find→direct.
  Find reuses install_add_paste_find. Direct is a
  Session pointer — not re-owned here.
  Distinct from install_add_mazel_skill (Cursor skill),
  install_add_mazel_pack (kind=readme),
  install_add_paste_find (no tool=),
  install_add_paste_find_mcp (mcp=), and
  session_direct_* (Session owns Direct).
  Off Group / Trust / proof-Has / new APIs.
  """

  @tool_rel "docs/ADD_MAZEL_TOOL.md"
  @pack_rel "docs/ADD_MAZEL.md"

  def tool_rel, do: @tool_rel
  def pack_rel, do: @pack_rel
  def tool_kind, do: :adapter

  def look_tool, do: "ok  tool=add_mazel  mix_user_lane=no"
  def look_steps, do: Room.InstallAddMazelPack.look_steps()
  def look_add_paste, do: Room.InstallAddMazelPack.look_add_paste()
  def look_find(rec \\ %{}), do: Room.InstallAddMazelPack.look_find(rec)
  def look_direct, do: Room.InstallAddMazelPack.look_direct()

  def look(pack) when is_map(pack) do
    [look_tool(), look_steps(), look_add_paste(), look_find(pack.hit), look_direct()]
  end

  def look(_), do: look(%{hit: %{}})

  def tool_path, do: Path.join(Room.Index.repo_root(), @tool_rel)
  def pack_path, do: Path.join(Room.Index.repo_root(), @pack_rel)

  @doc """
  Adapter paste on disk wrapping the pack, then Add→paste→find.
  Direct is a pointer. Isolated. Sibling skill / pack / find stay.
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
              "mazel-install-add-mazel-tool-#{System.unique_integer([:positive])}"
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
    text = File.read!(tool_path())
    pack_text = File.read!(pack_path())

    with {:ok, found} <- Room.InstallAddPasteFind.demo(root: root) do
      cond do
        not File.exists?(tool_path()) ->
          {:error, :tool_miss}

        not File.exists?(pack_path()) ->
          {:error, :pack_miss}

        tool_kind() != :adapter ->
          {:error, :kind_miss}

        not String.starts_with?(text, "# Add Mazel tool") ->
          {:error, :tool_miss}

        not String.contains?(text, "Paste this into your agent as a tool") ->
          {:error, :paste_miss}

        not String.contains?(text, @pack_rel) ->
          {:error, :wrap_miss}

        not String.contains?(text, "Paste a Switzerland brain") ->
          {:error, :paste_miss}

        not String.contains?(text, "Find skill") ->
          {:error, :find_miss}

        not String.contains?(text, "mazel @kai hello") ->
          {:error, :direct_miss}

        not String.contains?(text, "Session owns Direct") ->
          {:error, :pointer_miss}

        String.contains?(text, "mix ") ->
          {:error, :mix_internals}

        not String.starts_with?(pack_text, "# Add Mazel") ->
          {:error, :pack_miss}

        found.hit.handle != "kai@mazel" ->
          {:error, :find_miss}

        true ->
          tool =
            Map.merge(found, %{
              tool: @tool_rel,
              wrap: @pack_rel,
              kind: tool_kind(),
              mix_user_lane: :no,
              text: text
            })

          {:ok, Map.put(tool, :lines, look(tool))}
      end
    end
  end
end