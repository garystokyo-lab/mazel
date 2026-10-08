defmodule Room.InstallAddMazelFriendPublicHostReady do
  @moduledoc """
  Honest public_host / live-host readiness
  after in-tree share.

  Reuses share_in_tree (find→Direct). Live
  skill https is still none — no invented
  host (mazel.ai marketing / GitHub raw
  404s / loopback). Distinct from
  share_in_tree (ok public_host=none; no
  live_host_ready=), from_https
  (url_fixture theater / live_https=none),
  and path_live_ready (live_ready=yes).
  Off Group / Trust / Session / Consent /
  A2A / Match-core / dual unpaste/repaste.
  """

  def public_host, do: probe_host().public_host
  def live_host_ready, do: probe_host().live_host_ready

  def look_share, do: Room.InstallAddMazelFriendShareInTree.look_share()
  def look_tree, do: Room.InstallAddMazelFriendShareInTree.look_tree(:yes)
  def look_host(:none), do: "error  public_host=none"
  def look_host(host) when is_binary(host), do: "ok  public_host=#{host}"
  def look_host(_), do: look_host(:none)
  def look_ready(:no), do: "ok  live_host_ready=no"
  def look_ready(:yes), do: "ok  live_host_ready=yes"
  def look_ready(_), do: look_ready(:no)
  def look_gate, do: Room.InstallAddMazelFriendShareInTree.look_gate()
  def look_steps, do: Room.InstallAddMazelFriendShareInTree.look_steps()
  def look_find(rec \\ %{}), do: Room.InstallAddMazelFriendShareInTree.look_find(rec)
  def look_direct, do: Room.InstallAddMazelFriendShareInTree.look_direct()
  def look_lane, do: Room.InstallAddMazelFriendShareInTree.look_lane()

  def look(pack) when is_map(pack) do
    host = pack[:public_host] || :none
    ready = pack[:live_host_ready] || :no

    [
      look_share(),
      look_tree(),
      look_host(host),
      look_ready(ready),
      look_gate(),
      look_steps(),
      look_find(pack[:hit] || %{}),
      look_direct(),
      look_lane()
    ]
  end

  def look(_), do: look(%{hit: %{}})

  @doc """
  Friend-handable https host, or honest none.
  Invented marketing / raw / loopback miss.
  `:install` reads skill live_url (still none).
  `:a2a` reads the founder origin allowlist.
  """
  def probe_host, do: probe_host(:install)

  def probe_host(:install) do
    probe_origin(Room.InstallAddMazelSkillFromHttps.live_url())
  end

  def probe_host(:a2a) do
    probe_origin(Room.A2aPeerCard.founder_origin())
  end

  def probe_host(_), do: probe_host(:install)

  defp probe_origin(url) do
    cond do
      is_nil(url) or url == "" ->
        %{public_host: :none, live_host_ready: :no}

      Room.A2aPeerCard.invented_host?(url) ->
        %{public_host: :none, live_host_ready: :no, invented: true}

      true ->
        %{public_host: url, live_host_ready: :yes}
    end
  end

  @doc """
  In-tree share find→Direct, then honest
  public_host stance. Isolated. Sibling
  share_in_tree / from_https / live_ready
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
              "mazel-install-add-mazel-friend-public-host-ready-#{System.unique_integer([:positive])}"
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
           Room.InstallAddMazelFriendShareInTree.demo(Keyword.put(opts, :root, root)) do
      probed = probe_host()

      cond do
        prior.share != :in_tree or prior.in_tree != :yes ->
          {:error, :tree_miss}

        prior.public_host != :none ->
          {:error, :host_claimed}

        probed[:invented] == true ->
          {:error, :host_claimed}

        Room.InstallAddMazelSkillFromHttps.live_url() != nil ->
          {:error, :live_claimed}

        probed.public_host != :none or probed.live_host_ready != :no ->
          {:error, :host_claimed}

        look_share() != "ok  handoff=friend  share=in_tree" ->
          {:error, :share_look}

        look_tree() != "ok  in_tree=yes" ->
          {:error, :tree_look}

        look_host(:none) != "error  public_host=none" ->
          {:error, :host_look}

        look_host(:none) == Room.InstallAddMazelFriendShareInTree.look_host() ->
          {:error, :share_look}

        look_ready(:no) != "ok  live_host_ready=no" ->
          {:error, :ready_look}

        look_ready(:no) == Room.InstallAddMazelFriendPathLiveReady.look_ready() ->
          {:error, :ready_look}

        look_ready(:yes) == Room.InstallAddMazelFriendPathLiveReady.look_ready() ->
          {:error, :ready_look}

        look_gate() != "ok  checkout=none  harness=none" ->
          {:error, :gate_look}

        look(%{hit: prior.hit, public_host: :none, live_host_ready: :no}) ==
            Room.InstallAddMazelFriendShareInTree.look(prior) ->
          {:error, :share_look}

        look(%{hit: prior.hit}) == Room.InstallAddMazelSkillFromHttps.look(prior) ->
          {:error, :https_look}

        look(%{hit: prior.hit}) == Room.InstallAddMazelFriendPathLiveReady.look(prior) ->
          {:error, :ready_look}

        Enum.any?(look(%{hit: prior.hit}), &String.contains?(&1, "from=url_fixture")) ->
          {:error, :https_look}

        Enum.any?(look(%{hit: prior.hit}), &String.contains?(&1, "live_https=")) ->
          {:error, :https_look}

        Enum.any?(look(%{hit: prior.hit}), &String.contains?(&1, "127.0.0.1")) ->
          {:error, :host_claimed}

        Enum.any?(look(%{hit: prior.hit}), &String.contains?(&1, "raw.githubusercontent")) ->
          {:error, :host_claimed}

        true ->
          pack =
            Map.merge(prior, %{
              public_host: :none,
              live_host_ready: :no
            })

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

end
