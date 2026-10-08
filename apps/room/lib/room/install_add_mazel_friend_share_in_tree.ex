defmodule Room.InstallAddMazelFriendShareInTree do
  @moduledoc """
  In-tree sendable handoff+share after share_object.

  Proves `.cursor/add-mazel-handoff.md` and
  `.cursor/add-mazel-share.md` are committed
  in the repo tree. Reuses share_object vault
  write for find→Direct. Distinct from
  share_object (vault-only; share=object;
  paste_into_ai) and path_live_ready
  (live_ready / one_block / mix-missing).
  No invented public host. Off Group / Trust /
  Session / Consent / A2A / Match-core / dual
  unpaste/repaste edges.
  """

  def public_host, do: :none
  def handoff_rel, do: Room.InstallAddMazelFriendPathLiveReady.block_rel()
  def share_rel, do: Room.InstallAddMazelFriendShareObject.share_rel()

  def look_share, do: "ok  handoff=friend  share=in_tree"
  def look_block, do: "ok  block=sendable  path=#{share_rel()}"
  def look_tree(:yes), do: "ok  in_tree=yes"
  def look_tree(_), do: "error  in_tree=missing"
  def look_gate, do: Room.InstallAddMazelFriendShareObject.look_gate()
  def look_steps, do: Room.InstallAddMazelFriendShareObject.look_steps()
  def look_find(rec \\ %{}), do: Room.InstallAddMazelFriendShareObject.look_find(rec)
  def look_direct, do: Room.InstallAddMazelFriendShareObject.look_direct()
  def look_lane, do: Room.InstallAddMazelFriendShareObject.look_lane()
  def look_host, do: Room.InstallAddMazelFriendShareObject.look_host()

  def look(pack) when is_map(pack) do
    [
      look_share(),
      look_block(),
      look_tree(pack[:in_tree] || :missing),
      look_gate(),
      look_steps(),
      look_find(pack[:hit] || %{}),
      look_direct(),
      look_lane(),
      look_host()
    ]
  end

  def look(_), do: look(%{hit: %{}})

  @doc "Walk up from cwd to the repo root (VERSION or .git)."
  def repo_root(from \\ File.cwd!()) do
    walk = fn
      walk, dir ->
        cond do
          File.exists?(Path.join(dir, "VERSION")) or File.dir?(Path.join(dir, ".git")) ->
            {:ok, dir}

          dir == Path.dirname(dir) ->
            {:error, :root_miss}

          true ->
            walk.(walk, Path.dirname(dir))
        end
    end

    walk.(walk, Path.expand(from))
  end

  @doc "Both sendable files exist and are tracked in git."
  def probe_tree(root) when is_binary(root) do
    handoff = Path.join(root, handoff_rel())
    share = Path.join(root, share_rel())

    cond do
      File.regular?(handoff) and File.regular?(share) and tracked?(root, handoff_rel()) and
          tracked?(root, share_rel()) ->
        {:ok, %{in_tree: :yes, handoff: handoff, share: share}}

      true ->
        {:error,
         %{
           error: :in_tree_missing,
           in_tree: :missing,
           handoff: handoff,
           share: share,
           handoff_here: File.exists?(handoff),
           share_here: File.exists?(share),
           handoff_tracked: tracked?(root, handoff_rel()),
           share_tracked: tracked?(root, share_rel())
         }}
    end
  end

  def probe_tree(_), do: {:error, :root_miss}

  @doc """
  Tree has committed sendable handoff+share.
  Vault share-object still runs find→Direct.
  Isolated. Sibling share_object / live_ready
  LOOK stays.
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
              "mazel-install-add-mazel-friend-share-in-tree-#{System.unique_integer([:positive])}"
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
    with {:ok, prior} <-
           Room.InstallAddMazelFriendShareObject.demo(Keyword.put(opts, :root, root)),
         {:ok, tree_root} <- repo_root(),
         {:ok, probed} <- probe_tree(tree_root) do
      vault_handoff = Path.join(root, handoff_rel())
      vault_share = Path.join(root, share_rel())
      tree_handoff_text = File.read!(probed.handoff)
      tree_share_text = File.read!(probed.share)

      cond do
        prior.share != :object or prior.public_host != :none ->
          {:error, :share_miss}

        public_host() != :none ->
          {:error, :host_claimed}

        not File.exists?(vault_handoff) or not File.exists?(vault_share) ->
          {:error, :vault_miss}

        probed.in_tree != :yes ->
          {:error, :in_tree_missing}

        tree_handoff_text != prior.block_text ->
          {:error, :handoff_drift}

        tree_share_text != prior.share_text ->
          {:error, :share_drift}

        maze_path?(tree_handoff_text) or maze_path?(tree_share_text) ->
          {:error, :path_claimed}

        String.contains?(tree_share_text, "cwd") ->
          {:error, :path_claimed}

        Path.type(handoff_rel()) != :relative or Path.type(share_rel()) != :relative ->
          {:error, :path_claimed}

        look_share() != "ok  handoff=friend  share=in_tree" ->
          {:error, :share_look}

        look_share() == Room.InstallAddMazelFriendShareObject.look_share() ->
          {:error, :share_look}

        look_block() != "ok  block=sendable  path=#{share_rel()}" ->
          {:error, :block_look}

        look_block() == Room.InstallAddMazelFriendShareObject.look_block() ->
          {:error, :share_look}

        look_block() == Room.InstallAddMazelFriendPathLiveReady.look_block() ->
          {:error, :ready_look}

        look_tree(:yes) != "ok  in_tree=yes" ->
          {:error, :tree_look}

        look_tree(:missing) != "error  in_tree=missing" ->
          {:error, :tree_look}

        look_gate() != "ok  checkout=none  harness=none" ->
          {:error, :gate_look}

        look(%{in_tree: :yes, hit: prior.hit}) ==
            Room.InstallAddMazelFriendShareObject.look(prior) ->
          {:error, :share_look}

        look(%{in_tree: :yes, hit: prior.hit}) ==
            Room.InstallAddMazelFriendPathLiveReady.look(prior) ->
          {:error, :ready_look}

        Room.InstallAddMazelSkillFromHttps.live_url() != nil ->
          {:error, :live_claimed}

        true ->
          pack =
            Map.merge(prior, %{
              share: :in_tree,
              in_tree: :yes,
              tree_root: tree_root,
              probed: probed,
              public_host: :none
            })

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp tracked?(root, rel) do
    case System.cmd("git", ["-C", root, "ls-files", "--error-unmatch", "--", rel],
           stderr_to_stdout: true
         ) do
      {_, 0} -> true
      _ -> false
    end
  end

  defp maze_path?(text) do
    String.contains?(text, "/workspace") or
      String.contains?(text, "/absolute/path") or
      String.contains?(text, "apps/room")
  end
end
