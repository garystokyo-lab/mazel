defmodule Room.Harp do
  @moduledoc """
  Daily has+needs export. Harp-feel plain markdown for the
  prompt path — magic, not bureaucracy. Not Obsidian.

  Agent emit splits `{has, needs, curious}`.
  evidence → Has (proof only). Clear hunt → Needs.
  Claim / vibe / wildcard → Curious and never match.
  """

  @feel "harp"
  @proof_order ~w(series-a cto impl enterprise)

  def feel, do: @feel

  @doc "ADHD count line. `export=harp` is the feel id."
  def look(pack) when is_map(pack) do
    "ok  export=harp  has=#{count(pack.has)}  needs=#{count(pack.needs)}  curious=#{count(pack.curious)}"
  end

  def look(_), do: "ok  export=harp  has=0  needs=0  curious=0"

  @doc "Plain markdown. Sections only — no vault, no wikilinks."
  def markdown(pack) when is_map(pack) do
    [
      "## Has",
      bullets(pack.has),
      "",
      "## Needs",
      bullets(pack.needs),
      "",
      "## Curious",
      bullets(pack.curious)
    ]
    |> List.flatten()
    |> Enum.join("\n")
  end

  def lines(pack) when is_map(pack) do
    [look(pack), ""] ++ String.split(markdown(pack), "\n")
  end

  @doc """
  Bucket agent-emitted lines. Classify only — does not rank.
  """
  def bucket(items) when is_list(items) do
    grouped = Enum.group_by(items, &Room.Need.classify/1)

    %{
      has: Enum.map(grouped[:has] || [], &proof_label/1),
      needs: Enum.map(grouped[:need] || [], &need_label/1),
      curious: Enum.map(grouped[:curious] || [], &curious_label/1)
    }
  end

  @doc """
  Isolated daily export. Copies proof Has, seeds Needs, writes
  claim+vibe Curious. Curious is not matchable.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-harp-#{System.unique_integer([:positive])}")
          File.mkdir_p!(Path.join(path, "index/has"))
          File.mkdir_p!(Path.join(path, "index/needs"))
          File.mkdir_p!(Path.join(path, "index/curious"))
          {path, true}
      end

    try do
      demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp demo_on(root) do
    now = ~U[2026-09-11 12:00:00Z]
    src = Room.Index.repo_root()

    Enum.each(["kai.md", "nova.md"], fn name ->
      File.cp!(Path.join(src, Path.join("index/has", name)), Path.join(root, Path.join("index/has", name)))
    end)

    with {:ok, investors} <- Room.Need.Shape.cast(:founder_investors),
         {:ok, icp} <- Room.Need.Shape.cast(:icp_pain),
         {:ok, pkg} <- Room.Need.Shape.cast(:package_n, %{n: 3, package: "x"}) do
      needs = [
        Room.OpenNeed.stamp(investors, now: now),
        Room.OpenNeed.stamp(icp, now: now),
        Room.OpenNeed.expire(Room.OpenNeed.stamp(pkg, now: now), now: now)
      ]

      curious_rows = [
        write_curious(root, %{
          id: "linkedin-boast",
          kind: "curious",
          status: "curious",
          topic: "series-a",
          wants: ["series-a"],
          ask: "claim: I am a passionate visionary thought leader.",
          body: "claim: I am a passionate visionary thought leader."
        }),
        write_curious(root, %{
          id: "vibe-energy",
          kind: "curious",
          status: "curious",
          topic: "series-a",
          wants: ["series-a"],
          ask: "vibe: passionate visionary energy",
          body: "vibe: passionate visionary energy"
        })
      ]

      pack = %{
        has: proofs_from(root),
        needs: Enum.map(needs, &need_label/1),
        curious: Enum.map(curious_rows, &curious_label/1)
      }

      if leak?(pack) do
        {:error, :curious_in_has}
      else
        case refuse_curious(curious_rows, root) do
          :ok ->
            {:ok,
             %{
               pack: pack,
               markdown: markdown(pack),
               lines: lines(pack),
               curious_rows: curious_rows
             }}

          {:error, _} = err ->
            err
        end
      end
    end
  end

  defp refuse_curious(rows, root) do
    Enum.reduce_while(rows, :ok, fn row, :ok ->
      case Room.Need.match_has(row, root: root) do
        {:ok, %{ok: false, unfit: true}} -> {:cont, :ok}
        {:ok, %{ok: false, error: "curious"}} -> {:cont, :ok}
        {:ok, %{ok: true}} -> {:halt, {:error, :curious_matched}}
        other -> {:halt, {:error, {:curious_match, other}}}
      end
    end)
  end

  defp proofs_from(root) do
    root
    |> Room.Index.load("has")
    |> Enum.filter(fn rec ->
      Room.Need.classify(%{kind: rec[:kind], status: rec[:status]}) == :has
    end)
    |> Enum.flat_map(&proof_ids/1)
    |> Enum.uniq()
    |> Enum.sort_by(&proof_order/1)
  end

  defp proof_ids(rec) do
    body = rec[:body] || ""

    case Regex.run(~r/^proof:\s*(.+)$/m, body) do
      [_, csv] ->
        csv
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      _ ->
        []
    end
  end

  defp proof_order(id) do
    case Enum.find_index(@proof_order, &(&1 == id)) do
      nil -> {1, id}
      idx -> {0, idx}
    end
  end

  defp proof_label(item) do
    text = text_of(item)

    case Regex.run(~r/(?:proof|has):\s*(.+)$/i, text) do
      [_, rest] ->
        rest
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.join(", ")

      _ ->
        text
    end
  end

  @doc "Need export line. Shape + hard TTL when the Need was preset-cast."
  def need_label(item) when is_map(item) do
    if item[:shape] || item[:ttl] || item[:need_ttl] || item[:expires_at] do
      shape = item[:shape] || item[:id] || item[:need_id]
      ttl = item[:ttl] || :hard
      freshness = item[:need_ttl] || Room.Need.freshness(item)
      "shape=#{shape}  ttl=#{ttl}  need_ttl=#{freshness}"
    else
      to_string(item[:id] || item[:shape] || text_of(item))
    end
  end

  def need_label(item), do: text_of(item)

  defp curious_label(item) when is_map(item) do
    text_of(item[:body] || item[:ask] || item[:id] || "curious")
  end

  defp curious_label(item), do: text_of(item)

  defp text_of(item) when is_binary(item), do: String.trim(item)
  defp text_of(item) when is_map(item), do: String.trim(to_string(item[:ask] || item[:body] || item[:id] || ""))
  defp text_of(_), do: ""

  defp bullets([]), do: ["-"]
  defp bullets(items), do: Enum.map(items, &"- #{&1}")

  defp count(list) when is_list(list), do: length(list)
  defp count(_), do: 0

  defp leak?(pack) do
    has = MapSet.new(List.wrap(pack.has))
    needs = MapSet.new(List.wrap(pack.needs))

    Enum.any?(List.wrap(pack.curious), fn row ->
      MapSet.member?(has, row) or MapSet.member?(needs, row)
    end)
  end

  defp write_curious(root, item) do
    folder = Room.Index.dir(root, "curious")
    File.mkdir_p!(folder)
    path = Path.join(folder, item.id <> ".md")

    File.write!(path, """
    ---
    id: #{item.id}
    kind: curious
    status: curious
    topic: #{item.topic}
    ---

    # Curious #{item.id}

    #{item.body}
    """)

    Map.put(item, :path, path)
  end
end
