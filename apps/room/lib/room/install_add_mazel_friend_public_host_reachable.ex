defmodule Room.InstallAddMazelFriendPublicHostReachable do
  @moduledoc """
  After public_host_ready, prove invented
  hosts are refused and nothing is reachable.

  Reuses public_host_ready (error public_host=none
  / live_host_ready=no). mazel.ai / GitHub raw /
  loopback stay invented — never the friend skill
  host. reachable=none until a real public_host
  fetches. Distinct from public_host_ready (no
  invented= / reachable=), share_in_tree
  (ok public_host=none), from_https
  (url_fixture / live_https=none), and
  path_live_ready (live_ready=yes). Off Group /
  Trust / Session / Consent / A2A / Match-core /
  dual unpaste/repaste.
  """

  @invented_candidates [
    "https://mazel.ai/ADD_MAZEL_SKILL.md",
    "https://raw.githubusercontent.com/mazel/mazel/main/docs/ADD_MAZEL_SKILL.md",
    "http://127.0.0.1/ADD_MAZEL_SKILL.md",
    "http://localhost/ADD_MAZEL_SKILL.md"
  ]

  def public_host, do: Room.InstallAddMazelFriendPublicHostReady.public_host()
  def live_host_ready, do: Room.InstallAddMazelFriendPublicHostReady.live_host_ready()
  def reachable, do: probe_reachable()

  def look_share, do: Room.InstallAddMazelFriendPublicHostReady.look_share()
  def look_tree, do: Room.InstallAddMazelFriendPublicHostReady.look_tree()
  def look_host(host \\ :none), do: Room.InstallAddMazelFriendPublicHostReady.look_host(host)
  def look_ready(ready \\ :no), do: Room.InstallAddMazelFriendPublicHostReady.look_ready(ready)
  def look_invented, do: "error  invented=refused"
  def look_reachable(:none), do: "error  reachable=none"
  def look_reachable(:yes), do: "ok  reachable=yes"
  def look_reachable(_), do: look_reachable(:none)
  def look_gate, do: Room.InstallAddMazelFriendPublicHostReady.look_gate()
  def look_steps, do: Room.InstallAddMazelFriendPublicHostReady.look_steps()
  def look_find(rec \\ %{}), do: Room.InstallAddMazelFriendPublicHostReady.look_find(rec)
  def look_direct, do: Room.InstallAddMazelFriendPublicHostReady.look_direct()
  def look_lane, do: Room.InstallAddMazelFriendPublicHostReady.look_lane()

  def look(pack) when is_map(pack) do
    host = pack[:public_host] || :none
    ready = pack[:live_host_ready] || :no
    reach = pack[:reachable] || :none

    [
      look_share(),
      look_tree(),
      look_host(host),
      look_ready(ready),
      look_invented(),
      look_reachable(reach),
      look_gate(),
      look_steps(),
      look_find(pack[:hit] || %{}),
      look_direct(),
      look_lane()
    ]
  end

  def look(_), do: look(%{hit: %{}})

  @doc """
  Invented marketing / raw / loopback miss.
  """
  def refuse_invented? do
    Enum.all?(@invented_candidates, &invented_host?/1)
  end

  @doc """
  Reachable only if probe yields a non-invented
  host that fetches. Else none.
  """
  def probe_reachable do
    probed = Room.InstallAddMazelFriendPublicHostReady.probe_host()

    cond do
      probed.public_host == :none ->
        :none

      probed.live_host_ready != :yes ->
        :none

      invented_host?(probed.public_host) ->
        :none

      true ->
        case Room.InstallAddMazelSkillFromHttps.fetch(probed.public_host) do
          {:ok, body} when is_binary(body) and body != "" -> :yes
          _ -> :none
        end
    end
  end

  @doc """
  In-tree share find→Direct, honest none, then
  invented refused + reachable none. Isolated.
  Sibling public_host_ready / from_https /
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
              "mazel-install-add-mazel-friend-public-host-reachable-#{System.unique_integer([:positive])}"
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
      reach = probe_reachable()

      cond do
        prior.share != :in_tree or prior.in_tree != :yes ->
          {:error, :tree_miss}

        prior.public_host != :none or prior.live_host_ready != :no ->
          {:error, :host_claimed}

        not refuse_invented?() ->
          {:error, :invented_miss}

        reach != :none ->
          {:error, :host_claimed}

        Room.InstallAddMazelSkillFromHttps.live_url() != nil ->
          {:error, :live_claimed}

        look_invented() != "error  invented=refused" ->
          {:error, :invented_look}

        look_reachable(:none) != "error  reachable=none" ->
          {:error, :reach_look}

        look_reachable(:yes) == look_reachable(:none) ->
          {:error, :reach_look}

        look(prior) == Room.InstallAddMazelFriendPublicHostReady.look(prior) ->
          {:error, :ready_look}

        look(prior) == Room.InstallAddMazelFriendShareInTree.look(prior) ->
          {:error, :share_look}

        look(prior) == Room.InstallAddMazelSkillFromHttps.look(prior) ->
          {:error, :https_look}

        look(prior) == Room.InstallAddMazelFriendPathLiveReady.look(prior) ->
          {:error, :ready_look}

        Enum.any?(look(prior), &String.contains?(&1, "from=url_fixture")) ->
          {:error, :https_look}

        Enum.any?(look(prior), &String.contains?(&1, "live_https=")) ->
          {:error, :https_look}

        Enum.any?(look(prior), &String.contains?(&1, "127.0.0.1")) ->
          {:error, :host_claimed}

        Enum.any?(look(prior), &String.contains?(&1, "raw.githubusercontent")) ->
          {:error, :host_claimed}

        Enum.any?(look(prior), &String.contains?(&1, "mazel.ai/")) ->
          {:error, :host_claimed}

        true ->
          pack =
            Map.merge(prior, %{
              invented: :refused,
              reachable: :none
            })

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp invented_host?(url), do: Room.A2aPeerCard.invented_host?(url)
end