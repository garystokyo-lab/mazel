defmodule Room.Index do
  @moduledoc """
  Dated markdown slices under `index/{knows,needs,opens,has}`.

  JIT rank: `topic_score - evidence_freshness_penalty`.
  Live `open` / `need` rows also honor hard TTL.
  """

  @kinds %{
    "know" => "knows",
    "need" => "needs",
    "open" => "opens",
    "has" => "has",
    "curious" => "curious",
    "candidate" => "candidate"
  }

  def repo_root do
    cwd = File.cwd!()

    cond do
      File.dir?(Path.join(cwd, "index/knows")) -> cwd
      File.dir?(Path.join(cwd, "../../index/knows")) -> Path.expand("../../", cwd)
      true -> Path.expand("../../..", Path.dirname(__DIR__))
    end
  end

  def fixtures_root, do: Path.join(repo_root(), "fixtures")

  def get(root, kind, id) do
    Enum.find(load(root, kind), fn row -> (row[:id] || row["id"]) == id end)
  end

  def dir(root, kind) do
    folder = Map.get(@kinds, kind_string(kind), kind_string(kind))
    Path.join([root, "index", folder])
  end

  def load(root, kind) do
    path = dir(root, kind)

    if File.dir?(path) do
      path
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".md"))
      |> Enum.map(&parse_slice(Path.join(path, &1)))
      |> Enum.reject(&is_nil/1)
    else
      []
    end
  end

  def write(root, slice) when is_map(slice) do
    kind = slice[:kind] || slice["kind"] || "need"
    folder = dir(root, kind)
    File.mkdir_p!(folder)
    path = Path.join(folder, "#{slice[:as_of] || slice["as_of"]}-#{slice[:id] || slice["id"]}.md")
    File.write!(path, markdown(slice))
    path
  end

  def parse_slice(path) do
    raw = File.read!(path)

    case String.split(raw, ~r/\n---\n/, parts: 2) do
      [front, body] ->
        meta =
          front
          |> String.replace_leading("---\n", "")
          |> String.split("\n")
          |> Enum.reduce(%{}, fn line, acc ->
            case String.split(line, ":", parts: 2) do
              [k, v] -> Map.put(acc, String.trim(k), String.trim(v))
              _ -> acc
            end
          end)

        ttl =
          case Integer.parse(meta["ttl_hours"] || "") do
            {n, _} -> n
            :error -> nil
          end

        %{
          id: meta["id"] || Path.basename(path, ".md"),
          kind: meta["kind"] || "know",
          topic: meta["topic"] || "",
          title: meta["title"] || meta["id"] || "",
          body: String.trim(body),
          as_of: meta["as_of"] || "",
          ttl_hours: ttl,
          expires_at: meta["expires_at"],
          handle: meta["handle"],
          sink: meta["sink"],
          source: meta["source"],
          status: meta["status"],
          strength: meta["strength"],
          provenance: meta["provenance"]
        }

      _ ->
        nil
    end
  end

  def expired?(slice, now) do
    case slice[:expires_at] || slice["expires_at"] do
      nil ->
        ttl = slice[:ttl_hours] || slice["ttl_hours"]
        as_of = slice[:as_of] || slice["as_of"]

        cond do
          is_nil(ttl) ->
            false

          is_binary(as_of) ->
            case Date.from_iso8601(as_of) do
              {:ok, date} -> Date.diff(DateTime.to_date(now), date) * 24 >= ttl
              _ -> false
            end

          true ->
            false
        end

      iso when is_binary(iso) ->
        case DateTime.from_iso8601(iso) do
          {:ok, expires, _} -> DateTime.compare(expires, now) != :gt
          _ -> false
        end
    end
  end

  def live(slices, now), do: Enum.reject(slices, &expired?(&1, now))

  def rank(query, candidates) do
    candidates
    |> Enum.map(&score(query, &1))
    |> Enum.filter(&(&1.score > 0.0))
    |> Enum.sort_by(&{-&1.score, -&1.topic_score})
  end

  def topic_from(text) do
    down = String.downcase(text)

    cond do
      String.contains?(down, "series-a") or String.contains?(down, "series a") or
          String.contains?(down, "cto") ->
        "series-a"

      String.contains?(down, "prague") ->
        "prague"

      String.contains?(down, "enterprise") ->
        "enterprise-ai"

      String.contains?(down, "agent") ->
        "ai-agents"

      true ->
        text
        |> String.downcase()
        |> String.replace(~r/[^a-z0-9]+/, "-")
        |> String.trim("-")
        |> String.slice(0, 32)
    end
  end

  def ttl_hours(value, default \\ 72) do
    cond do
      is_integer(value) and value > 0 ->
        value

      is_float(value) and value > 0 ->
        trunc(value)

      is_binary(value) ->
        case Integer.parse(String.trim(value)) do
          {n, _} when n > 0 -> n
          _ -> default
        end

      true ->
        default
    end
  end

  defp score(query, candidate) do
    topic = query[:topic] || query["topic"]
    topic_score = topic_score(topic, candidate)
    age = age_days(candidate[:as_of] || candidate["as_of"], query[:as_of] || query["as_of"])
    penalty = min(age / 365.0, 1.0) * 0.55

    %{
      id: candidate[:id] || candidate["id"],
      kind: candidate[:kind] || candidate["kind"] || "know",
      topic: candidate[:topic] || candidate["topic"],
      as_of: candidate[:as_of] || candidate["as_of"],
      handle: candidate[:handle] || candidate["handle"],
      topic_score: topic_score,
      evidence_freshness_penalty: penalty,
      score: topic_score - penalty
    }
  end

  defp topic_score(topic, candidate) do
    body = candidate[:body] || candidate["body"] || ""
    cand_topic = candidate[:topic] || candidate["topic"] || ""

    cond do
      cand_topic == topic -> 1.0
      is_binary(topic) and topic != "" and String.contains?(String.downcase(body), topic) -> 0.35
      true -> 0.0
    end
  end

  defp age_days(from, to) when is_binary(from) and is_binary(to) do
    with {:ok, a} <- Date.from_iso8601(from),
         {:ok, b} <- Date.from_iso8601(to) do
      abs(Date.diff(b, a))
    else
      _ -> 0
    end
  end

  defp age_days(_, _), do: 0

  defp markdown(slice) do
    id = slice[:id] || slice["id"]
    kind = kind_string(slice[:kind] || slice["kind"])
    topic = slice[:topic] || slice["topic"]
    as_of = slice[:as_of] || slice["as_of"]
    title = slice[:title] || slice["title"] || "#{kind} #{topic}"
    body = slice[:body] || slice["body"] || ""

    extras =
      [
        optional("ttl_hours", slice[:ttl_hours] || slice["ttl_hours"]),
        optional("expires_at", slice[:expires_at] || slice["expires_at"]),
        optional("sink", slice[:sink] || slice["sink"]),
        optional("handle", slice[:handle] || slice["handle"])
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join()

    """
    ---
    id: #{id}
    kind: #{kind}
    topic: #{topic}
    as_of: #{as_of}
    #{extras}---

    # #{title}

    #{body}
    """
  end

  defp optional(_key, nil), do: nil
  defp optional(_key, ""), do: nil
  defp optional(key, value), do: "#{key}: #{value}\n"

  defp kind_string(kind) when is_atom(kind), do: Atom.to_string(kind)
  defp kind_string(kind) when is_binary(kind), do: kind
end
