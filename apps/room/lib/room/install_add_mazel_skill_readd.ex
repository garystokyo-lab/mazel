defmodule Room.InstallAddMazelSkillReadd do
  @moduledoc """
  Add Mazel skill path twice is idempotent.

  Second install does not break find→Direct. Skill file
  stays mix-free. Direct is a Session pointer.
  Distinct from install_add_mazel_skill (single pass),
  install_add_twice (no skill / find / Direct),
  install_add_mazel_pack (kind=readme), and
  install_add_paste_find (no skill= / re-add).
  Off Group / Trust / proof-Has / new APIs.
  """

  def skill_rel, do: Room.InstallAddMazelSkill.skill_rel()
  def pack_rel, do: Room.InstallAddMazelSkill.pack_rel()
  def skill_path, do: Room.InstallAddMazelSkill.skill_path()
  def pack_path, do: Room.InstallAddMazelSkill.pack_path()

  def look_first, do: "ok  skill=add_mazel  first=ok"
  def look_second, do: "ok  skill=add_mazel  second=idempotent"
  def look_unlocked, do: Room.SelfReportToolbelt.look_unlocked()
  def look_find(rec \\ %{}), do: Room.InstallAddMazelSkill.look_find(rec)
  def look_direct, do: Room.InstallAddMazelSkill.look_direct()
  def look_lane, do: "ok  mix_user_lane=no"

  def look(pack) when is_map(pack) do
    [look_first(), look_second(), look_unlocked(), look_find(pack.hit), look_direct(), look_lane()]
  end

  def look(_), do: look(%{hit: %{}})

  @doc """
  Skill on disk, Add→paste→find, Add again. Still unlocked.
  Isolated. Sibling skill / pack / twice / find stay.
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
              "mazel-install-add-mazel-skill-readd-#{System.unique_integer([:positive])}"
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
    text = File.read!(skill_path())

    with {:ok, found} <- Room.InstallAddPasteFind.demo(root: root),
         {:ok, second} <- Room.Install.add(root),
         {:ok, find} <-
           Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root}) do
      count = Room.Install.unlock_count(root)

      cond do
        not File.exists?(skill_path()) ->
          {:error, :skill_miss}

        String.contains?(text, "mix ") ->
          {:error, :mix_internals}

        not String.contains?(text, pack_rel()) ->
          {:error, :wrap_miss}

        found.added.button != :ok or found.added[:idempotent] != false ->
          {:error, :first_miss}

        second[:idempotent] != true or second.button != :ok ->
          {:error, :not_idempotent}

        not Room.Install.added?(root) ->
          {:error, :add_miss}

        Room.Install.unlock(root) != :ok ->
          {:error, :locked}

        count != 1 ->
          {:error, :double_unlock}

        not match?(%{ok: true, hits: [%{handle: "kai@mazel"}]}, find) ->
          {:error, :find_miss}

        found.hit.handle != "kai@mazel" ->
          {:error, :find_miss}

        Room.Toolbelt.proof_has_count(root) != 0 ->
          {:error, :proof_wrote}

        true ->
          pack =
            Map.merge(found, %{
              skill: skill_rel(),
              wrap: pack_rel(),
              mix_user_lane: :no,
              first: found.added,
              second: second,
              unlock_count: count,
              text: text
            })

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end
end
