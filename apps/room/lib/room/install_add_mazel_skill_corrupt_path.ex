defmodule Room.InstallAddMazelSkillCorruptPath do
  @moduledoc """
  Empty or corrupt local skill path fails clearly.

  Path exists. Empty body → reason=empty. Garbage body
  → reason=corrupt. Distinct from
  install_add_mazel_skill_missing_path (file absent) and
  install_add_mazel_skill_bad_url (https 404 / file://).
  Path sibling stays green. Off Group / Trust / invented
  live host / mix user lane.
  """

  @empty_rel "docs/EMPTY_ADD_MAZEL_SKILL.md"
  @corrupt_rel "docs/CORRUPT_ADD_MAZEL_SKILL.md"
  @corrupt_body "{not a skill"
  @from :path

  def empty_rel, do: @empty_rel
  def corrupt_rel, do: @corrupt_rel
  def corrupt_body, do: @corrupt_body
  def from, do: @from

  def look_empty, do: "error  skill=add_mazel  from=path  reason=empty"
  def look_corrupt, do: "error  skill=add_mazel  from=path  reason=corrupt"
  def look_clear, do: Room.InstallAddMazelSkillBadUrl.look_clear()
  def look_sibling, do: Room.InstallAddMazelSkillBadUrl.look_sibling()

  def look(_ \\ %{}) do
    [look_empty(), look_corrupt(), look_clear(), look_sibling()]
  end

  @doc """
  Read a local skill path. Empty or garbage is clear error.
  Missing stays :missing.
  """
  def parse(path) when is_binary(path) do
    case Room.InstallAddMazelSkillMissingPath.read(path) do
      {:error, :missing} ->
        {:error, :missing}

      {:ok, text} ->
        cond do
          String.trim(text) == "" ->
            {:error, :empty}

          not String.starts_with?(text, "# Add Mazel skill") ->
            {:error, :corrupt}

          true ->
            {:ok, text}
        end

      error ->
        error
    end
  end

  def parse(_), do: {:error, :missing}

  @doc """
  Empty + corrupt local paths. Clear error. Path sibling green.
  Isolated. No invented live host.
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
              "mazel-install-add-mazel-skill-corrupt-path-#{System.unique_integer([:positive])}"
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
    empty = Path.join(root, @empty_rel)
    corrupt = Path.join(root, @corrupt_rel)
    File.mkdir_p!(Path.dirname(empty))
    File.write!(empty, "")
    File.write!(corrupt, @corrupt_body)

    with {:error, :empty} <- parse(empty),
         {:error, :corrupt} <- parse(corrupt),
         {:error, :missing} <- parse(Path.join(root, "docs/NO_SUCH_ADD_MAZEL_SKILL.md")),
         {:ok, sibling} <- Room.InstallAddMazelSkillFromUrl.demo(root: root) do
      cond do
        not File.exists?(empty) or not File.exists?(corrupt) ->
          {:error, :files_miss}

        sibling.lines != path_sibling_look(sibling) ->
          {:error, :sibling_drift}

        sibling.from != :path ->
          {:error, :sibling_miss}

        sibling.mix_user_lane != :no ->
          {:error, :mix_lane}

        from() != :path ->
          {:error, :from_miss}

        look_empty() != "error  skill=add_mazel  from=path  reason=empty" ->
          {:error, :look_miss}

        look_corrupt() != "error  skill=add_mazel  from=path  reason=corrupt" ->
          {:error, :look_miss}

        look_clear() != "ok  clear_error=yes  mix_user_lane=no" ->
          {:error, :look_miss}

        Room.InstallAddMazelSkillFromHttps.live_url() != nil ->
          {:error, :live_claimed}

        true ->
          pack = %{
            from: from(),
            empty_path: empty,
            corrupt_path: corrupt,
            empty: :empty,
            corrupt: :corrupt,
            mix_user_lane: :no,
            sibling: sibling
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp path_sibling_look(sib) do
    [
      "ok  skill=add_mazel  from=path",
      "ok  install=friend_handable  mix_user_lane=no",
      "ok  steps=add→paste→find→direct",
      "ok  add=mazel  paste=ready",
      "ok  find=series-a→kai@mazel  mazel'd @kai",
      "ok  direct=@kai  session=ready"
    ]
    |> then(fn expected ->
      if sib.hit.handle == "kai@mazel", do: expected, else: :miss
    end)
  end
end
