defmodule Room.Age do
  @moduledoc """
  Evidence-age honesty on match paths.

  Age of Has *proof* (`as_of` on the Has slice), not Need TTL and
  not Open TTL. Stale evidence still paths; the LOOK just says so.
  """

  @stale_after_days 14
  @now ~U[2026-09-11 12:00:00Z]
  @stale_days 40

  def stale_after_days, do: @stale_after_days
  def demo_now, do: @now
  def demo_stale_days, do: @stale_days

  @doc """
  Read proof age for a handle. Returns ids: `fresh` | `stale`.
  Always `still_paths: true`.
  """
  def of(handle, opts \\ [])

  def of(handle, opts) when is_binary(handle) do
    root = Keyword.get(opts, :root) || Room.Index.repo_root()
    now = Keyword.get(opts, :now) || DateTime.utc_now()
    as_of = slice_as_of(handle, root)
    days = age_days(as_of, now)
    label = if days > @stale_after_days, do: "stale", else: "fresh"

    has = proof_ids(handle, root, opts)

    %{
      handle: normalize(handle),
      as_of: as_of,
      evidence_age: days,
      evidence_age_id: "#{days}d",
      label: label,
      has: has,
      still_paths: true
    }
  end

  def of(_, _),
    do: %{
      handle: nil,
      evidence_age: 0,
      evidence_age_id: "0d",
      label: "fresh",
      has: [],
      still_paths: true
    }

  @doc "Attach evidence-age fields to a Need×Has match. Does not drop."
  def decorate(match, opts \\ []) when is_map(match) do
    handle = match[:handle]

    if match[:ok] && is_binary(handle) do
      age = of(handle, Keyword.put_new(opts, :overlap, List.wrap(match[:overlap])))

      match
      |> Map.put(:evidence_age, age.evidence_age_id)
      |> Map.put(:evidence_label, age.label)
      |> Map.put(:has, age.has)
      |> Map.put(:still_paths, true)
    else
      match
    end
  end

  def look(rec) when is_map(rec) do
    handle = rec[:handle] || rec[:peer]
    label = rec[:evidence_label] || rec[:label] || "fresh"
    has = rec[:has] || rec[:overlap] || []
    listed = has |> List.wrap() |> Enum.join(",")
    "ok  need×has  peer=#{handle}  age=#{label}  has=[#{listed}]"
  end

  def look(_), do: "ok  need×has  peer=  age=fresh  has=[]"

  @doc """
  Fresh Has still matches. Stale Has still matches, labeled.
  Isolated to tmp. Does not rewrite committed Has or Need TTL.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-age-#{System.unique_integer([:positive])}")
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
    now = @now
    src = Path.join(Room.Index.repo_root(), "index/has/kai.md")
    dest = Path.join(root, "index/has/kai.md")
    File.mkdir_p!(Path.dirname(dest))
    File.cp!(src, dest)
    stamp_as_of!(dest, Date.to_iso8601(DateTime.to_date(now)))

    with {:ok, need} <- Room.Need.seed("founders-investors", root: root, now: now),
         {:ok, fresh_raw} <- Room.Need.match_has(need, root: root, now: now) do
      fresh = decorate(fresh_raw, root: root, now: now)

      stale_on = Date.add(DateTime.to_date(now), -@stale_days) |> Date.to_iso8601()
      stamp_as_of!(dest, stale_on)

      {:ok, stale_raw} = Room.Need.match_has(need, root: root, now: now)
      stale = decorate(stale_raw, root: root, now: now)

      cond do
        not fresh.ok or fresh.handle != "kai@mazel" or fresh.evidence_label != "fresh" ->
          {:error, :fresh_not_labeled}

        not stale.ok or stale.handle != "kai@mazel" or stale.evidence_label != "stale" ->
          {:error, :stale_dropped}

        stale.still_paths != true ->
          {:error, :stale_dropped}

        true ->
          lines = [look(fresh), look(stale)]
          {:ok, %{need: need, fresh: fresh, stale: stale, lines: lines}}
      end
    end
  end

  defp proof_ids(handle, root, opts) do
    overlap = Keyword.get(opts, :overlap) || []

    cond do
      overlap != [] ->
        List.wrap(overlap)

      true ->
        Room.Has.skills_for(handle, root: root)
    end
  end

  defp slice_as_of(handle, root) do
    local = handle |> to_string() |> String.trim_leading("@") |> String.split("@") |> hd()
    path = Path.join(Room.Index.dir(root, "has"), local <> ".md")

    if File.regular?(path) do
      case Regex.run(~r/^as_of:\s*(\S+)/m, File.read!(path)) do
        [_, iso] -> iso
        _ -> nil
      end
    end
  end

  defp age_days(nil, _), do: 0

  defp age_days(as_of, now) when is_binary(as_of) do
    today =
      case now do
        %DateTime{} -> DateTime.to_date(now)
        %Date{} -> now
        iso when is_binary(iso) ->
          case Date.from_iso8601(iso) do
            {:ok, d} -> d
            _ -> Date.utc_today()
          end
      end

    case Date.from_iso8601(as_of) do
      {:ok, then} -> max(Date.diff(today, then), 0)
      _ -> 0
    end
  end

  defp stamp_as_of!(path, iso) do
    text = File.read!(path)
    updated = Regex.replace(~r/^as_of:\s*\S+/m, text, "as_of: #{iso}")
    File.write!(path, updated)
  end

  defp normalize(raw) do
    case Room.Cards.lookup(to_string(raw)) do
      {:ok, found} -> found.id
      _ ->
        trimmed = raw |> to_string() |> String.trim() |> String.trim_leading("@")
        if String.contains?(trimmed, "@"), do: trimmed, else: trimmed <> "@mazel"
    end
  end
end
