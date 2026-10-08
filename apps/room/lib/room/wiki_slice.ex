defmodule Room.WikiSlice do
  @moduledoc """
  Person md slice in the wiki vault.

  Written on curious→Has promote (trail / proof). Rebuildable
  from slices. No ES. Not the Rust wiki_demo knows/needs compile.
  """

  @vault "index/wiki"
  @people "people"
  @as_of "2026-09-11"

  def vault_rel, do: @vault
  def people_rel, do: Path.join(@vault, @people)

  def look_promote(rec) when is_map(rec) do
    "ok  promote=curious→has  peer=#{peer(rec)}"
  end

  def look_write(rec) when is_map(rec) do
    "ok  wiki=#{rec[:wiki] || rec[:rel] || "people/kai.md"}  written=#{rec[:written] == true}"
  end

  def look(pack) when is_map(pack) do
    [look_promote(pack.has), look_write(pack.slice)]
  end

  def look(_), do: look(%{has: %{handle: "kai@mazel"}, slice: %{wiki: "people/kai.md", written: true}})

  @doc """
  Promote a curious seed. Trail required. Writes the person slice.
  """
  def promote(curious, opts \\ []) when is_map(curious) do
    opts = Keyword.put_new(opts, :handle, peer(curious))

    with {:ok, has} <- Room.ProfileSeed.promote(curious, opts),
         {:ok, slice} <- write(has, opts) do
      {:ok, Map.merge(has, slice)}
    end
  end

  @doc """
  Write / update `people/<slug>.md` for a Has person.
  """
  def write(has, opts \\ []) when is_map(has) do
    cond do
      has[:status] != "has" and has[:kind] != "has" ->
        {:error, :not_has}

      true ->
        root = Keyword.get(opts, :root) || Room.Index.repo_root()
        handle = peer(has) || Keyword.get(opts, :handle) || "kai@mazel"
        slug = slug(handle)
        rel = Path.join(@people, slug <> ".md")
        path = Path.join([root, @vault, rel])
        File.mkdir_p!(Path.dirname(path))
        File.write!(path, markdown(has, handle, slug))
        {:ok, %{path: path, rel: rel, wiki: rel, written: true, handle: handle, peer: handle}}
    end
  end

  @doc "Rebuild person rows from wiki slices. No ES."
  def rebuild(root) do
    dir = Path.join(root, people_rel())

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
  URL seed stays curious (no slice). Trail promote writes people/kai.md.
  Isolated. Does not rewrite profile_seed LOOK.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-wiki-slice-#{System.unique_integer([:positive])}")
          File.mkdir_p!(Path.join(path, people_rel()))
          {path, true}
      end

    try do
      demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp demo_on(root) do
    url = Room.Has.fixture_url()
    expected = Path.join([root, @vault, @people, "kai.md"])

    with {:ok, alone} <- Room.ProfileSeed.seed(url),
         alone <- Map.put(alone, :handle, "kai@mazel"),
         {:error, :url_alone} <- promote(alone, root: root),
         {:ok, has} <- promote(alone, trail: :github, root: root, handle: "kai@mazel"),
         {:ok, rows} <- rebuild(root) do
      cond do
        File.regular?(expected) == false ->
          {:error, :slice_miss}

        has.status != "has" or has.written != true or has.wiki != "people/kai.md" ->
          {:error, :write_miss}

        not Enum.any?(rows, &(&1.handle == "kai@mazel" and &1.has != [])) ->
          {:error, :rebuild_miss}

        true ->
          pack = %{has: has, slice: has, rows: rows, path: expected}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp markdown(has, handle, slug) do
    skills = List.wrap(has[:has] || has[:skills] || has[:proof] || [])
    listed = Enum.join(skills, ", ")

    """
    ---
    id: #{slug}
    kind: has
    status: has
    handle: #{handle}
    source: wiki
    as_of: #{@as_of}
    ---

    # #{handle}

    has: #{listed}
    """
  end

  defp parse(path) do
    raw = File.read!(path)

    handle =
      case Regex.run(~r/^handle:\s*(.+)$/m, raw) do
        [_, h] -> String.trim(h)
        _ -> nil
      end

    has =
      case Regex.run(~r/^has:\s*(.+)$/m, raw) do
        [_, line] ->
          line |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

        _ ->
          []
      end

    if is_binary(handle) and handle != "" do
      %{handle: handle, has: has, status: "has", path: path, source: "wiki"}
    end
  end

  defp peer(rec) when is_map(rec) do
    rec[:handle] || rec[:peer] || rec["handle"]
  end

  defp peer(_), do: nil

  defp slug(handle) when is_binary(handle) do
    handle
    |> String.trim()
    |> String.trim_leading("@")
    |> String.split("@")
    |> hd()
    |> String.downcase()
  end

  defp slug(_), do: "kai"
end
