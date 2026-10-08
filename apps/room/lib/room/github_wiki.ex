defmodule Room.GithubWiki do
  @moduledoc """
  GitHub proof Has writes a person wiki slice.

  people/kai.md on gh→has only. Resume-only / claim stay
  curious and write nothing. Rebuildable. No ES. Distinct from
  pdf_wiki (PDF proof), wiki_slice (curious→has, no proof cite),
  and has_gh (no wiki=). Off Needs. Off badge.
  """

  def look_promote(rec \\ %{}) do
    peer = rec[:handle] || rec[:peer] || "kai@mazel"
    "ok  promote=gh→has  peer=#{peer}"
  end

  def look_write(rec \\ %{}) do
    wiki = rec[:wiki] || rec[:rel] || "people/kai.md"
    proof = rec[:proof] || rec[:gh] || proof_id(nil)
    "ok  wiki=#{wiki}  written=true  proof=#{proof}"
  end

  def look_resume, do: "error  gh=resume  wiki=none"

  def look_claim, do: "error  gh=claim  wiki=none"

  def look(pack) when is_map(pack) do
    [look_promote(pack.has), look_write(pack.slice), look_resume(), look_claim()]
  end

  def look(_), do: look(%{has: %{handle: "kai@mazel"}, slice: %{wiki: "people/kai.md", proof: proof_id(nil)}})

  @doc """
  Write people/<handle>.md citing the GitHub fixture / repo proof id.
  Has only. Curious stays :not_has.
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
    raw = has[:file] || has[:gh] || Room.Has.github_rel()
    raw |> to_string() |> Path.basename()
  end

  defp proof_id(_), do: Path.basename(Room.Has.github_rel())

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
    gh: #{proof}
    """
  end

  @doc """
  GH trail→has writes people/kai.md. Resume / claim never write.
  Isolated. Sibling pdf_wiki / wiki_slice / has_gh LOOK stays.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-github-wiki-#{System.unique_integer([:positive])}")
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
           Room.Has.seed_resume(Room.Has.align_rel(), handle: "kai@mazel", root: root, github: false),
         {:ok, claim} <-
           Room.Has.seed_resume(Room.Has.fluff_rel(), handle: "kai@mazel", root: root, github: false),
         {:error, :not_has} <- Room.WikiSlice.write(resume, root: root),
         {:error, :not_has} <- Room.WikiSlice.write(claim, root: root),
         {:error, :not_has} <- write(resume, root: root),
         {:error, :not_has} <- write(claim, root: root),
         {:ok, gh} <-
           Room.Has.seed_github(Room.Has.github_rel(), handle: "kai@mazel", root: root),
         {:ok, slice} <- write(gh, root: root),
         {:ok, rows} <- Room.WikiSlice.rebuild(root) do
      cond do
        resume.status != "curious" or resume.reason != "resume_only" ->
          {:error, :resume_not_curious}

        claim.status != "curious" or claim.reason != "claim" ->
          {:error, :claim_not_curious}

        gh.status != "has" or gh.source != "github" ->
          {:error, :trail_miss}

        not File.regular?(expected) or slice.written != true or slice.wiki != "people/kai.md" ->
          {:error, :write_miss}

        slice.proof != proof_id(gh) or not String.contains?(File.read!(expected), "proof: #{slice.proof}") ->
          {:error, :cite_miss}

        not Enum.any?(rows, &(&1.handle == "kai@mazel" and &1.has != [])) ->
          {:error, :rebuild_miss}

        true ->
          pack = %{
            resume: resume,
            claim: claim,
            has: Map.merge(gh, %{handle: "kai@mazel"}),
            slice: slice,
            rows: rows,
            path: expected
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end
end
