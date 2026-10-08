defmodule Room.InstallAddMazelFriendSharePasteDoor do
  @moduledoc """
  Sendable in-tree share that lands the paste-door
  path on a friend's machine.

  share → mix on PATH → dual Add → Need×Have
  find → Direct ready. Friend pastes
  `.cursor/add-mazel-share.md`.
  public_host stays none / live_host_ready=no.
  Session owns Direct talk. Consent owns join.
  Distinct from share_object (share=object;
  paste_into_ai), share_in_tree (share=in_tree;
  no paste_door=), and paste_door (no share=).
  Off Group / morph / Trust / invented host /
  mix user lane / Session / Consent / A2A /
  Match-core.
  """

  alias Room.InstallAddMazelFriendShareInTree, as: ShareTree
  alias Room.InstallAddMazelFriendShareObject, as: ShareObject
  alias Room.InstallAddMazelFriendPasteDoor, as: PasteDoor
  alias Room.InstallAddMazelFriendPublicHostReady, as: HostReady

  def share_rel, do: ShareTree.share_rel()

  def look_share, do: "ok  share=sendable  paste_door=yes"
  def look_mix, do: PasteDoor.look_mix()
  def look_add, do: PasteDoor.look_add()
  def look_need, do: PasteDoor.look_need()
  def look_find, do: PasteDoor.look_find()
  def look_direct, do: PasteDoor.look_direct()
  def look_host, do: PasteDoor.look_host()
  def look_ready, do: PasteDoor.look_ready()
  def look_lane, do: PasteDoor.look_lane()

  def look(_ \\ %{}) do
    [
      look_share(),
      look_mix(),
      look_add(),
      look_need(),
      look_find(),
      look_direct(),
      look_host(),
      look_ready(),
      look_lane()
    ]
  end

  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path =
            Path.join(
              System.tmp_dir!(),
              "mazel-install-add-mazel-friend-share-paste-door-#{System.unique_integer([:positive])}"
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
    with {:ok, tree_root} <- ShareTree.repo_root(),
         {:ok, probed} <- ShareTree.probe_tree(tree_root),
         {:ok, door} <- PasteDoor.demo(root: root) do
      share_text = File.read!(probed.share)
      lines = look()

      cond do
        probed.in_tree != :yes ->
          {:error, :in_tree_missing}

        share_rel() != ".cursor/add-mazel-share.md" ->
          {:error, :share_path}

        Path.type(share_rel()) != :relative ->
          {:error, :path_claimed}

        not String.contains?(share_text, "Paste this into your AI.") ->
          {:error, :share_miss}

        maze_path?(share_text) or String.contains?(share_text, "cwd") ->
          {:error, :path_claimed}

        door.onramp != :dual or door.checkout != :none ->
          {:error, :add_miss}

        door.public_host != :none or door.live_host_ready != :no ->
          {:error, :host_claimed}

        door.hit.handle != "kai@mazel" ->
          {:error, :find_miss}

        look_share() != "ok  share=sendable  paste_door=yes" ->
          {:error, :share_look}

        look_share() == ShareTree.look_share() ->
          {:error, :tree_look}

        look_share() == ShareObject.look_share() ->
          {:error, :object_look}

        look_mix() != "ok  mix=on_path  handoff=friend" ->
          {:error, :mix_look}

        look_need() != "ok  need=self_report" ->
          {:error, :need_look}

        look_direct() != "ok  direct=@kai  session=ready" ->
          {:error, :direct_look}

        look_host() != "error  public_host=none" ->
          {:error, :host_look}

        look_ready() != "ok  live_host_ready=no" ->
          {:error, :ready_look}

        lines == PasteDoor.look() ->
          {:error, :door_look}

        lines == ShareTree.look(%{in_tree: :yes, hit: %{}}) ->
          {:error, :tree_look}

        lines == ShareObject.look(%{}) ->
          {:error, :object_look}

        Enum.any?(lines, &String.contains?(&1, "share=in_tree")) ->
          {:error, :tree_look}

        Enum.any?(lines, &String.contains?(&1, "share=object")) ->
          {:error, :object_look}

        Enum.any?(lines, &String.contains?(&1, "paste_into_ai")) ->
          {:error, :object_look}

        Enum.any?(lines, &String.contains?(&1, "why  you_have")) ->
          {:error, :session_look}

        Enum.any?(lines, &String.contains?(&1, "return=agent")) ->
          {:error, :session_look}

        Enum.any?(lines, &String.contains?(&1, "live_host=fixture")) ->
          {:error, :fixture_look}

        Enum.any?(lines, &String.contains?(&1, "live_host_ready=yes")) ->
          {:error, :ready_claimed}

        Enum.any?(lines, &String.contains?(&1, "127.0.0.1")) ->
          {:error, :host_claimed}

        Enum.any?(lines, &String.contains?(&1, "public_host=https")) ->
          {:error, :host_claimed}

        Enum.any?(lines, &String.contains?(&1, "raw.githubusercontent")) ->
          {:error, :host_claimed}

        Enum.any?(lines, &String.contains?(&1, "mazel.ai/")) ->
          {:error, :host_claimed}

        Enum.any?(lines, &String.contains?(&1, "group=")) ->
          {:error, :group_look}

        Enum.any?(lines, &String.contains?(&1, "morph=")) ->
          {:error, :morph_look}

        HostReady.probe_host() != %{public_host: :none, live_host_ready: :no} ->
          {:error, :host_claimed}

        Room.InstallAddMazelSkillFromHttps.live_url() != nil ->
          {:error, :live_claimed}

        true ->
          {:ok,
           door
           |> Map.put(:share, :sendable)
           |> Map.put(:paste_door, :yes)
           |> Map.put(:share_rel, share_rel())
           |> Map.put(:tree_root, tree_root)
           |> Map.put(:probed, probed)
           |> Map.put(:public_host, :none)
           |> Map.put(:live_host_ready, :no)
           |> Map.put(:lines, lines)}
      end
    end
  end

  defp maze_path?(text) do
    String.contains?(text, "/workspace") or
      String.contains?(text, "/absolute/path") or
      String.contains?(text, "apps/room")
  end
end