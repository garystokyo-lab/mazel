defmodule Room.InstallAddMazelFriendPathLiveReady do
  @moduledoc """
  Live-friend readiness on dual PATH handoff.

  Sendable one-block (portable skill+MCP, no
  absolute cwd) plus PATH verify / honest
  mix-missing. Then Add→paste→find→Direct.
  Reuses path_handoff_dual. Distinct from
  path_handoff / path_handoff_skill /
  path_handoff_dual (success LOOKs; no
  live_ready / sendable / mix-missing), mix_path
  (PATH gate; no handoff= / harness=), and
  friend_paste (absolute cwd dump). Session owns
  Direct. Consent owns join. Off Group / Trust /
  invented live host / mix user lane / dual
  unpaste/repaste edges.
  """

  @missing_bin "mazel-mix-not-on-path"
  @present_bin "mix"
  @block_rel ".cursor/add-mazel-handoff.md"

  def missing_bin, do: @missing_bin
  def present_bin, do: @present_bin
  def public_host, do: :none
  def block_rel, do: @block_rel
  def probe(bin), do: Room.InstallAddMazelFriendPathHandoffDual.probe(bin)

  def look_ready, do: "ok  handoff=friend  live_ready=yes"
  def look_block, do: "ok  block=sendable  one_block=yes"
  def look_missing, do: Room.InstallAddMazelFriendTryDualPortableMixPath.look_missing()
  def look_on_path, do: Room.InstallAddMazelFriendTryDualPortableMixPath.look_on_path()
  def look_gate, do: Room.InstallAddMazelFriendPathHandoffDual.look_gate()
  def look_onramp, do: Room.InstallAddMazelFriendPathHandoffDual.look_onramp()
  def look_steps, do: Room.InstallAddMazelFriendPathHandoffDual.look_steps()
  def look_add_paste, do: Room.InstallAddMazelFriendPathHandoffDual.look_add_paste()
  def look_find(rec \\ %{}), do: Room.InstallAddMazelFriendPathHandoffDual.look_find(rec)
  def look_direct, do: Room.InstallAddMazelFriendPathHandoffDual.look_direct()
  def look_lane, do: Room.InstallAddMazelFriendPathHandoffDual.look_lane()
  def look_host, do: Room.InstallAddMazelFriendPathHandoffDual.look_host()

  def look(pack) when is_map(pack) do
    [
      look_ready(),
      look_block(),
      look_missing(),
      look_on_path(),
      look_gate(),
      look_onramp(),
      look_steps(),
      look_add_paste(),
      look_find(pack[:hit] || %{}),
      look_direct(),
      look_lane(),
      look_host()
    ]
  end

  def look(_), do: look(%{hit: %{}})

  @doc """
  Portable one-block a friend can be texted.
  Skill + MCP. No absolute cwd.
  """
  def one_block(pack) when is_map(pack) do
    skill = pack[:text] || ""
    mcp = pack[:paste] || ""

    Enum.join(
      [
        "Add Mazel. Portable skill+MCP. mix on PATH. No checkout.",
        "",
        Room.InstallAddMazelFriendTryDualPortable.skill_rel(),
        skill,
        "",
        Room.InstallAddMazelFriendTryDualPortable.mcp_rel(),
        mcp
      ],
      "\n"
    )
  end

  def one_block(_), do: one_block(%{})

  @doc """
  Sendable one-block + PATH missing/on_path, then
  dual PATH handoff find→Direct. Isolated. Sibling
  path_handoff_dual / mix_path / friend_paste LOOK
  stays.
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
              "mazel-install-add-mazel-friend-path-live-ready-#{System.unique_integer([:positive])}"
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
    gone = Keyword.get(opts, :missing, @missing_bin)
    present = Keyword.get(opts, :present, @present_bin)
    harness = Room.InstallAddMazelFriendPaste.cursor_paste()

    with {:error, :mix_missing} <- probe(gone),
         {:ok, prior} <-
           Room.InstallAddMazelFriendPathHandoffDual.demo(root: root, present: present) do
      block = one_block(prior)
      dest = Path.join(root, @block_rel)
      File.mkdir_p!(Path.dirname(dest))
      File.write!(dest, block)

      cond do
        gone == present ->
          {:error, :probe_miss}

        prior.handoff != :friend ->
          {:error, :handoff_miss}

        prior.onramp != :dual or prior.kind != :dual ->
          {:error, :try_miss}

        prior.checkout != :none or prior.harness != :none or prior.public_host != :none ->
          {:error, :host_claimed}

        prior.hit.handle != "kai@mazel" ->
          {:error, :find_miss}

        Path.type(@block_rel) != :relative or String.starts_with?(@block_rel, "/") ->
          {:error, :path_claimed}

        not File.exists?(dest) or File.read!(dest) != block ->
          {:error, :block_miss}

        block == "" or block == harness ->
          {:error, :block_miss}

        not String.contains?(block, prior.text) or not String.contains?(block, prior.paste) ->
          {:error, :block_miss}

        not String.contains?(block, Room.InstallAddMazelFriendTryDualPortable.skill_rel()) ->
          {:error, :block_miss}

        not String.contains?(block, Room.InstallAddMazelFriendTryDualPortable.mcp_rel()) ->
          {:error, :block_miss}

        maze_path?(block) or String.contains?(block, "cwd") ->
          {:error, :path_claimed}

        checkout?(block) ->
          {:error, :checkout_claimed}

        look_ready() != "ok  handoff=friend  live_ready=yes" ->
          {:error, :ready_look}

        look_ready() == Room.InstallAddMazelFriendPathHandoffDual.look_handoff() ->
          {:error, :dual_look}

        look_block() != "ok  block=sendable  one_block=yes" ->
          {:error, :block_look}

        look_missing() != "error  mix=missing  clear_error=yes" ->
          {:error, :missing_look}

        look_on_path() != "ok  mix=on_path" ->
          {:error, :path_look}

        look_onramp() != "ok  onramp=dual  skill=portable  mcp=portable" ->
          {:error, :onramp_look}

        look(prior) == Room.InstallAddMazelFriendPathHandoffDual.look(prior) ->
          {:error, :dual_look}

        look(prior) == Room.InstallAddMazelFriendPathHandoff.look(prior) ->
          {:error, :mcp_look}

        look(prior) == Room.InstallAddMazelFriendPathHandoffSkill.look(prior) ->
          {:error, :skill_look}

        look(prior) == Room.InstallAddMazelFriendTryDualPortableMixPath.look(prior) ->
          {:error, :path_look}

        look(prior) == Room.InstallAddMazelFriendTryDualPortable.look(prior) ->
          {:error, :try_look}

        look(prior) == Room.InstallAddMazelFriendPaste.look(prior) ->
          {:error, :paste_look}

        Room.InstallAddMazelSkillFromHttps.live_url() != nil ->
          {:error, :live_claimed}

        true ->
          pack =
            Map.merge(prior, %{
              live_ready: :yes,
              one_block: :yes,
              block: @block_rel,
              block_text: block,
              mix_missing: :missing,
              clear_error: :yes
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
