defmodule Room.InstallAddMazelSkillFromHttps do
  @moduledoc """
  Fetch Add Mazel skill over http(s). No public host yet.

  Live https is none (mazel.ai is marketing; GitHub raw
  404s). Closer proof: fetch() + local url_fixture.
  Distinct from install_add_mazel_skill_from_url
  (from=path), install_add_mazel_skill (in-repo skill),
  and install_add_mazel_skill_readd (idempotent re-add).
  Off Group / Trust / proof-Has / invented live host.
  """

  @hand_rel "docs/ADD_MAZEL_SKILL.md"
  @pack_rel "docs/ADD_MAZEL.md"
  @from :url_fixture
  @skill_path "/ADD_MAZEL_SKILL.md"

  def hand_rel, do: @hand_rel
  def pack_rel, do: @pack_rel
  def from, do: @from
  def live_url, do: nil

  def look_from, do: "ok  skill=add_mazel  from=url_fixture"
  def look_blocked, do: "error  live_https=none"
  def look_install, do: Room.InstallAddMazelSkillFromUrl.look_install()
  def look_steps, do: Room.InstallAddMazelPack.look_steps()
  def look_add_paste, do: Room.InstallAddMazelPack.look_add_paste()
  def look_find(rec \\ %{}), do: Room.InstallAddMazelPack.look_find(rec)
  def look_direct, do: Room.InstallAddMazelPack.look_direct()

  def look(pack) when is_map(pack) do
    [
      look_from(),
      look_blocked(),
      look_install(),
      look_steps(),
      look_add_paste(),
      look_find(pack.hit),
      look_direct()
    ]
  end

  def look(_), do: look(%{hit: %{}})

  def hand_path, do: Path.join(Room.Index.repo_root(), @hand_rel)
  def pack_path, do: Path.join(Room.Index.repo_root(), @pack_rel)

  @doc "GET http(s) only. file:// / ftp / empty miss."
  def fetch(url) when is_binary(url) do
    uri = URI.parse(String.trim(url))

    cond do
      uri.scheme not in ["http", "https"] ->
        {:error, :bad_scheme}

      uri.host in [nil, ""] ->
        {:error, :bad_scheme}

      true ->
        http_get(url)
    end
  end

  def fetch(_), do: {:error, :bad_scheme}

  @doc """
  Serve skill md on loopback http, fetch it, then Add→paste→find.
  Isolated. Sibling from_url / skill / readd LOOK stays.
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
              "mazel-install-add-mazel-skill-from-https-#{System.unique_integer([:positive])}"
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
    text = File.read!(hand_path())
    pack_text = File.read!(pack_path())
    url = "http://127.0.0.1:#{port}#{@skill_path}"

    {:ok, pid} = start_fixture!(port, text)

    try do
      with {:ok, fetched} <- fetch_wait(url),
           {:error, :bad_scheme} <- fetch("file://#{hand_path()}"),
           {:ok, found} <- Room.InstallAddPasteFind.demo(root: root) do
        cond do
          live_url() != nil ->
            {:error, :live_claimed}

          from() != :url_fixture ->
            {:error, :from_miss}

          fetched != text ->
            {:error, :fetch_miss}

          not String.starts_with?(fetched, "# Add Mazel skill") ->
            {:error, :hand_miss}

          String.contains?(fetched, "mix ") ->
            {:error, :mix_internals}

          not String.contains?(fetched, "Hand a friend this path") ->
            {:error, :hand_miss}

          not String.contains?(fetched, ".cursor/skills/add-mazel/SKILL.md") ->
            {:error, :install_miss}

          not String.contains?(fetched, "Session owns Direct") ->
            {:error, :pointer_miss}

          not String.starts_with?(pack_text, "# Add Mazel") ->
            {:error, :pack_miss}

          found.hit.handle != "kai@mazel" ->
            {:error, :find_miss}

          look_from() != "ok  skill=add_mazel  from=url_fixture" ->
            {:error, :from_miss}

          look_blocked() != "error  live_https=none" ->
            {:error, :live_claimed}

          true ->
            skill =
              Map.merge(found, %{
                skill: @hand_rel,
                wrap: @pack_rel,
                from: from(),
                url: url,
                fetched: fetched,
                mix_user_lane: :no,
                live_url: live_url(),
                text: fetched
              })

            {:ok, Map.put(skill, :lines, look(skill))}
        end
      end
    after
      Process.exit(pid, :normal)
    end
  end

  defp fetch_wait(url, tries \\ 8) do
    case fetch(url) do
      {:ok, body} ->
        {:ok, body}

      {:error, _} when tries > 1 ->
        Process.sleep(25)
        fetch_wait(url, tries - 1)

      error ->
        error
    end
  end

  defp start_fixture!(port, body) do
    Bandit.start_link(
      plug: {Room.InstallAddMazelSkillFromHttps.Fixture, [body: body, path: @skill_path]},
      scheme: :http,
      port: port,
      thousand_island_options: [transport_options: [ip: {127, 0, 0, 1}]]
    )
  end

  defp http_get(url) do
    args = ["-fsS", "--max-time", "5", "--connect-timeout", "3", "-A", "mazel-install/0.1", url]

    case System.cmd("curl", args, stderr_to_stdout: true) do
      {body, 0} when is_binary(body) ->
        {:ok, body}

      {out, _} ->
        text = to_string(out)

        if String.contains?(text, "404") do
          {:error, :not_found}
        else
          {:error, {:curl, out}}
        end
    end
  end
end

defmodule Room.InstallAddMazelSkillFromHttps.Fixture do
  @moduledoc false
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, opts) do
    body = Keyword.fetch!(opts, :body)
    path = Keyword.fetch!(opts, :path)

    if conn.request_path == path do
      conn
      |> put_resp_content_type("text/markdown")
      |> send_resp(200, body)
    else
      send_resp(conn, 404, "none")
    end
  end
end
