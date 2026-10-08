defmodule Room.Jit do
  @moduledoc """
  JIT match slice. Hard Need TTL is a gate. Soft Has age is `fresh`.

  Expired Need → unfit, out of the pool. Stale Has still paths with
  `fresh=0`. Deterministic Factor inputs only. No chat ranking.
  """

  def look(%{unfit: true, need_ttl: ttl}) when ttl in [:expired, "expired"] do
    "error  need_ttl=expired  unfit=true"
  end

  def look(%{fresh: 0, still_paths: true} = rec) do
    peer = rec[:handle] || rec[:peer]
    named = rec[:inputs] || rec[:factors] || %{}

    "ok  need×has  peer=#{peer}  inputs=#{Room.Factors.format_inputs(named)}  score=#{fmt(rec[:score] || 0)}  age=stale  still_paths=true"
  end

  def look(rec) when is_map(rec) do
    peer = rec[:handle] || rec[:peer]
    named = rec[:inputs] || rec[:factors] || %{}
    ttl = rec[:need_ttl] || rec[:freshness] || "fresh"

    "ok  need×has  peer=#{peer}  inputs=#{Room.Factors.format_inputs(named)}  score=#{fmt(rec[:score] || 0)}  need_ttl=#{ttl}"
  end

  def look(_), do: "error  need_ttl=expired  unfit=true"

  @doc """
  Fresh Need + vouched fresh Has → score=2.
  Same Need + stale Has → fresh=0, still paths.
  Expired Need → unfit. Isolated tmp.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-jit-#{System.unique_integer([:positive])}")
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

    with {:ok, need} <- Room.Need.seed("founders-investors", root: root, now: now),
         {:ok, _} <-
           Room.Has.seed_resume(Room.Has.align_rel(), handle: "kai@mazel", root: root, github: false),
         {:ok, _} <- Room.Has.vouch("ariel@mazel", "kai@mazel", root: root) do
      stamp_as_of!(dest, Date.to_iso8601(DateTime.to_date(now)))

      {:ok, hot} = beat(need, root, now)

      stale_on = Date.add(DateTime.to_date(now), -Room.Age.demo_stale_days()) |> Date.to_iso8601()
      stamp_as_of!(dest, stale_on)
      {:ok, stale} = beat(need, root, now)

      dead = Map.put(need, :expires_at, "2026-09-11T00:00:00Z")
      {:ok, expired} = Room.Need.match_has(dead, root: root, now: now)

      cond do
        not hot.ok or hot.score != 2 or hot.fresh != 1 ->
          {:error, :fresh_miss}

        not stale.ok or stale.fresh != 0 or stale.still_paths != true ->
          {:error, :stale_dropped}

        expired.ok or not expired.unfit or expired.need_ttl != :expired ->
          {:error, :expired_matched}

        true ->
          lines = [look(Map.put(hot, :need_ttl, :fresh)), look(stale), look(expired)]
          {:ok, %{hot: hot, stale: stale, expired: expired, lines: lines}}
      end
    end
  end

  defp beat(need, root, now) do
    case Room.Need.match_has(need, root: root, now: now) do
      {:ok, match} ->
        scored = Room.Score.decorate(match, root: root, now: now, need: need)
        if scored.ok, do: {:ok, scored}, else: {:error, :no_has}

      other ->
        other
    end
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
