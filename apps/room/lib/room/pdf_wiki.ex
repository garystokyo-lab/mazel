defmodule Room.PdfWiki do
  @moduledoc """
  PDF-aligned Has promote writes a person wiki slice.

  people/kai.md on pdf→has only. Resume/claim/conflict stay
  curious and write nothing. Rebuildable. No ES. Distinct from
  wiki_slice (curious→has URL/trail) and pdf_has (no wiki=).
  """

  def look_promote(rec \\ %{}) do
    peer = rec[:handle] || rec[:peer] || "kai@mazel"
    "ok  promote=pdf→has  peer=#{peer}"
  end

  def look_write(rec \\ %{}) do
    wiki = rec[:wiki] || rec[:rel] || "people/kai.md"
    proof = rec[:proof] || rec[:pdf] || proof_id(nil)
    "ok  wiki=#{wiki}  written=true  proof=#{proof}"
  end

  def look_claim, do: "error  pdf=claim  wiki=none"

  def look_conflict, do: "error  pdf=conflict  wiki=none"

  def look(pack) when is_map(pack) do
    [look_promote(pack.has), look_write(pack.slice), look_claim(), look_conflict()]
  end

  def look(_), do: look(%{has: %{handle: "kai@mazel"}, slice: %{wiki: "people/kai.md", proof: proof_id(nil)}})

  @doc """
  Write people/<handle>.md citing the PDF proof id.
  Has only. Curious / conflict stay :not_has.
  """
  def write(has, opts \\ []) when is_map(has) do
    cond do
      has[:status] != "has" and has[:kind] != "has" ->
        {:error, :not_has}

      true ->
        root = Keyword.get(opts, :root) || Room.Index.repo_root()
        handle = has[:handle] || has[:peer] || Keyword.get(opts, :handle) || "kai@mazel"
        slug = handle |> to_string() |> String.trim_leading("@") |> String.split("@") |> hd()
        rel = Path.join("people", slug <> ".md")
        path = Path.join([root, Room.WikiSlice.vault_rel(), rel])
        proof = proof_id(has)
        File.mkdir_p!(Path.dirname(path))
        File.write!(path, markdown(has, handle, slug, proof))
        {:ok, %{path: path, rel: rel, wiki: rel, written: true, handle: handle, peer: handle, proof: proof}}
    end
  end

  defp proof_id(has) when is_map(has) do
    raw = has[:file] || has[:pdf] || Room.Has.pdf_rel()
    raw |> to_string() |> Path.basename()
  end

  defp proof_id(_), do: Path.basename(Room.Has.pdf_rel())

  defp markdown(has, handle, slug, proof) do
    skills = List.wrap(has[:has] || has[:skills] || has[:proof] || [])
    listed = Enum.join(skills, ", ")

    """
    ---
    id: #{slug}
    kind: has
    status: has
    handle: #{handle}
    source: wiki
    proof: #{proof}
    as_of: 2026-09-11
    ---

    # #{handle}

    has: #{listed}
    pdf: #{proof}
    """
  end

  @doc """
  Aligned PDF after a trail writes people/kai.md.
  Claim / conflict never write. Isolated. Sibling LOOK stays.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-pdf-wiki-#{System.unique_integer([:positive])}")
          File.mkdir_p!(Path.join(path, "index/has"))
          File.mkdir_p!(Path.join(path, Room.WikiSlice.people_rel()))
          {path, true}
      end

    try do
      demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp demo_on(root) do
    expected = Path.join([root, Room.WikiSlice.vault_rel(), "people", "kai.md"])

    with {:ok, resume} <-
           Room.Has.seed_resume(Room.Has.pdf_rel(), handle: "kai@mazel", root: root, github: false),
         {:ok, claim} <-
           Room.Has.seed_resume(Room.Has.fluff_rel(), handle: "kai@mazel", root: root, github: false),
         {:error, :not_has} <- Room.WikiSlice.write(resume, root: root),
         {:error, :not_has} <- Room.WikiSlice.write(claim, root: root),
         {:ok, gh} <-
           Room.Has.seed_github(Room.Has.github_rel(), handle: "kai@mazel", root: root),
         {:ok, aligned} <-
           Room.Has.seed_resume(Room.Has.pdf_rel(), handle: "kai@mazel", root: root),
         {:ok, slice} <- write(aligned, root: root),
         {:ok, conflict} <-
           Room.Has.seed_resume(Room.Has.conflict_rel(), handle: "kai@mazel", root: root),
         {:error, :not_has} <- Room.WikiSlice.write(conflict, root: root),
         {:ok, rows} <- Room.WikiSlice.rebuild(root) do
      cond do
        resume.status != "curious" or claim.status != "curious" or claim.reason != "claim" ->
          {:error, :claim_not_curious}

        gh.status != "has" ->
          {:error, :trail_miss}

        aligned.status != "has" or aligned.reason != "aligned" or aligned.source != "upload" ->
          {:error, :align_not_has}

        conflict.status != "curious" or conflict.reason != "conflict" ->
          {:error, :conflict_not_curious}

        not File.regular?(expected) or slice.written != true or slice.wiki != "people/kai.md" ->
          {:error, :write_miss}

        slice.proof != proof_id(aligned) or not String.contains?(File.read!(expected), "proof: #{slice.proof}") ->
          {:error, :cite_miss}

        not Enum.any?(rows, &(&1.handle == "kai@mazel" and &1.has != [])) ->
          {:error, :rebuild_miss}

        true ->
          pack = %{
            resume: resume,
            claim: claim,
            aligned: aligned,
            conflict: conflict,
            has: Map.merge(aligned, %{handle: "kai@mazel"}),
            slice: slice,
            rows: rows,
            path: expected
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end
end
