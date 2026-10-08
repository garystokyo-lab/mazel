defmodule Room.InstallAddMazelSkillPaste do
  @moduledoc """
  Friend-handable Add Mazel skill paste, then find→Direct.

  LOOK prints the exact `.cursor/skills/add-mazel/SKILL.md`
  a friend copies into normal AI chat / Cursor skills.
  No public skill host. Distinct from
  install_add_mazel_friend_paste (kind=mcp INSTALL.json),
  install_add_mazel_skill (flags only; no paste body),
  and install_add_mazel_skill_from_url (from=path).
  Off Group / Trust / invented live host / mix user lane.
  """

  @skill_rel ".cursor/skills/add-mazel/SKILL.md"
  @from :paste
  @kind :skill

  def skill_rel, do: @skill_rel
  def from, do: @from
  def kind, do: @kind

  def look_kind, do: "ok  paste=friend  kind=skill"
  def look_paste_begin, do: Room.InstallAddMazelFriendPaste.look_paste_begin()
  def look_paste_end, do: Room.InstallAddMazelFriendPaste.look_paste_end()
  def look_steps, do: Room.InstallAddMazelPack.look_steps()
  def look_add_paste, do: Room.InstallAddMazelPack.look_add_paste()
  def look_find(rec \\ %{}), do: Room.InstallAddMazelPack.look_find(rec)
  def look_direct, do: Room.InstallAddMazelPack.look_direct()
  def look_lane, do: Room.InstallAddMazelFriendPaste.look_lane()

  def look(pack) when is_map(pack) do
    [
      look_kind(),
      look_paste_begin()
    ] ++ paste_lines(pack[:paste]) ++
      [
        look_paste_end(),
        look_steps(),
        look_add_paste(),
        look_find(pack[:hit] || %{}),
        look_direct(),
        look_lane()
      ]
  end

  def look(_), do: look(%{paste: "", hit: %{}})

  def skill_path, do: Path.join(Room.Index.repo_root(), @skill_rel)

  @doc "Exact Add Mazel skill body a friend copies."
  def skill_paste do
    skill_path() |> File.read!() |> String.trim_trailing()
  end

  defp paste_lines(text) when is_binary(text) do
    text
    |> String.split("\n", trim: false)
    |> Enum.reject(&(&1 == ""))
  end

  defp paste_lines(_), do: []

  @doc """
  Exact skill paste, then Add→paste→find→Direct.
  Isolated. MCP friend_paste LOOK stays. No live host.
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
              "mazel-install-add-mazel-skill-paste-#{System.unique_integer([:positive])}"
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
    with {:ok, found} <- Room.InstallAddPasteFind.demo(root: root),
         {:ok, mcp} <-
           Room.InstallAddMazelFriendPaste.demo(root: Path.join(root, "mcp")) do
      paste = skill_paste()

      cond do
        not File.exists?(skill_path()) ->
          {:error, :skill_miss}

        from() != :paste ->
          {:error, :from_miss}

        kind() != :skill ->
          {:error, :kind_miss}

        paste == "" ->
          {:error, :paste_miss}

        not String.starts_with?(paste, "# Add Mazel") ->
          {:error, :skill_miss}

        not String.contains?(paste, "Find skill series-a") ->
          {:error, :find_miss}

        not String.contains?(paste, "mazel @kai hello") ->
          {:error, :direct_miss}

        not String.contains?(paste, "Session owns Direct") ->
          {:error, :pointer_miss}

        String.contains?(paste, "mix ") ->
          {:error, :mix_internals}

        String.contains?(paste, "npx") ->
          {:error, :npx_hero}

        String.contains?(paste, "https://") ->
          {:error, :live_claimed}

        String.contains?(paste, "githubusercontent") ->
          {:error, :live_claimed}

        mcp.lines != mcp_sibling_look() ->
          {:error, :sibling_drift}

        mcp.kind != :mcp ->
          {:error, :sibling_miss}

        found.hit.handle != "kai@mazel" ->
          {:error, :find_miss}

        look_kind() != "ok  paste=friend  kind=skill" ->
          {:error, :look_miss}

        look_kind() == Room.InstallAddMazelFriendPaste.look_kind() ->
          {:error, :mcp_look}

        look_lane() != "ok  mix_user_lane=no" ->
          {:error, :look_miss}

        Room.InstallAddMazelSkillFromHttps.live_url() != nil ->
          {:error, :live_claimed}

        true ->
          pack =
            Map.merge(found, %{
              from: from(),
              kind: kind(),
              paste: paste,
              mix_user_lane: :no,
              sibling: mcp,
              skill: @skill_rel
            })

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp mcp_sibling_look do
    [
      "ok  paste=friend  kind=mcp",
      "--- paste ---",
      "{",
      "  \"mcpServers\": {",
      "    \"mazel\": {",
      "      \"command\": \"mix\",",
      "      \"args\": [\"mcp\"],",
      "      \"cwd\": \"/absolute/path/to/mazel/apps/room\",",
      "      \"env\": {",
      "        \"MAZEL_HTTP\": \"0\",",
      "        \"MAZEL_MCP\": \"1\"",
      "      }",
      "    }",
      "  }",
      "}",
      "--- end ---",
      "ok  steps=add→paste→find→direct",
      "ok  add=mazel  paste=ready",
      "ok  find=series-a→kai@mazel  mazel'd @kai",
      "ok  direct=@kai  session=ready",
      "ok  mix_user_lane=no",
      "ok  harness_only=no"
    ]
  end
end
