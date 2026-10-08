defmodule Room.InstallAddMazelFriendPasteDoor do
  @moduledoc """
  Friend-machine mix on PATH, dual-portable Add,
  Need×Have find, Direct ready. Install door.

  public_host stays none / live_host_ready=no.
  Session owns Direct talk. Consent owns join.
  Distinct from mix_on_path (no Need×Have line),
  path_handoff* (handoff=friend mix=on_path first),
  find_why (Session talk/return), host_none
  remints, and Consent fixtures. Off Group /
  morph / Trust / invented host / mix user lane.
  """

  @x "series-a"
  @y "cto"
  @you "ariel@mazel"
  @they "kai@mazel"

  alias Room.InstallAddMazelFriendMixOnPath, as: MixOnPath
  alias Room.InstallAddMazelFriendTryDualPortable, as: Dual
  alias Room.InstallAddMazelFriendPublicHostReady, as: HostReady

  def look_mix, do: "ok  mix=on_path  handoff=friend"
  def look_add, do: Room.SessionDirectAfterDualPortableAdd.look_add()
  def look_need, do: "ok  need=self_report"
  def look_find, do: Dual.look_find(%{handle: @they, query: @x})
  def look_direct, do: Dual.look_direct()
  def look_host, do: HostReady.look_host(:none)
  def look_ready, do: HostReady.look_ready(:no)
  def look_lane, do: Dual.look_lane()

  def look(_ \\ %{}) do
    [
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
              "mazel-install-add-mazel-friend-paste-door-#{System.unique_integer([:positive])}"
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
    you = %{
      need: Room.SelfReportMatch.report(:need, @x, handle: @you),
      has: Room.SelfReportMatch.report(:has, @y, handle: @you)
    }

    they = %{
      need: Room.SelfReportMatch.report(:need, @y, handle: @they),
      has: Room.SelfReportMatch.report(:has, @x, handle: @they)
    }

    paired = Room.SelfReportMatch.both(you, they)

    with {:ok, prior} <- MixOnPath.demo(root: root) do
      probed = HostReady.probe_host()
      lines = look()

      cond do
        prior.onramp != :dual or prior.checkout != :none ->
          {:error, :add_miss}

        prior.public_host != :none or prior.live_host_ready != :no ->
          {:error, :host_claimed}

        prior.hit.handle != @they ->
          {:error, :find_miss}

        not paired.ok or paired.error != nil ->
          {:error, :both_miss}

        probed.public_host != :none or probed.live_host_ready != :no ->
          {:error, :host_claimed}

        look_mix() != "ok  mix=on_path  handoff=friend" ->
          {:error, :mix_look}

        look_mix() == Room.InstallAddMazelFriendPathHandoff.look_handoff() ->
          {:error, :handoff_look}

        look_need() != "ok  need=self_report" ->
          {:error, :need_look}

        look_direct() != "ok  direct=@kai  session=ready" ->
          {:error, :direct_look}

        look_host() != "error  public_host=none" ->
          {:error, :host_look}

        look_ready() != "ok  live_host_ready=no" ->
          {:error, :ready_look}

        lines == MixOnPath.look(prior) ->
          {:error, :mix_on_path_look}

        lines == Dual.look(prior) ->
          {:error, :dual_look}

        lines == Room.InstallAddMazelFriendPathHandoffDual.look(prior) ->
          {:error, :handoff_look}

        lines == Room.SessionDirectAfterDualPortableFindWhy.look(:default) ->
          {:error, :session_look}

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

        Room.InstallAddMazelSkillFromHttps.live_url() != nil ->
          {:error, :live_claimed}

        true ->
          {:ok,
           prior
           |> Map.put(:paired, paired)
           |> Map.put(:public_host, :none)
           |> Map.put(:live_host_ready, :no)
           |> Map.put(:lines, lines)}
      end
    end
  end
end
