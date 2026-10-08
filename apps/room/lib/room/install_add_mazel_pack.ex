defmodule Room.InstallAddMazelPack do
  @moduledoc """
  Human Add Mazel pack wraps the already-green path.

  Pack is docs/ADD_MAZEL.md (no mix internals). Steps
  add→paste→find→direct. Find reuses install_add_paste_find.
  Direct is a Session pointer — not re-owned here.
  Distinct from install_add_paste_find (no pack=),
  install_add_paste_find_mcp (mcp=), and
  session_direct_after_find (id + talk + badge).
  Off Group / Trust / new APIs.
  """

  @pack_rel "docs/ADD_MAZEL.md"

  def pack_rel, do: @pack_rel
  def pack_kind, do: :readme

  def look_pack, do: "ok  pack=add_mazel  kind=readme"
  def look_steps, do: "ok  steps=add→paste→find→direct"
  def look_add_paste, do: Room.SessionDirectAfterFind.look_add_paste()
  def look_find(rec \\ %{}), do: Room.InstallAddPasteFind.look_find(rec)
  def look_direct, do: "ok  direct=@kai  session=ready"

  def look(pack) when is_map(pack) do
    [look_pack(), look_steps(), look_add_paste(), look_find(pack.hit), look_direct()]
  end

  def look(_), do: look(%{hit: %{}})

  def pack_path, do: Path.join(Room.Index.repo_root(), @pack_rel)

  @doc """
  Pack on disk, then Add→paste→find. Direct is a pointer.
  Isolated. Sibling find / mcp / after_find LOOK stays.
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
              "mazel-install-add-mazel-pack-#{System.unique_integer([:positive])}"
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
    text = File.read!(pack_path())

    with {:ok, found} <- Room.InstallAddPasteFind.demo(root: root) do
      cond do
        not File.exists?(pack_path()) ->
          {:error, :pack_miss}

        pack_kind() != :readme ->
          {:error, :kind_miss}

        not String.starts_with?(text, "# Add Mazel") ->
          {:error, :pack_miss}

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

        found.hit.handle != "kai@mazel" ->
          {:error, :find_miss}

        true ->
          pack =
            Map.merge(found, %{
              pack: @pack_rel,
              kind: pack_kind(),
              text: text
            })

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end
end
