defmodule Room.InstallAddMazelSkillFromUrl do
  @moduledoc """
  Add Mazel skill is handable from a friend path.

  Path is docs/ADD_MAZEL_SKILL.md (no mix). Wraps
  docs/ADD_MAZEL.md. Copy into .cursor/skills. Steps
  add→paste→find→direct. Direct is a Session pointer.
  Distinct from install_add_mazel_skill (in-repo skill
  only), install_add_mazel_skill_readd (idempotent
  re-add), and install_add_mazel_pack (kind=readme).
  Off Group / Trust / proof-Has / new APIs / live URL.
  """

  @hand_rel "docs/ADD_MAZEL_SKILL.md"
  @pack_rel "docs/ADD_MAZEL.md"
  @from :path

  def hand_rel, do: @hand_rel
  def pack_rel, do: @pack_rel
  def from, do: @from

  def look_from, do: "ok  skill=add_mazel  from=path"
  def look_install, do: "ok  install=friend_handable  mix_user_lane=no"
  def look_steps, do: Room.InstallAddMazelPack.look_steps()
  def look_add_paste, do: Room.InstallAddMazelPack.look_add_paste()
  def look_find(rec \\ %{}), do: Room.InstallAddMazelPack.look_find(rec)
  def look_direct, do: Room.InstallAddMazelPack.look_direct()

  def look(pack) when is_map(pack) do
    [
      look_from(),
      look_install(),
      look_steps(),
      look_add_paste(),
      look_find(pack.hit),
      look_direct()
    ]
  end

  def look(_), do: look(%{hit: %{}})

  def hand_path, do: Path.join(Room.Index.repo_root(), @hand_rel)
  def pack_path, do: Path.join(Room.Index.repo_root(), @pack_rel)

  @doc """
  Friend-handable skill path, then Add→paste→find.
  Direct is a pointer. Isolated. Sibling skill / readd / pack stay.
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
              "mazel-install-add-mazel-skill-from-url-#{System.unique_integer([:positive])}"
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
    text = File.read!(hand_path())
    pack_text = File.read!(pack_path())

    with {:ok, found} <- Room.InstallAddPasteFind.demo(root: root) do
      cond do
        not File.exists?(hand_path()) ->
          {:error, :hand_miss}

        not File.exists?(pack_path()) ->
          {:error, :pack_miss}

        from() != :path ->
          {:error, :from_miss}

        not String.starts_with?(text, "# Add Mazel skill") ->
          {:error, :hand_miss}

        not String.contains?(text, "Hand a friend this path") ->
          {:error, :hand_miss}

        not String.contains?(text, @hand_rel) ->
          {:error, :hand_miss}

        not String.contains?(text, ".cursor/skills/add-mazel/SKILL.md") ->
          {:error, :install_miss}

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
          skill =
            Map.merge(found, %{
              skill: @hand_rel,
              wrap: @pack_rel,
              from: from(),
              mix_user_lane: :no,
              text: text
            })

          {:ok, Map.put(skill, :lines, look(skill))}
      end
    end
  end
end
