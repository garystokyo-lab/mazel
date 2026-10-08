defmodule Room.InstallAddMazelSkillMissingPath do
  @moduledoc """
  Missing local skill path fails clearly.

  Nonexistent from=path file → reason=missing. Path sibling
  stays green. Distinct from install_add_mazel_skill_bad_url
  (https 404 / file:// scheme) and
  install_add_mazel_skill_from_url (existing docs path).
  Off Group / Trust / invented live host / mix user lane.
  """

  @gone_rel "docs/NO_SUCH_ADD_MAZEL_SKILL.md"
  @from :path

  def gone_rel, do: @gone_rel
  def from, do: @from

  def look_missing, do: "error  skill=add_mazel  from=path  reason=missing"
  def look_clear, do: Room.InstallAddMazelSkillBadUrl.look_clear()
  def look_sibling, do: Room.InstallAddMazelSkillBadUrl.look_sibling()

  def look(_ \\ %{}) do
    [look_missing(), look_clear(), look_sibling()]
  end

  @doc """
  Read a local skill path. Missing file is :missing.
  """
  def read(path) when is_binary(path) do
    if File.exists?(path) and File.regular?(path) do
      File.read(path)
    else
      {:error, :missing}
    end
  end

  def read(_), do: {:error, :missing}

  @doc """
  Nonexistent local path. Clear error. Path sibling green.
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
              "mazel-install-add-mazel-skill-missing-path-#{System.unique_integer([:positive])}"
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
    gone = Path.join(root, @gone_rel)

    with {:error, :missing} <- read(gone),
         {:error, :missing} <- read(""),
         {:ok, sibling} <- Room.InstallAddMazelSkillFromUrl.demo(root: root) do
      cond do
        File.exists?(gone) ->
          {:error, :gone_exists}

        sibling.lines != path_sibling_look(sibling) ->
          {:error, :sibling_drift}

        sibling.from != :path ->
          {:error, :sibling_miss}

        sibling.mix_user_lane != :no ->
          {:error, :mix_lane}

        from() != :path ->
          {:error, :from_miss}

        look_missing() != "error  skill=add_mazel  from=path  reason=missing" ->
          {:error, :look_miss}

        look_clear() != "ok  clear_error=yes  mix_user_lane=no" ->
          {:error, :look_miss}

        Room.InstallAddMazelSkillFromHttps.live_url() != nil ->
          {:error, :live_claimed}

        true ->
          pack = %{
            from: from(),
            path: gone,
            missing: :missing,
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
