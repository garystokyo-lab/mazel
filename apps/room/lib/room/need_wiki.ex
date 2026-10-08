defmodule Room.NeedWiki do
  @moduledoc """
  Need md slice in the wiki vault.

  Written on Need cast / seed. Rebuildable from slices. No ES.
  Pair with person slices (`Room.WikiSlice`). Curious / vibe
  does not write. Does not rewrite need_shape or wiki_slice LOOK.
  """

  @vault "index/wiki"
  @needs "needs"
  @as_of "2026-09-11"
  @shape :icp_pain

  def vault_rel, do: @vault
  def needs_rel, do: Path.join(@vault, @needs)

  def look_cast(need) when is_map(need) do
    "ok  cast=need  id=#{need[:id] || need[:shape] || need[:need_id]}"
  end

  def look_write(rec) when is_map(rec) do
    "ok  wiki=#{rec[:wiki] || rec[:rel] || "needs/icp_pain.md"}  written=#{rec[:written] == true}"
  end

  def look(pack) when is_map(pack) do
    [look_cast(pack.need), look_write(pack.slice)]
  end

  def look(_), do: look(%{need: %{id: @shape}, slice: %{wiki: "needs/icp_pain.md", written: true}})

  @doc """
  Cast a Need preset and write `needs/<id>.md`. Vibe / claim skip write.
  """
  def cast(raw, opts \\ []) do
    params = Keyword.get(opts, :params, %{})

    with {:ok, need} <- Room.Need.Shape.cast(raw, params) do
      cond do
        need.unfit or Room.Need.curious?(need) ->
          {:ok, need}

        true ->
          case write(need, opts) do
            {:ok, slice} -> {:ok, Map.merge(need, slice)}
            other -> other
          end
      end
    end
  end

  @doc "Write / update `needs/<id>.md` for a structured Need."
  def write(need, opts \\ []) when is_map(need) do
    cond do
      need[:unfit] == true or Room.Need.curious?(need) ->
        {:error, :not_need}

      true ->
        root = Keyword.get(opts, :root) || Room.Index.repo_root()
        id = id_of(need)
        rel = Path.join(@needs, "#{id}.md")
        path = Path.join([root, @vault, rel])
        File.mkdir_p!(Path.dirname(path))
        File.write!(path, markdown(need, id))
        {:ok, %{path: path, rel: rel, wiki: rel, written: true, need_id: id, id: id}}
    end
  end

  @doc "Rebuild Need rows from wiki slices. No ES."
  def rebuild(root) do
    dir = Path.join(root, needs_rel())

    rows =
      if File.dir?(dir) do
        dir
        |> File.ls!()
        |> Enum.filter(&String.ends_with?(&1, ".md"))
        |> Enum.map(&parse(Path.join(dir, &1)))
        |> Enum.reject(&is_nil/1)
      else
        []
      end

    {:ok, rows}
  end

  @doc """
  Cast icp_pain → needs/icp_pain.md. Vibe does not write.
  Isolated. Does not rewrite wiki_slice / need_shape LOOK.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-need-wiki-#{System.unique_integer([:positive])}")
          File.mkdir_p!(Path.join(path, needs_rel()))
          {path, true}
      end

    try do
      demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp demo_on(root) do
    expected = Path.join([root, @vault, @needs, "icp_pain.md"])
    vibe_path = Path.join([root, @vault, @needs, "vibe.md"])

    with {:ok, need} <- cast(@shape, root: root),
         {:ok, vibe} <- cast("vibe: passionate energy", root: root),
         {:ok, rows} <- rebuild(root) do
      cond do
        File.regular?(expected) == false ->
          {:error, :slice_miss}

        File.regular?(vibe_path) ->
          {:error, :vibe_wrote}

        need.written != true or need.wiki != "needs/icp_pain.md" ->
          {:error, :write_miss}

        not vibe.unfit ->
          {:error, :vibe_fit}

        not Enum.any?(rows, &(&1.id == "icp_pain" and &1.kind == "need")) ->
          {:error, :rebuild_miss}

        true ->
          pack = %{need: need, slice: need, vibe: vibe, rows: rows, path: expected}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp markdown(need, id) do
    wants = List.wrap(need[:wants] || need["wants"] || [])
    listed = Enum.join(wants, ", ")

    """
    ---
    id: #{id}
    kind: need
    status: need
    shape: #{id}
    source: wiki
    as_of: #{@as_of}
    ---

    # Need #{id}

    wants: #{listed}
    """
  end

  defp parse(path) do
    raw = File.read!(path)

    id =
      case Regex.run(~r/^id:\s*(.+)$/m, raw) do
        [_, v] -> String.trim(v)
        _ -> nil
      end

    kind =
      case Regex.run(~r/^kind:\s*(.+)$/m, raw) do
        [_, v] -> String.trim(v)
        _ -> "need"
      end

    wants =
      case Regex.run(~r/^wants:\s*(.+)$/m, raw) do
        [_, line] ->
          line |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

        _ ->
          []
      end

    if is_binary(id) and id != "" do
      %{id: id, kind: kind, wants: wants, path: path, source: "wiki"}
    end
  end

  defp id_of(need) do
    (need[:shape] || need[:id] || need[:need_id] || @shape)
    |> to_string()
    |> String.trim()
    |> String.downcase()
  end
end