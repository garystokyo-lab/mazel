defmodule Room.GithubWikiFind do
  @moduledoc """
  Find against a wiki person slice that cites GitHub proof.

  people/kai.md with proof=kai.github.txt feeds find.
  Resume / claim never write a slice, so they miss.
  Distinct from github_wiki (write only), pdf_wiki_find
  (PDF proof), and has_gh (no wiki find). No ES.
  Off Needs. Off badge.
  """

  def look_find(rec \\ %{}) do
    peer = rec[:handle] || rec[:peer] || "kai@mazel"
    proof = rec[:proof] || "kai.github.txt"
    "ok  find=series-a→#{peer}  proof=#{proof}"
  end

  def look_wiki(rec \\ %{}) do
    wiki = rec[:wiki] || "people/kai.md"
    "ok  wiki=#{wiki}  from=gh"
  end

  def look_resume, do: "error  gh=resume  find=none"

  def look_claim, do: "error  gh=claim  find=none"

  def look(pack) when is_map(pack) do
    [look_find(pack.hit), look_wiki(pack.hit), look_resume(), look_claim()]
  end

  def look(_), do: look(%{hit: %{}})

  @doc """
  Wiki people slices that cite a GitHub proof. Query overlaps `has:`.
  No card catalog. No ES.
  """
  def find(query, root) when is_binary(query) do
    q = query |> String.trim() |> String.downcase()

    with {:ok, rows} <- Room.WikiSlice.rebuild(root) do
      hit =
        rows
        |> Enum.map(&with_cite/1)
        |> Enum.find(fn row ->
          gh?(row[:proof]) and q in Enum.map(List.wrap(row[:has]), &String.downcase/1)
        end)

      if is_map(hit) do
        {:ok,
         Map.merge(hit, %{
           ok: true,
           query: q,
           wiki: "people/kai.md",
           from: "gh",
           matches: [hit.handle]
         })}
      else
        {:ok, %{ok: false, query: q, handle: nil, matches: [], proof: nil, from: "gh"}}
      end
    end
  end

  def find(_, _), do: {:ok, %{ok: false, query: "", matches: [], from: "gh"}}

  @doc """
  GH-cited wiki slice feeds find. Resume / claim miss.
  Isolated. Sibling write / pdf-find LOOK stays.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path =
            Path.join(System.tmp_dir!(), "mazel-github-wiki-find-#{System.unique_integer([:positive])}")

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
    with {:ok, wiki} <- Room.GithubWiki.demo(root: root),
         {:ok, hit} <- find("series-a", root),
         {:ok, resume_miss} <- find("resume-only", root),
         {:ok, claim_miss} <- find("passionate", root) do
      body = File.read!(wiki.path)

      cond do
        not hit.ok or hit.handle != "kai@mazel" or hit.proof != "kai.github.txt" ->
          {:error, :find_miss}

        hit.from != "gh" ->
          {:error, :not_from_gh}

        not String.contains?(body, "proof: kai.github.txt") ->
          {:error, :cite_miss}

        resume_miss.ok or resume_miss.matches != [] ->
          {:error, :resume_hit}

        claim_miss.ok or claim_miss.matches != [] ->
          {:error, :claim_hit}

        wiki.resume.status != "curious" or wiki.claim.status != "curious" ->
          {:error, :curious_miss}

        true ->
          pack = %{
            wiki: wiki,
            hit: hit,
            resume: resume_miss,
            claim: claim_miss,
            path: wiki.path
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp with_cite(row) do
    Map.put(row, :proof, cite(row[:path]))
  end

  defp cite(path) when is_binary(path) do
    raw = File.read!(path)

    case Regex.run(~r/^proof:\s*(.+)$/m, raw) do
      [_, p] ->
        String.trim(p)

      _ ->
        case Regex.run(~r/^gh:\s*(.+)$/m, raw) do
          [_, p] -> String.trim(p)
          _ -> nil
        end
    end
  end

  defp cite(_), do: nil

  defp gh?(id) when is_binary(id), do: String.contains?(id, "github")
  defp gh?(_), do: false
end
