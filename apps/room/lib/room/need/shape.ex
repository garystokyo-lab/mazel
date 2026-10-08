defmodule Room.Need.Shape do
  @moduledoc """
  Agent-emitted Need presets. Structured objects, not a human form.

  Ids are stable. Labels are a swappable table. Vibe / claim is
  not a shape — curious, never matches.
  """

  @presets %{
    founder_investors: %{
      id: :founder_investors,
      fields: [:who, :wants],
      defaults: %{who: "founders", wants: "series-a"},
      wants: ["series-a", "cto"],
      ttl_hours: 168
    },
    founder_customers: %{
      id: :founder_customers,
      fields: [:who, :wants],
      defaults: %{who: "founders", wants: "enterprise"},
      wants: ["enterprise", "impl"],
      ttl_hours: 168
    },
    icp_pain: %{
      id: :icp_pain,
      fields: [:icp, :pain],
      defaults: %{icp: "enterprise", pain: "impl"},
      wants: ["impl", "enterprise"],
      ttl_hours: 72
    },
    package_n: %{
      id: :package_n,
      fields: [:n, :package],
      defaults: %{n: 3, package: "x"},
      wants: ["impl"],
      ttl_hours: 48
    }
  }

  @labels %{
    founder_investors: "Founders seeking investors",
    founder_customers: "Founders seeking customers",
    icp_pain: "ICP pain the product cures",
    package_n: "N companies on package X"
  }

  def ids, do: @presets |> Map.keys() |> Enum.sort()
  def presets, do: @presets
  def labels, do: Process.get({__MODULE__, :labels}, @labels)
  def put_label(id, text), do: Process.put({__MODULE__, :labels}, Map.put(labels(), normalize(id), text))
  def reset_labels, do: Process.delete({__MODULE__, :labels})

  def label(id), do: Map.get(labels(), normalize(id))

  def get(id) do
    Map.get(@presets, normalize(id))
  end

  def preset?(id), do: Map.has_key?(@presets, normalize(id))

  @doc """
  Agent emit. Preset id + params → Need. Unknown / vibe / claim
  is curious and never a Need shape.
  """
  def cast(raw, params \\ %{}) do
    id = normalize(raw)
    params = stringify_keys(params)

    case Map.fetch(@presets, id) do
      {:ok, spec} ->
        {:ok, build(spec, params)}

      :error ->
        {:ok, curious(raw)}
    end
  end

  def look(%{unfit: true}), do: "error  vibe→curious  unfit=true"

  def look(%{ok: true, shape: shape, fields: fields}) do
    "ok  shape=#{shape}  need=#{shape}  fields=#{format_fields(shape, fields)}"
  end

  def look(_), do: "error  vibe→curious  unfit=true"

  def format_fields(shape, fields) when is_map(fields) do
    keys =
      case get(shape) do
        %{fields: order} -> order
        _ -> Map.keys(fields)
      end

    inner = Enum.map_join(keys, ",", fn k -> "#{k}:#{Map.get(fields, k)}" end)
    "{#{inner}}"
  end

  def format_fields(_, _), do: "{}"

  def format_fields(fields) when is_map(fields) do
    inner = Enum.map_join(fields, ",", fn {k, v} -> "#{k}:#{v}" end)
    "{#{inner}}"
  end

  def format_fields(_), do: "{}"

  @doc """
  Cast the four presets, one Need×Has beat, vibe refused.
  Isolated tmp. Does not rewrite committed Has.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-need-shape-#{System.unique_integer([:positive])}")
          File.mkdir_p!(Path.join(path, "index/has"))
          {path, true}
      end

    try do
      demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp demo_on(root) do
    dest = Path.join(root, "index/has/kai.md")
    File.cp!(Path.join(Room.Index.repo_root(), "index/has/kai.md"), dest)

    with {:ok, investors} <- cast(:founder_investors),
         {:ok, customers} <- cast(:founder_customers),
         {:ok, icp} <- cast(:icp_pain),
         {:ok, pkg} <- cast(:package_n, %{n: 3, package: "x"}),
         {:ok, vibe} <- cast("vibe: passionate energy"),
         {:ok, match} <- Room.Need.match_has(investors, root: root) do
      cond do
        not investors.ok or not customers.ok or not icp.ok or not pkg.ok ->
          {:error, :shape_miss}

        not vibe.unfit or vibe.ok ->
          {:error, :vibe_matched}

        match.handle != "kai@mazel" or match[:unfit] ->
          {:error, :match_miss}

        true ->
          lines =
            [look(investors), look(customers), look(icp), look(pkg)] ++
              ["ok  need×has  peer=#{match.handle}", look(vibe)]

          {:ok,
           %{
             investors: investors,
             customers: customers,
             icp: icp,
             package: pkg,
             vibe: vibe,
             match: match,
             lines: lines
           }}
      end
    end
  end

  defp build(spec, params) do
    fields =
      Map.new(spec.fields, fn key ->
        {key, pick(params, key, Map.fetch!(spec.defaults, key))}
      end)

    %{
      ok: true,
      id: spec.id,
      need_id: spec.id,
      kind: "need",
      shape: spec.id,
      fields: fields,
      wants: spec.wants,
      ask: Room.Need.Shape.label(spec.id),
      topic: hd(spec.wants),
      ttl_hours: spec.ttl_hours,
      sink: "need@mazel",
      unfit: false
    }
  end

  defp curious(raw) do
    %{
      ok: false,
      id: nil,
      need_id: nil,
      kind: :curious,
      shape: nil,
      fields: %{},
      wants: [],
      ask: to_string(raw),
      error: "vibe",
      curious: true,
      unfit: true
    }
  end

  defp pick(params, key, default) do
    Map.get(params, key) || Map.get(params, Atom.to_string(key)) || default
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {k, v}
      {k, v} -> {k, v}
    end)
  end

  defp stringify_keys(_), do: %{}

  defp normalize(id) when is_atom(id), do: id

  defp normalize(id) when is_binary(id) do
    down = id |> String.trim() |> String.downcase()

    cond do
      down == "" ->
        :vibe

      String.starts_with?(down, "vibe") or String.starts_with?(down, "claim") or
          String.starts_with?(down, "curious") ->
        :vibe

      true ->
        name = down |> String.replace("-", "_") |> String.replace(" ", "_")

        try do
          String.to_existing_atom(name)
        rescue
          ArgumentError -> :vibe
        end
    end
  end

  defp normalize(_), do: :vibe
end
