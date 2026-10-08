defmodule Room.McpRefresh do
  @moduledoc """
  Live MCP connector refresh. Trail stays Has; quiet is soft-decay.

  Live bump of `as_of` keeps `age=fresh`. Quiet trail is labeled
  `decay=soft` (not hard-delete). Claims never Has.
  Distinct from mcp_trail (static trail→quant).
  """

  def look_live(rec \\ %{}) do
    "ok  mcp=live  trail=#{rec[:trail] || 1}  age=fresh"
  end

  def look_quiet(rec \\ %{}) do
    "ok  mcp=quiet  trail=#{rec[:trail] || 1}  decay=soft  age=stale  still_paths=true"
  end

  def look_claim, do: "error  claim→curious  unfit=true"

  def look(pack) when is_map(pack) do
    [look_live(pack.live), look_quiet(pack.quiet), look_claim()]
  end

  def look(_), do: look(%{live: %{trail: 1}, quiet: %{trail: 1}})

  @doc """
  Re-read the MCP fixture and stamp proof `as_of` to now.
  Connector trail stays Has. Isolated writes only.
  """
  def refresh(handle, opts \\ []) do
    root = Keyword.get(opts, :root) || Room.Index.repo_root()
    now = Keyword.get(opts, :now) || Room.Age.demo_now()
    iso = iso_of(now)

    with {:ok, has} <-
           Room.Has.seed_mcp(Room.Has.github_rel(), handle: handle, root: root) do
      stamp_as_of!(has_path(handle, root), iso)
      age = Room.Age.of(handle, root: root, now: now)

      {:ok,
       Map.merge(has, %{
         trail: Room.Has.trail_for(handle, root: root),
         check: Room.Has.check_for(handle, root: root),
         age: age,
         decay: :none,
         still_paths: true
       })}
    end
  end

  @doc """
  Quiet connector: keep the Has file, label soft-decay.
  Does not hard-delete. Stale still paths.
  """
  def quiet(handle, opts \\ []) do
    root = Keyword.get(opts, :root) || Room.Index.repo_root()
    now = Keyword.get(opts, :now) || Room.Age.demo_now()
    days = Keyword.get(opts, :stale_days) || Room.Age.demo_stale_days()
    path = has_path(handle, root)

    if File.regular?(path) do
      then = Date.add(date_of(now), -days) |> Date.to_iso8601()
      stamp_as_of!(path, then)
      age = Room.Age.of(handle, root: root, now: now)

      {:ok,
       %{
         handle: age.handle,
         trail: Room.Has.trail_for(handle, root: root),
         check: Room.Has.check_for(handle, root: root),
         age: age,
         decay: :soft,
         still_paths: age.still_paths,
         kept: true,
         path: path
       }}
    else
      {:error, :has_miss}
    end
  end

  @doc """
  Live MCP refresh stays fresh. Quiet trail is soft-decay, still paths.
  Claim stays curious. Isolated. mcp_trail LOOK stays.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-mcp-refresh-#{System.unique_integer([:positive])}")
          File.mkdir_p!(Path.join(path, "index/has"))
          File.mkdir_p!(Path.join(path, "index/needs"))
          {path, true}
      end

    try do
      demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp demo_on(root) do
    now = Room.Age.demo_now()

    with {:ok, live} <- refresh("kai@mazel", root: root, now: now),
         {:ok, need} <- Room.Need.seed("founders-investors", root: root, now: now),
         {:ok, fresh_raw} <- Room.Need.match_has(need, root: root, now: now) do
      fresh = Room.Age.decorate(fresh_raw, root: root, now: now)

      {:ok, quiet} = quiet("kai@mazel", root: root, now: now)
      {:ok, quiet_raw} = Room.Need.match_has(need, root: root, now: now)
      stale = Room.Age.decorate(quiet_raw, root: root, now: now)

      claim = Room.Factors.score(%{fit: 1, heat: 1, fresh: 1, trail: 1, check: 1, claim: true})

      cond do
        live.status != "has" or live.source != "mcp" or live.trail != 1 ->
          {:error, :live_not_has}

        live.age.label != "fresh" ->
          {:error, :live_not_fresh}

        not fresh.ok or fresh.handle != "kai@mazel" or fresh.evidence_label != "fresh" ->
          {:error, :fresh_miss}

        quiet.decay != :soft or quiet.trail != 1 or not quiet.kept or not File.regular?(quiet.path) ->
          {:error, :hard_delete}

        not stale.ok or stale.evidence_label != "stale" or stale.still_paths != true ->
          {:error, :quiet_dropped}

        not claim.unfit ->
          {:error, :claim_fit}

        true ->
          pack = %{live: live, quiet: quiet, fresh: fresh, stale: stale, claim: claim}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp has_path(handle, root) do
    local = handle |> to_string() |> String.trim_leading("@") |> String.split("@") |> hd()
    Path.join(Room.Index.dir(root, "has"), local <> ".md")
  end

  defp stamp_as_of!(path, iso) do
    text = File.read!(path)
    updated = Regex.replace(~r/^as_of:\s*\S+/m, text, "as_of: #{iso}")
    File.write!(path, updated)
  end

  defp iso_of(%DateTime{} = dt), do: Date.to_iso8601(DateTime.to_date(dt))
  defp iso_of(%Date{} = d), do: Date.to_iso8601(d)
  defp iso_of(iso) when is_binary(iso), do: iso

  defp date_of(%DateTime{} = dt), do: DateTime.to_date(dt)
  defp date_of(%Date{} = d), do: d

  defp date_of(iso) when is_binary(iso) do
    case Date.from_iso8601(iso) do
      {:ok, d} -> d
      _ -> Date.utc_today()
    end
  end
end