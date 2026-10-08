defmodule Room.InstallAddMazelSkillBadUrl do
  @moduledoc """
  Bad skill URL fails clearly. No public host.

  404 on the https fetch rail + file:// is non_https.
  Path sibling stays green. Distinct from
  install_add_mazel_skill_from_https (url_fixture happy
  fetch) and install_add_mazel_skill_from_url (from=path).
  Off Group / Trust / invented live host / mix user lane.
  """

  @gone_path "/gone.md"
  @file_url "file:///tmp/mazel-no-such-skill.md"

  def live_url, do: Room.InstallAddMazelSkillFromHttps.live_url()
  def from, do: :https

  def look_404, do: "error  skill=add_mazel  from=https  reason=404"
  def look_non_https, do: "error  skill=add_mazel  from=file  reason=non_https"
  def look_clear, do: "ok  clear_error=yes  mix_user_lane=no"
  def look_sibling, do: "ok  sibling=from_path  green"

  def look(_ \\ %{}) do
    [look_404(), look_non_https(), look_clear(), look_sibling()]
  end

  @doc """
  Loopback 404 + file:// deny. Path sibling still green.
  Isolated. No invented live host.
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
              "mazel-install-add-mazel-skill-bad-url-#{System.unique_integer([:positive])}"
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
           {:error, :bad_scheme} <- Room.InstallAddMazelSkillFromHttps.fetch("ftp://example.com/x"),
           {:ok, sibling} <- Room.InstallAddMazelSkillFromUrl.demo(root: root) do
        cond do
          live_url() != nil ->
            {:error, :live_claimed}

          sibling.lines != path_sibling_look(sibling) ->
            {:error, :sibling_drift}

          sibling.from != :path ->
            {:error, :sibling_miss}

          sibling.mix_user_lane != :no ->
            {:error, :mix_lane}

          look_404() != "error  skill=add_mazel  from=https  reason=404" ->
            {:error, :look_miss}

          look_non_https() != "error  skill=add_mazel  from=file  reason=non_https" ->
            {:error, :look_miss}

          true ->
            pack = %{
              from: from(),
              url: url,
              file_url: @file_url,
              not_found: :not_found,
              non_https: :non_https,
              mix_user_lane: :no,
              live_url: live_url(),
              sibling: sibling
            }

            {:ok, Map.put(pack, :lines, look(pack))}
        end
      end
    after
      Process.exit(pid, :normal)
    end
  end

  defp path_sibling_look(sib) do
    [
      "ok  skill=add_mazel  from=path",
      "ok  install=friend_handable  mix_user_lane=no",
      "ok  steps=add→paste→find→direct",
      "ok  add=mazel  paste=ready",
      "ok  find=series-a→kai@mazel  mazel'd @kai",
      "ok  direct=@kai  session=ready"
    ]
    |> then(fn expected ->
      if sib.hit.handle == "kai@mazel", do: expected, else: :miss
    end)
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
