defmodule Room.InstallAddMazelFriendShareObject do
  @moduledoc """
  Share-object handoff after live-ready.

  A copy/paste block a friend pastes into their
  AI. Portable skill+MCP. No absolute cwd.
  Reuses path_live_ready. Distinct from
  path_live_ready (live_ready / one_block /
  mix-missing), path_handoff_dual / mcp / skill
  (no share= / paste_into_ai), and friend_paste
  (absolute cwd dump). Session owns Direct.
  Consent owns join. Off Group / Trust /
  invented live host / mix user lane / dual
  unpaste/repaste edges / Session / Consent /
  A2A / Match-core.
  """

  @share_rel ".cursor/add-mazel-share.md"

  def public_host, do: :none
  def share_rel, do: @share_rel

  def look_share, do: "ok  handoff=friend  share=object"
  def look_block, do: "ok  block=sendable  paste_into_ai=yes"
  def look_missing, do: "error  block=missing  clear_error=yes"
  def look_gate, do: Room.InstallAddMazelFriendPathLiveReady.look_gate()
  def look_steps, do: Room.InstallAddMazelFriendPathLiveReady.look_steps()
  def look_find(rec \\ %{}), do: Room.InstallAddMazelFriendPathLiveReady.look_find(rec)
  def look_direct, do: Room.InstallAddMazelFriendPathLiveReady.look_direct()
  def look_lane, do: Room.InstallAddMazelFriendPathLiveReady.look_lane()
  def look_host, do: Room.InstallAddMazelFriendPathLiveReady.look_host()

  def look(pack) when is_map(pack) do
    [
      look_share(),
      look_block(),
      look_gate(),
      look_steps(),
      look_find(pack[:hit] || %{}),
      look_direct(),
      look_lane(),
      look_host()
    ]
  end

  def look(_), do: look(%{hit: %{}})

  @doc """
  Share-object a friend pastes into their AI.
  Skill + MCP. No absolute cwd. Blank → missing.
  """
  def share(pack) when is_map(pack) do
    skill = pack[:text] || ""
    mcp = pack[:paste] || ""

    cond do
      String.trim(skill) == "" or String.trim(mcp) == "" ->
        {:error, %{error: :block_missing, clear_error: :yes}}

      maze_path?(skill) or maze_path?(mcp) or String.contains?(mcp, "cwd") ->
        {:error, :path_claimed}

      true ->
        {:ok,
         Enum.join(
           [
             "Paste this into your AI.",
             "",
             "Add Mazel. Portable skill+MCP. No checkout. No absolute path.",
             "",
             Room.InstallAddMazelFriendTryDualPortable.skill_rel(),
             skill,
             "",
             Room.InstallAddMazelFriendTryDualPortable.mcp_rel(),
             mcp
           ],
           "\n"
         )}
    end
  end

  def share(_), do: {:error, %{error: :block_missing, clear_error: :yes}}

  @doc """
  After live-ready, write the paste-into-AI share
  object. Isolated. Sibling live_ready / dual /
  friend_paste LOOK stays.
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
              "mazel-install-add-mazel-friend-share-object-#{System.unique_integer([:positive])}"
            )

          File.mkdir_p!(path)
          {path, true}
      end

    try do
      demo_on(root, opts)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp demo_on(root, opts) do
    harness = Room.InstallAddMazelFriendPaste.cursor_paste()

    with {:ok, prior} <- Room.InstallAddMazelFriendPathLiveReady.demo(Keyword.put(opts, :root, root)),
         {:ok, body} <- share(prior) do
      dest = Path.join(root, @share_rel)
      File.mkdir_p!(Path.dirname(dest))
      File.write!(dest, body)
      handoff = Path.join(root, Room.InstallAddMazelFriendPathLiveReady.block_rel())

      cond do
        prior.handoff != :friend or prior.live_ready != :yes ->
          {:error, :handoff_miss}

        prior.onramp != :dual or prior.checkout != :none or prior.public_host != :none ->
          {:error, :try_miss}

        prior.hit.handle != "kai@mazel" ->
          {:error, :find_miss}

        Path.type(@share_rel) != :relative or String.starts_with?(@share_rel, "/") ->
          {:error, :path_claimed}

        @share_rel == Room.InstallAddMazelFriendPathLiveReady.block_rel() ->
          {:error, :ready_look}

        not File.exists?(dest) or File.read!(dest) != body ->
          {:error, :block_miss}

        not File.exists?(handoff) or File.read!(handoff) != prior.block_text ->
          {:error, :ready_miss}

        body == "" or body == harness or body == prior.block_text ->
          {:error, :block_miss}

        not String.contains?(body, "Paste this into your AI.") ->
          {:error, :block_miss}

        not String.contains?(body, prior.text) or not String.contains?(body, prior.paste) ->
          {:error, :block_miss}

        not String.contains?(body, Room.InstallAddMazelFriendTryDualPortable.skill_rel()) ->
          {:error, :block_miss}

        not String.contains?(body, Room.InstallAddMazelFriendTryDualPortable.mcp_rel()) ->
          {:error, :block_miss}

        maze_path?(body) or String.contains?(body, "cwd") ->
          {:error, :path_claimed}

        checkout?(body) ->
          {:error, :checkout_claimed}

        share(%{}) != {:error, %{error: :block_missing, clear_error: :yes}} ->
          {:error, :missing_look}

        look_share() != "ok  handoff=friend  share=object" ->
          {:error, :share_look}

        look_share() == Room.InstallAddMazelFriendPathLiveReady.look_ready() ->
          {:error, :ready_look}

        look_block() != "ok  block=sendable  paste_into_ai=yes" ->
          {:error, :block_look}

        look_block() == Room.InstallAddMazelFriendPathLiveReady.look_block() ->
          {:error, :ready_look}

        look_missing() != "error  block=missing  clear_error=yes" ->
          {:error, :missing_look}

        look_gate() != "ok  checkout=none  harness=none" ->
          {:error, :gate_look}

        look(prior) == Room.InstallAddMazelFriendPathLiveReady.look(prior) ->
          {:error, :ready_look}

        look(prior) == Room.InstallAddMazelFriendPathHandoffDual.look(prior) ->
          {:error, :dual_look}

        look(prior) == Room.InstallAddMazelFriendPaste.look(prior) ->
          {:error, :paste_look}

        Room.InstallAddMazelSkillFromHttps.live_url() != nil ->
          {:error, :live_claimed}

        true ->
          pack =
            Map.merge(prior, %{
              share: :object,
              paste_into_ai: :yes,
              share_rel: @share_rel,
              share_text: body,
              public_host: :none
            })

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp maze_path?(text) do
    String.contains?(text, "/workspace") or
      String.contains?(text, "/absolute/path") or
      String.contains?(text, "apps/room")
  end

  defp checkout?(text) do
    String.contains?(text, "git clone") or String.contains?(text, "git checkout")
  end
end
