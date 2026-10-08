defmodule Room.GmailHeat do
  @moduledoc """
  Optional Gmail edge-heat prior.

  Recency / frequency / depth fill the existing **heat** factor.
  Bodies are redacted. Not a core dependency. Not BM25. Not Has.
  LinkedIn stays curious-only. Fixture only — no live Gmail.
  """

  @as_of ~D[2026-09-11]
  @fresh_days 14
  @rel "priv/fixtures/kai.gmail.json"
  @secrets ~w(body snippet text subject html)

  def fixture_rel, do: @rel
  def as_of, do: @as_of
  def secret_keys, do: @secrets

  def load(raw, opts \\ []) when is_binary(raw) do
    root = Keyword.get(opts, :root) || Room.Index.repo_root()

    case resolve(raw, root) do
      {:ok, path} ->
        case File.read(path) do
          {:ok, bytes} -> decode(bytes)
          {:error, _} -> {:error, :no_connector}
        end

      {:error, _} ->
        {:error, :no_connector}
    end
  end

  def decode(bytes) when is_binary(bytes) do
    case Jason.decode(bytes) do
      {:ok, map} when is_map(map) -> {:ok, map}
      _ -> {:error, :bad_fixture}
    end
  end

  def redact(thread) when is_map(thread) do
    Enum.reduce(@secrets, thread, fn key, acc ->
      Map.drop(acc, [key, String.to_atom(key)])
    end)
  end

  def redact(_), do: %{}

  def edges(pack) when is_map(pack) do
    threads = List.wrap(pack["threads"] || pack[:threads])
    as_of = parse_date(pack["as_of"] || pack[:as_of]) || @as_of
    redacted = Enum.map(threads, &redact/1)
    dates = Enum.map(redacted, &parse_date(&1["date"] || &1[:date])) |> Enum.reject(&is_nil/1)
    depths = Enum.map(redacted, &depth_of/1)
    newest = Enum.max(dates, Date, fn -> nil end)
    recency = if fresh?(newest, as_of), do: "fresh", else: "stale"
    freq = length(redacted)
    depth = Enum.max(depths, fn -> 0 end)
    heat = if recency == "fresh" and freq >= 2 and depth >= 3, do: 1, else: 0

    %{
      recency: recency,
      freq: freq,
      depth: depth,
      heat: heat,
      redacted: true,
      threads: redacted
    }
  end

  def edges(_), do: %{recency: "stale", freq: 0, depth: 0, heat: 0, redacted: true, threads: []}

  def inputs(%{heat: heat}) do
    %{
      fit: 1,
      heat: heat,
      fresh: 1,
      trail: 0,
      check: 0
    }
  end

  def look_edge(edges) when is_map(edges) do
    "ok  gmail=edge  recency=#{edges.recency}  freq=#{edges.freq}  depth=#{edges.depth}  heat=#{edges.heat}"
  end

  def look_inputs(scored) when is_map(scored) do
    named = scored[:inputs] || scored[:factors] || %{}
    "ok  inputs=#{Room.Factors.format_inputs(named)}  prior=gmail"
  end

  def look_match(scored) when is_map(scored) do
    "ok  need×has  peer=kai@mazel  score=#{scored[:score] || 0}"
  end

  def look_none, do: "ok  no_connector  heat=0  redacted=true"

  def look(pack) when is_map(pack) do
    [look_edge(pack.edges), look_inputs(pack.score), look_match(pack.score), look_none()]
  end

  @doc """
  Fixture edges lift heat. Missing connector stays heat=0.
  Isolated. Bodies never print.
  """
  def demo(opts \\ []) do
    root = Keyword.get(opts, :root) || Room.Index.repo_root()

    with {:ok, pack} <- load(@rel, root: root) do
      edges = edges(pack)
      scored = Room.Factors.score(inputs(edges))
      none = case load("priv/fixtures/missing.gmail.json", root: root) do
        {:error, :no_connector} -> %{heat: 0, redacted: true}
        {:ok, empty} -> edges(empty)
      end

      cond do
        edges.heat != 1 or edges.redacted != true ->
          {:error, :no_heat}

        scored.unfit or scored.score != 2 or scored.inputs.heat != 1 ->
          {:error, :score_miss}

        none.heat != 0 ->
          {:error, :connector_required}

        leaked?(look(%{edges: edges, score: scored}), pack) ->
          {:error, :body_leaked}

        true ->
          out = %{edges: edges, score: scored, none: none}
          {:ok, Map.put(out, :lines, look(out))}
      end
    end
  end

  defp leaked?(lines, pack) do
    hay = Enum.join(lines, "\n")
    secrets =
      List.wrap(pack["threads"] || pack[:threads])
      |> Enum.flat_map(fn t ->
        Enum.map(@secrets, &to_string(t[&1] || t[String.to_atom(&1)] || ""))
      end)
      |> Enum.reject(&(&1 == ""))

    Enum.any?(secrets, &String.contains?(hay, &1))
  end

  defp fresh?(nil, _), do: false

  defp fresh?(date, as_of) do
    Date.diff(as_of, date) <= @fresh_days and Date.diff(as_of, date) >= 0
  end

  defp parse_date(nil), do: nil

  defp parse_date(%Date{} = date), do: date

  defp parse_date(raw) when is_binary(raw) do
    case Date.from_iso8601(String.trim(raw)) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_date(_), do: nil

  defp depth_of(thread) do
    case thread["depth"] || thread[:depth] do
      n when is_integer(n) and n >= 0 -> n
      n when is_binary(n) ->
        case Integer.parse(n) do
          {i, _} -> i
          _ -> 0
        end

      _ ->
        0
    end
  end

  defp resolve(raw, root) do
    cond do
      File.regular?(raw) -> {:ok, raw}
      File.regular?(Path.join(root, raw)) -> {:ok, Path.join(root, raw)}
      File.regular?(Path.join(Room.Index.repo_root(), raw)) ->
        {:ok, Path.join(Room.Index.repo_root(), raw)}

      true ->
        {:error, :no_connector}
    end
  end
end
