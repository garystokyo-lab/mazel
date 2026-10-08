defmodule Room.InstallAddMazelSkillBadUrlThenPath do
  @moduledoc """
  Bad skill URL fails clearly, then friend-path retry works.

  404 on the https fetch rail (no public host). Retry is
  docs/ADD_MAZEL_SKILL.md (from=path) → Add→paste→find→Direct.
  Distinct from install_add_mazel_skill_bad_url (error only;
  sibling green, no retry strip), from_url (path only), and
  from_https (url_fixture happy). Off Group / Trust /
  invented live host / mix user lane.
  """

  @gone_path "/gone.md"
  @file_url "file:///tmp/mazel-no-such-skill.md"

  def live_url, do: Room.InstallAddMazelSkillFromHttps.live_url()

  def look_404, do: Room.InstallAddMazelSkillBadUrl.look_404()
  def look_clear, do: "ok  clear_error=yes"
  def look_retry, do: "ok  retry=from_path  friend_handable"
  def look_steps, do: Room.InstallAddMazelPack.look_steps()
  def look_add_paste, do: Room.InstallAddMazelPack.look_add_paste()
  def look_find(rec \\ %{}), do: Room.InstallAddMazelPack.look_find(rec)
  def look_direct, do: Room.InstallAddMazelPack.look_direct()
  def look_lane, do: "ok  mix_user_lane=no"

  def look(pack) when is_map(pack) do
    [
      look_404(),
      look_clear(),
      look_retry(),
      look_steps(),
      look_add_paste(),
      look_find(pack.hit),
      look_direct(),
      look_lane()
    ]
  end

  def look(_), do: look(%{hit: %{}})

  @doc """
  Loopback 404, then friend-path retry. Isolated.
  Sibling bad_url / from_url / from_https LOOK stays.
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
              "mazel-install-add-mazel-skill-bad-url-then-path-#{System.unique_integer([:positive])}"
            )

          File.mkdir_p!(path)
          {path, true}
      end

    port = Keyword.get(opts, :port) || 47000 + rem(System.unique_integer([:positive]), 2000)

    try do
      demo_on(root, port)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp demo_on(root, port) do
    url = "http://127.0.0.1:#{port}#{@gone_path}"
    {:ok, pid} = start_fixture!(port)

    try do
      with {:error, :not_found} <- fetch_miss(url),
           {:error, :bad_scheme} <- Room.InstallAddMazelSkillFromHttps.fetch(@file_url),
           {:ok, retried} <- Room.InstallAddMazelSkillFromUrl.demo(root: root) do
        cond do
          live_url() != nil ->
            {:error, :live_claimed}

          retried.from != :path ->
            {:error, :retry_miss}

          retried.hit.handle != "kai@mazel" ->
            {:error, :find_miss}

          retried.mix_user_lane != :no ->
            {:error, :mix_lane}

          look_404() != "error  skill=add_mazel  from=https  reason=404" ->
            {:error, :look_miss}

          look_retry() != "ok  retry=from_path  friend_handable" ->
            {:error, :look_miss}

          true ->
            pack =
              Map.merge(retried, %{
                url: url,
                not_found: :not_found,
                retried: retried,
                mix_user_lane: :no,
                live_url: live_url()
              })

            {:ok, Map.put(pack, :lines, look(pack))}
        end
      end
    after
      Process.exit(pid, :normal)
    end
  end

  defp fetch_miss(url, tries \\ 8) do
    case Room.InstallAddMazelSkillFromHttps.fetch(url) do
      {:error, :not_found} ->
        {:error, :not_found}

      {:ok, _} ->
        {:error, :unexpected_ok}

      {:error, _} when tries > 1 ->
        Process.sleep(25)
        fetch_miss(url, tries - 1)

      error ->
        error
    end
  end

  defp start_fixture!(port) do
    Bandit.start_link(
      plug:
        {Room.InstallAddMazelSkillFromHttps.Fixture,
         [body: "# none\n", path: "/ADD_MAZEL_SKILL.md"]},
      scheme: :http,
      port: port,
      thousand_island_options: [transport_options: [ip: {127, 0, 0, 1}]]
    )
  end
end