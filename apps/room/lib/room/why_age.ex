defmodule Room.WhyAge do
  @moduledoc """
  Why strip labels Has evidence age and Need TTL honestly.

  Soft decay: stale Has still paths, labeled. Expired Need is unfit.
  Does not rewrite age / why / jit / agent_complete LOOK.
  """

  def look_fresh(rec) when is_map(rec) do
    peer = rec[:handle] || rec[:peer] || "kai@mazel"
    "ok  need×has  peer=#{peer}  score=#{fmt(rec[:score] || 0)}"
  end

  def look_fresh(_), do: "ok  need×has  peer=kai@mazel  score=0"

  def look_why_fresh(rec) when is_map(rec) do
    [
      "why  need=#{rec[:why_need] || "series-a"}  need_ttl=fresh",
      "why  has=#{rec[:why_has] || "series-a"}  age=fresh"
    ]
  end

  def look_stale(rec) when is_map(rec) do
    peer = rec[:handle] || rec[:peer] || "kai@mazel"
    "ok  need×has  peer=#{peer}  age=stale  still_paths=true"
  end

  def look_stale(_), do: "ok  need×has  peer=kai@mazel  age=stale  still_paths=true"

  def look_why_stale(rec) when is_map(rec) do
    "why  has=#{rec[:why_has] || "series-a"}  age=stale"
  end

  def look_expired, do: Room.Jit.look(%{unfit: true, need_ttl: :expired})

  def look(pack) when is_map(pack) do
    [look_fresh(pack.fresh)] ++
      look_why_fresh(pack.fresh) ++
      [look_stale(pack.stale), look_why_stale(pack.stale), look_expired()]
  end

  def look(_) do
    look(%{
      fresh: %{handle: "kai@mazel", score: 0, why_need: "series-a", why_has: "series-a"},
      stale: %{handle: "kai@mazel", why_has: "series-a"}
    })
  end

  @doc """
  Fresh match: why carries need_ttl + Has age.
  Stale Has still paths, labeled on why. Expired Need unfit.
  Isolated. Does not rewrite why_demo / age_demo / jit_demo.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-why-age-#{System.unique_integer([:positive])}")
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
    dest = Path.join(root, "index/has/kai.md")
    File.cp!(Path.join(Room.Index.repo_root(), "index/has/kai.md"), dest)
    stamp_as_of!(dest, Date.to_iso8601(DateTime.to_date(now)))

    with {:ok, need} <- Room.Need.seed("founders-investors", root: root, now: now),
         {:ok, fresh_raw} <- Room.Need.match_has(need, root: root, now: now) do
      fresh = decorate(fresh_raw, need, root, now)

      stale_on = Date.add(DateTime.to_date(now), -Room.Age.demo_stale_days()) |> Date.to_iso8601()
      stamp_as_of!(dest, stale_on)
      {:ok, stale_raw} = Room.Need.match_has(need, root: root, now: now)
      stale = decorate(stale_raw, need, root, now)

      dead = Map.put(need, :expires_at, "2026-09-11T00:00:00Z")
      {:ok, expired} = Room.Need.match_has(dead, root: root, now: now)

      cond do
        not fresh.ok or fresh.handle != "kai@mazel" or fresh.evidence_label != "fresh" or
            fresh.need_ttl != :fresh ->
          {:error, :fresh_miss}

        fresh.why_need != "series-a" or fresh.why_has != "series-a" ->
          {:error, :why_miss}

        not stale.ok or stale.evidence_label != "stale" or stale.still_paths != true or
            stale.need_ttl != :fresh ->
          {:error, :stale_dropped}

        expired.ok or not expired.unfit or expired.need_ttl != :expired ->
          {:error, :expired_matched}

        true ->
          pack = %{fresh: fresh, stale: stale, expired: expired}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp decorate(match, need, root, now) do
    match
    |> Room.Age.decorate(root: root, now: now)
    |> Room.Score.decorate(root: root, now: now, need: need)
    |> Map.merge(Room.Score.why_fields(need, match))
    |> Map.put(:need_ttl, match[:freshness] || :fresh)
  end

  defp stamp_as_of!(path, iso) do
    text = File.read!(path)
    File.write!(path, Regex.replace(~r/^as_of:\s*\S+/m, text, "as_of: #{iso}"))
  end

  defp fmt(n) when is_float(n) do
    if n == Float.floor(n), do: trunc(n), else: :erlang.float_to_binary(n, decimals: 2)
  end

  defp fmt(n) when is_integer(n), do: n
  defp fmt(_), do: 0
end
