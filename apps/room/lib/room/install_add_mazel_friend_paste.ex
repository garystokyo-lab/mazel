defmodule Room.InstallAddMazelFriendPaste do
  @moduledoc """
  Friend-handable Cursor MCP paste, then find→Direct.

  LOOK prints the exact first json fence from
  docs/INSTALL.md — the paste a friend copies into
  Cursor Settings → MCP. No public skill host.
  Distinct from install_add_mazel_skill_from_url
  (path flags only; no paste body),
  install_add_mazel_skill (in-repo skill),
  install_add_mazel_pack (kind=readme), and
  install_add_paste_find_mcp (mcp= find; no paste body).
  Off Group / Trust / invented live host / mix user lane.
  """

  @install_rel "docs/INSTALL.md"
  @from :paste
  @kind :mcp

  def install_rel, do: @install_rel
  def from, do: @from
  def kind, do: @kind

  def look_kind, do: "ok  paste=friend  kind=mcp"
  def look_paste_begin, do: "--- paste ---"
  def look_paste_end, do: "--- end ---"
  def look_steps, do: Room.InstallAddMazelPack.look_steps()
  def look_add_paste, do: Room.InstallAddMazelPack.look_add_paste()
  def look_find(rec \\ %{}), do: Room.InstallAddMazelPack.look_find(rec)
  def look_direct, do: Room.InstallAddMazelPack.look_direct()
  def look_lane, do: "ok  mix_user_lane=no"
  def look_harness, do: "ok  harness_only=no"

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
        look_lane(),
        look_harness()
      ]
  end

  def look(_), do: look(%{paste: "", hit: %{}})

  def install_path, do: Path.join(Room.Index.repo_root(), @install_rel)

  @doc "Exact first json fence body from INSTALL.md."
  def cursor_paste do
    case first_json_fence(File.read!(install_path())) do
      {:ok, body} -> body
      {:error, _} -> ""
    end
  end

  def first_json_fence(text) when is_binary(text) do
    case Regex.run(~r/```json\n(.*?)```/s, text, capture: :all_but_first) do
      [body] -> {:ok, String.trim_trailing(body)}
      _ -> {:error, :fence_miss}
    end
  end

  def first_json_fence(_), do: {:error, :fence_miss}

  defp paste_lines(text) when is_binary(text) do
    text
    |> String.split("\n", trim: false)
    |> Enum.reject(&(&1 == ""))
  end

  defp paste_lines(_), do: []

  @doc """
  Exact Cursor MCP paste, then Add→paste→find→Direct.
  Isolated. No invented live host. Path sibling stays.
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
              "mazel-install-add-mazel-friend-paste-#{System.unique_integer([:positive])}"
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
    install = File.read!(install_path())

    with {:ok, paste} <- first_json_fence(install),
         {:ok, found} <- Room.InstallAddPasteFind.demo(root: root),
         {:ok, sibling} <- Room.InstallAddMazelSkillFromUrl.demo(root: Path.join(root, "sib")) do
      cond do
        not File.exists?(install_path()) ->
          {:error, :install_miss}

        from() != :paste ->
          {:error, :from_miss}

        kind() != :mcp ->
          {:error, :kind_miss}

        paste != cursor_paste() ->
          {:error, :paste_drift}

        not String.contains?(paste, "\"mcpServers\"") ->
          {:error, :paste_miss}

        not String.contains?(paste, "\"command\": \"mix\"") ->
          {:error, :stdio_miss}

        not String.contains?(paste, "\"args\": [\"mcp\"]") ->
          {:error, :stdio_miss}

        not String.contains?(paste, "/absolute/path/to/mazel/apps/room") ->
          {:error, :cwd_miss}

        not String.contains?(paste, "MAZEL_HTTP") ->
          {:error, :env_miss}

        not String.contains?(paste, "MAZEL_MCP") ->
          {:error, :env_miss}

        String.contains?(paste, "npx") ->
          {:error, :npx_hero}

        String.contains?(paste, "https://") ->
          {:error, :live_claimed}

        String.contains?(paste, "githubusercontent") ->
          {:error, :live_claimed}

        sibling.lines != path_sibling_look(sibling) ->
          {:error, :sibling_drift}

        sibling.from != :path ->
          {:error, :sibling_miss}

        sibling.mix_user_lane != :no ->
          {:error, :mix_lane}

        found.hit.handle != "kai@mazel" ->
          {:error, :find_miss}

        look_kind() != "ok  paste=friend  kind=mcp" ->
          {:error, :look_miss}

        look_paste_begin() != "--- paste ---" ->
          {:error, :look_miss}

        look_paste_end() != "--- end ---" ->
          {:error, :look_miss}

        look_lane() != "ok  mix_user_lane=no" ->
          {:error, :look_miss}

        look_harness() != "ok  harness_only=no" ->
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
              harness_only: :no,
              sibling: sibling,
              install: @install_rel
            })

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
