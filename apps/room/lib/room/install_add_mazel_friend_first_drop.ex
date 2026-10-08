defmodule Room.InstallAddMazelFriendFirstDrop do
  @moduledoc """
  Friend-facing first-drop bullets that land the
  paste-door path.

  Short paste-into-AI block
  (`.cursor/add-mazel-first-drop.md`; 3–5
  bullets). Then share → mix on PATH → dual
  Add → Need×Have find → Direct ready.
  public_host stays none / live_host_ready=no.
  Distinct from share_paste_door (no first_drop=;
  share=paste_door=yes), share_object
  (share=object), and paste_door (no share=).
  Off Group / morph / Trust / invented host /
  mix user lane / Session / Consent / A2A /
  Match-core / share_paste_door remint.
  """

  alias Room.InstallAddMazelFriendSharePasteDoor, as: ShareDoor
  alias Room.InstallAddMazelFriendShareInTree, as: ShareTree
  alias Room.InstallAddMazelFriendShareObject, as: ShareObject
  alias Room.InstallAddMazelFriendPasteDoor, as: PasteDoor
  alias Room.InstallAddMazelFriendPublicHostReady, as: HostReady

  @drop_rel ".cursor/add-mazel-first-drop.md"
  @one_liner "Paste this into your AI and say Add Mazel."
  @min_bullets 3
  @max_bullets 5

  @locked """
  Paste this into your AI and say Add Mazel.

  **Try Mazel (friend drop)**
  1. Paste the Mazel block I send you into your AI chat (wherever you already talk).
  2. Tell it to Add Mazel (skill + tools) — no GitHub checkout.
  3. Say one Need or one thing you Have (plain words / tags).
  4. Ask it to find someone and mazel them — your agents talk first.
  5. Only join the human chat if both of you say yes.
  """

  def drop_rel, do: @drop_rel
  def one_liner, do: @one_liner
  def locked, do: @locked

  def look_drop, do: "ok  first_drop=yes  bullets=3..5"
  def look_share, do: "ok  share=sendable  paste_into_ai=yes"
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
      look_drop(),
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

  def bullets(text) when is_binary(text) do
    text
    |> String.split("\n")
    |> Enum.filter(&String.match?(&1, ~r/^\d+\. /))
  end

  def bullets(_), do: []

  def probe_drop(root) when is_binary(root) do
    path = Path.join(root, @drop_rel)

    cond do
      not File.regular?(path) ->
        {:error, :drop_missing}

      not tracked?(root, @drop_rel) ->
        {:error, :drop_untracked}

      true ->
        text = File.read!(path)
        items = bullets(text)
        count = length(items)

        cond do
          not String.contains?(text, @one_liner) ->
            {:error, :one_liner_miss}

          text != @locked ->
            {:error, :drop_copy}

          count < @min_bullets or count > @max_bullets ->
            {:error, :bullet_count}

          maze_path?(text) or String.contains?(text, "cwd") ->
            {:error, :path_claimed}

          String.contains?(text, "127.0.0.1") or String.contains?(text, "public_host=https") ->
            {:error, :host_claimed}

          String.contains?(text, "raw.githubusercontent") or String.contains?(text, "mazel.ai/") ->
            {:error, :host_claimed}

          true ->
            {:ok, %{path: path, text: text, bullets: items, count: count}}
        end
    end
  end

  def probe_drop(_), do: {:error, :root_miss}

  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path =
            Path.join(
              System.tmp_dir!(),
              "mazel-install-add-mazel-friend-first-drop-#{System.unique_integer([:positive])}"
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
         {:ok, drop} <- probe_drop(tree_root),
         {:ok, door} <- ShareDoor.demo(root: root) do
      lines = look()
      probed = HostReady.probe_host()

      cond do
        drop.count < @min_bullets or drop.count > @max_bullets ->
          {:error, :bullet_count}

        door.share != :sendable or door.paste_door != :yes ->
          {:error, :door_miss}

        door.onramp != :dual or door.checkout != :none ->
          {:error, :add_miss}

        door.public_host != :none or door.live_host_ready != :no ->
          {:error, :host_claimed}

        probed != %{public_host: :none, live_host_ready: :no} ->
          {:error, :host_claimed}

        drop.text != @locked ->
          {:error, :drop_copy}

        look_drop() != "ok  first_drop=yes  bullets=3..5" ->
          {:error, :drop_look}

        look_share() != "ok  share=sendable  paste_into_ai=yes" ->
          {:error, :share_look}

        look_share() == ShareDoor.look_share() ->
          {:error, :door_look}

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

        lines == ShareDoor.look() ->
          {:error, :door_look}

        lines == PasteDoor.look() ->
          {:error, :paste_look}

        Enum.any?(lines, &String.contains?(&1, "share=object")) ->
          {:error, :object_look}

        Enum.any?(lines, &String.contains?(&1, "paste_door=yes")) ->
          {:error, :door_look}

        Enum.any?(lines, &String.contains?(&1, "why  you_have")) ->
          {:error, :session_look}

        Enum.any?(lines, &String.contains?(&1, "return=agent")) ->
          {:error, :session_look}

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

        Room.InstallAddMazelSkillFromHttps.live_url() != nil ->
          {:error, :live_claimed}

        true ->
          {:ok,
           door
           |> Map.put(:first_drop, :yes)
           |> Map.put(:bullets, drop.bullets)
           |> Map.put(:bullet_count, drop.count)
           |> Map.put(:drop_rel, @drop_rel)
           |> Map.put(:drop_text, drop.text)
           |> Map.put(:lines, lines)}
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
