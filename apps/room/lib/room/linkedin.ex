defmodule Room.LinkedIn do
  @moduledoc """
  LinkedIn zip/export → curious scaffolding only.

  Names and profile structure land as curious. Never Has.
  This layer does not promote. GH / vouch trails live elsewhere.
  Claims and boasts stay curious.
  """

  @scaffold ~w(name headline positions)
  @export_files ~w(Profile.csv Positions.csv Skills.csv)

  def export_rel, do: "priv/fixtures/linkedin"
  def zip_name, do: "kai.linkedin.zip"
  def scaffold_ids, do: @scaffold

  def import_zip(raw, opts \\ []) when is_binary(raw) do
    root = Keyword.get(opts, :root) || Room.Index.repo_root()

    with {:ok, path} <- resolve(raw, root),
         {:ok, files} <- unzip(path) do
      rec = scaffold(files, opts)
      if Keyword.get(opts, :persist, true), do: persist(rec, root)
      {:ok, rec}
    end
  end

  @doc """
  Pack the LinkedIn CSV fixture into a zip. Import reads the zip.
  """
  def pack_zip(dest, opts \\ []) when is_binary(dest) do
    root = Keyword.get(opts, :root) || Room.Index.repo_root()
    src = Path.join(root, export_rel())
    File.mkdir_p!(Path.dirname(dest))

    entries =
      Enum.map(@export_files, fn name ->
        {String.to_charlist(name), File.read!(Path.join(src, name))}
      end)

    case :zip.create(String.to_charlist(dest), entries) do
      {:ok, _} -> {:ok, dest}
      {:error, reason} -> {:error, reason}
    end
  end

  def unzip(path) when is_binary(path) do
    case :zip.unzip(String.to_charlist(path), [:memory]) do
      {:ok, entries} ->
        {:ok,
         Map.new(entries, fn {name, bin} ->
           {entry_name(name), bin}
         end)}

      {:error, _} ->
        {:error, :bad_zip}
    end
  end

  def scaffold(files, opts \\ []) when is_map(files) do
    profile = List.first(parse_csv(files["Profile.csv"] || "")) || %{}
    positions = parse_csv(files["Positions.csv"] || "")
    skills = parse_csv(files["Skills.csv"] || "")

    first = Map.get(profile, "first name", "")
    last = Map.get(profile, "last name", "")
    name = String.trim("#{first} #{last}")
    headline = String.trim(Map.get(profile, "headline", ""))
    summary = String.trim(Map.get(profile, "summary", ""))
    handle = Keyword.get(opts, :handle) || "kai@mazel"

    curious =
      []
      |> then(&if(name != "", do: &1 ++ ["name"], else: &1))
      |> then(&if(headline != "", do: &1 ++ ["headline"], else: &1))
      |> then(&if(positions != [], do: &1 ++ ["positions"], else: &1))

    claims =
      [headline, summary]
      |> Kernel.++(Enum.map(positions, &position_line/1))
      |> Kernel.++(Enum.map(skills, &Map.get(&1, "name", "")))
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    %{
      ok: true,
      kind: "curious",
      status: "curious",
      source: "linkedin",
      provenance: Room.Has.provenance_for("linkedin"),
      strength: "curious",
      handle: handle,
      file: zip_name(),
      name: name,
      headline: headline,
      positions: Enum.map(positions, &position_line/1),
      skills: [],
      proof: [],
      has: [],
      curious: curious,
      claim: claims,
      reason: "no_trail",
      unfit: true,
      trail: 0,
      check: 0
    }
  end

  @doc "This layer never promotes. Trails are GH / vouch, not a zip."
  def promote(_rec, _opts \\ []), do: {:error, :no_trail}

  def look(rec) when is_map(rec) do
    listed = Enum.join(rec[:curious] || [], ",")

    [
      "ok  import=linkedin  →curious",
      "ok  has=[] / curious=[#{listed}]",
      "error  no_trail→curious  unfit=true"
    ]
  end

  def look(_), do: look(%{curious: []})

  @doc """
  Isolated zip → curious. Does not write the repo Has slice.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-linkedin-#{System.unique_integer([:positive])}")
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
    zip = Path.join(root, zip_name())

    with {:ok, _} <- pack_zip(zip),
         {:ok, rec} <- import_zip(zip, root: root, handle: "kai@mazel") do
      cond do
        rec.status != "curious" or rec.source != "linkedin" ->
          {:error, :not_curious}

        rec.has != [] or rec.skills != [] or rec.proof != [] ->
          {:error, :leaked_has}

        rec.curious != @scaffold ->
          {:error, :bad_scaffold}

        promote(rec) != {:error, :no_trail} ->
          {:error, :promoted}

        File.regular?(Path.join(Room.Index.dir(root, "has"), "kai.md")) ->
          {:error, :wrote_has}

        not File.regular?(Path.join(Room.Index.dir(root, "curious"), "kai.md")) ->
          {:error, :no_curious_slice}

        true ->
          {:ok, %{rec: rec, lines: look(rec)}}
      end
    end
  end

  defp persist(rec, root) do
    Room.Has.write_slice(root, rec)
  end

  defp resolve(raw, root) do
    cond do
      File.regular?(raw) -> {:ok, raw}
      File.regular?(Path.join(root, raw)) -> {:ok, Path.join(root, raw)}
      File.regular?(Path.join(Room.Index.repo_root(), raw)) -> {:ok, Path.join(Room.Index.repo_root(), raw)}
      true -> {:error, :bad_file}
    end
  end

  defp entry_name(name) do
    name
    |> to_string()
    |> String.replace("\\", "/")
    |> Path.basename()
  end

  defp parse_csv(text) when text in [nil, ""], do: []

  defp parse_csv(text) do
    lines =
      text
      |> String.split(~r/\r?\n/)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    case lines do
      [header | rows] ->
        keys = header |> String.split(",") |> Enum.map(&csv_key/1)

        Enum.map(rows, fn row ->
          vals = String.split(row, ",")
          Map.new(Enum.zip(keys, vals))
        end)

      _ ->
        []
    end
  end

  defp csv_key(key), do: key |> String.trim() |> String.downcase()

  defp position_line(row) do
    title = String.trim(Map.get(row, "title", ""))
    company = String.trim(Map.get(row, "company name", ""))

    cond do
      title != "" and company != "" -> "#{title} @ #{company}"
      title != "" -> title
      company != "" -> company
      true -> ""
    end
  end
end