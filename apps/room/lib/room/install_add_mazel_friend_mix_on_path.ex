defmodule Room.InstallAddMazelFriendMixOnPath do
  @moduledoc """
  After portable Add Mazel, mix on PATH for a
  friend machine. public_host stays none.

  handoff=friend portable=yes, checkout=none,
  then mix=on_path, then Add→paste→find→Direct.
  live_host_ready=no. No invented mazel.ai /
  GitHub raw / loopback. Distinct from
  friend_mix_path (no door steps), mix_path
  (PATH gate then Add), path_handoff*
  (handoff=friend mix=on_path first),
  path_live_ready (live_ready=yes), and
  public_host_ready / live_host_step /
  reachable. Session owns Direct. Consent
  owns join. Off Group / Trust / host_ready
  success / mix user lane.
  """

  alias Room.InstallAddMazelFriendTryDualPortable, as: Dual
  alias Room.InstallAddMazelFriendTryDualPortableMixPath, as: MixPath
  alias Room.InstallAddMazelFriendTryDualPortableFriendMixPath, as: FriendMix
  alias Room.InstallAddMazelFriendPublicHostReady, as: HostReady

  def look_handoff, do: "ok  handoff=friend  portable=yes"
  def look_checkout, do: Dual.look_checkout()
  def look_mix, do: MixPath.look_on_path()
  def look_steps, do: Dual.look_steps()
  def look_add_paste, do: Dual.look_add_paste()
  def look_find(rec \\ %{}), do: Dual.look_find(rec)
  def look_direct, do: Dual.look_direct()
  def look_host, do: HostReady.look_host(:none)
  def look_ready, do: HostReady.look_ready(:no)
  def look_lane, do: Dual.look_lane()

  def look(pack \\ %{}) do
    [
      look_handoff(),
      look_checkout(),
      look_mix(),
      look_steps(),
      look_add_paste(),
      look_find(pack[:hit] || %{}),
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
              "mazel-install-add-mazel-friend-mix-on-path-#{System.unique_integer([:positive])}"
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
    with {:ok, add} <- Dual.demo(root: root),
         {:ok, mix_path} <- MixPath.probe("mix") do
      probed = HostReady.probe_host()
      reach = Room.InstallAddMazelFriendPublicHostReachable.probe_reachable()
      lines = look(add)

      cond do
        add.onramp != :dual or add.checkout != :none ->
          {:error, :onramp_miss}

        add.public_host != :none ->
          {:error, :host_claimed}

        add.hit.handle != "kai@mazel" ->
          {:error, :find_miss}

        Path.type(mix_path) != :absolute ->
          {:error, :path_claimed}

        String.contains?(mix_path, "apps/room") ->
          {:error, :path_claimed}

        probed.public_host != :none or probed.live_host_ready != :no ->
          {:error, :host_claimed}

        reach != :none ->
          {:error, :host_claimed}

        Room.InstallAddMazelSkillFromHttps.live_url() != nil ->
          {:error, :live_claimed}

        look_handoff() != "ok  handoff=friend  portable=yes" ->
          {:error, :handoff_look}

        look_handoff() == Room.InstallAddMazelFriendPathHandoff.look_handoff() ->
          {:error, :handoff_look}

        look_mix() != "ok  mix=on_path" ->
          {:error, :mix_look}

        look_mix() == FriendMix.look_mix() ->
          {:error, :friend_mix_look}

        look_host() != "error  public_host=none" ->
          {:error, :host_look}

        look_ready() != "ok  live_host_ready=no" ->
          {:error, :ready_look}

        look_ready() == HostReady.look_ready(:yes) ->
          {:error, :ready_claimed}

        look_lane() != "ok  mix_user_lane=no" ->
          {:error, :lane_look}

        lines == Dual.look(add) ->
          {:error, :dual_look}

        lines == MixPath.look(add) ->
          {:error, :mix_path_look}

        lines == FriendMix.look() ->
          {:error, :friend_mix_look}

        lines == Room.InstallAddMazelFriendPathHandoffDual.look(add) ->
          {:error, :handoff_look}

        lines == Room.InstallAddMazelFriendPathLiveReady.look(add) ->
          {:error, :live_look}

        lines == HostReady.look(add) ->
          {:error, :ready_look}

        lines == Room.InstallAddMazelFriendLiveHostStep.look(add) ->
          {:error, :step_look}

        Enum.any?(lines, &String.contains?(&1, "live_host_ready=yes")) ->
          {:error, :ready_claimed}

        Enum.any?(lines, &String.contains?(&1, "live_ready=yes")) ->
          {:error, :live_look}

        Enum.any?(lines, &String.contains?(&1, "127.0.0.1")) ->
          {:error, :host_claimed}

        Enum.any?(lines, &String.contains?(&1, "public_host=https")) ->
          {:error, :host_claimed}

        Enum.any?(lines, &String.contains?(&1, "raw.githubusercontent")) ->
          {:error, :host_claimed}

        Enum.any?(lines, &String.contains?(&1, "mazel.ai/")) ->
          {:error, :host_claimed}

        true ->
          {:ok,
           add
           |> Map.put(:mix_path, mix_path)
           |> Map.put(:handoff, :friend)
           |> Map.put(:portable, :yes)
           |> Map.put(:live_host_ready, :no)
           |> Map.put(:public_host, :none)
           |> Map.put(:lines, lines)}
      end
    end
  end
end