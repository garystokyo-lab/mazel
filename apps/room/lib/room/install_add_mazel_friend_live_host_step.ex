defmodule Room.InstallAddMazelFriendLiveHostStep do
  @moduledoc """
  After public_host_ready, name the next
  honest blocker: a friend-handable public
  https host.

  Still public_host=none / live_host_ready=no.
  next=public_https — not mazel.ai, not GitHub
  raw, not loopback / url_fixture. Distinct
  from public_host_ready (no next=),
  public_host_reachable (invented= / reachable=),
  from_https (url_fixture / live_https=none),
  and path_live_ready (live_ready=yes). Off
  Group / Trust / Session / Consent / A2A /
  Match-core / dual unpaste/repaste.
  """

  def public_host, do: Room.InstallAddMazelFriendPublicHostReady.public_host()
  def live_host_ready, do: Room.InstallAddMazelFriendPublicHostReady.live_host_ready()
  def next_step, do: :public_https

  def look_share, do: Room.InstallAddMazelFriendPublicHostReady.look_share()
  def look_tree, do: Room.InstallAddMazelFriendPublicHostReady.look_tree()
  def look_host(host \\ :none), do: Room.InstallAddMazelFriendPublicHostReady.look_host(host)
  def look_ready(ready \\ :no), do: Room.InstallAddMazelFriendPublicHostReady.look_ready(ready)
  def look_next, do: "ok  next=public_https"
  def look_gate, do: Room.InstallAddMazelFriendPublicHostReady.look_gate()
  def look_steps, do: Room.InstallAddMazelFriendPublicHostReady.look_steps()
  def look_find(rec \\ %{}), do: Room.InstallAddMazelFriendPublicHostReady.look_find(rec)
  def look_direct, do: Room.InstallAddMazelFriendPublicHostReady.look_direct()
  def look_lane, do: Room.InstallAddMazelFriendPublicHostReady.look_lane()

  def look(pack) when is_map(pack) do
    host = pack[:public_host] || :none
    ready = pack[:live_host_ready] || :no

    [
      look_share(),
      look_tree(),
      look_host(host),
      look_ready(ready),
      look_next(),
      look_gate(),
      look_steps(),
      look_find(pack[:hit] || %{}),
      look_direct(),
      look_lane()
    ]
  end

  def look(_), do: look(%{hit: %{}})

  @doc """
  In-tree share find→Direct, honest none, then
  name next=public_https. Isolated. Sibling
  public_host_ready / reachable / from_https /
  live_ready LOOK stays.
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
              "mazel-install-add-mazel-friend-live-host-step-#{System.unique_integer([:positive])}"
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
           Room.InstallAddMazelFriendPublicHostReady.demo(Keyword.put(opts, :root, root)) do
      cond do
        prior.share != :in_tree or prior.in_tree != :yes ->
          {:error, :tree_miss}

        prior.public_host != :none or prior.live_host_ready != :no ->
          {:error, :host_claimed}

        Room.InstallAddMazelSkillFromHttps.live_url() != nil ->
          {:error, :live_claimed}

        Room.InstallAddMazelFriendPublicHostReachable.probe_reachable() != :none ->
          {:error, :host_claimed}

        not Room.InstallAddMazelFriendPublicHostReachable.refuse_invented?() ->
          {:error, :invented_miss}

        next_step() != :public_https ->
          {:error, :next_miss}

        look_next() != "ok  next=public_https" ->
          {:error, :next_look}

        look(prior) == Room.InstallAddMazelFriendPublicHostReady.look(prior) ->
          {:error, :ready_look}

        look(prior) == Room.InstallAddMazelFriendPublicHostReachable.look(prior) ->
          {:error, :reach_look}

        look(prior) == Room.InstallAddMazelSkillFromHttps.look(prior) ->
          {:error, :https_look}

        look(prior) == Room.InstallAddMazelFriendPathLiveReady.look(prior) ->
          {:error, :ready_look}

        Enum.any?(look(prior), &String.contains?(&1, "from=url_fixture")) ->
          {:error, :https_look}

        Enum.any?(look(prior), &String.contains?(&1, "live_https=")) ->
          {:error, :https_look}

        Enum.any?(look(prior), &String.contains?(&1, "invented=")) ->
          {:error, :reach_look}

        Enum.any?(look(prior), &String.contains?(&1, "reachable=")) ->
          {:error, :reach_look}

        Enum.any?(look(prior), &String.contains?(&1, "127.0.0.1")) ->
          {:error, :host_claimed}

        Enum.any?(look(prior), &String.contains?(&1, "raw.githubusercontent")) ->
          {:error, :host_claimed}

        Enum.any?(look(prior), &String.contains?(&1, "mazel.ai/")) ->
          {:error, :host_claimed}

        true ->
          pack =
            Map.merge(prior, %{
              next: :public_https
            })

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end
end