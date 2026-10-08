defmodule Room.PdfWikiFind do
  @moduledoc """
  Find against a wiki person slice that cites PDF proof.

  people/kai.md with proof=kai.resume.pdf feeds find.
  Claim / conflict never write a slice, so they miss.
  Distinct from pdf_wiki (write only) and wiki_jit (needs + from=wiki).
  No ES. Off Needs. Off badge.
  """

  def look_find(rec \\ %{}) do
    peer = rec[:handle] || rec[:peer] || "kai@mazel"
    proof = rec[:proof] || "kai.resume.pdf"
    "ok  find=series-a→#{peer}  proof=#{proof}"
  end

  def look_wiki(rec \\ %{}) do
    wiki = rec[:wiki] || "people/kai.md"
    "ok  wiki=#{wiki}  from=pdf"
  end

  def look_claim, do: "error  pdf=claim  find=none"

  def look_conflict, do: "error  pdf=conflict  find=none"

  def look(pack) when is_map(pack) do
    [look_find(pack.hit), look_wiki(pack.hit), look_claim(), look_conflict()]
  end

  def look(_), do: look(%{hit: %{}})

  @doc """
  Wiki people slices that cite a PDF proof. Query overlaps `has:`.
  No card catalog. No ES.
  """
  def find(query, root) when is_binary(query) do
    q = query |> String.trim() |> String.downcase()

    with {:ok, rows} <- Room.WikiSlice.rebuild(root) do
      hit =
        rows
        |> Enum.map(&with_cite/1)
        |> Enum.find(fn row ->
          pdf?(row[:proof]) and q in Enum.map(List.wrap(row[:has]), &String.downcase/1)
        end)

      if is_map(hit) do
        {:ok,
         Map.merge(hit, %{
           ok: true,
           query: q,
           wiki: "people/kai.md",
           from: "pdf",
           matches: [hit.handle]
         })}
      else
        {:ok, %{ok: false, query: q, handle: nil, matches: [], proof: nil, from: "pdf"}}
      end
    end
  end

  def find(_, _), do: {:ok, %{ok: false, query: "", matches: [], from: "pdf"}}

  @doc """
  PDF-cited wiki slice feeds find. Claim / conflict miss.
  Isolated. Sibling write / JIT LOOK stays.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-pdf-wiki-find-#{System.unique_integer([:positive])}")
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
    with {:ok, wiki} <- Room.PdfWiki.demo(root: root),
         {:ok, hit} <- find("series-a", root),
         {:ok, claim_miss} <- find("passionate", root),
         {:ok, conflict_miss} <- find("impl", root) do
      body = File.read!(wiki.path)

      cond do
        not hit.ok or hit.handle != "kai@mazel" or hit.proof != "kai.resume.pdf" ->
          {:error, :find_miss}

        hit.from != "pdf" ->
          {:error, :not_from_pdf}

        not String.contains?(body, "proof: kai.resume.pdf") ->
          {:error, :cite_miss}

        claim_miss.ok or claim_miss.matches != [] ->
          {:error, :claim_hit}

        conflict_miss.ok or conflict_miss.matches != [] ->
          {:error, :conflict_hit}

        wiki.claim.status != "curious" or wiki.conflict.status != "curious" ->
          {:error, :curious_miss}

        true ->
          pack = %{
            wiki: wiki,
            hit: hit,
            claim: claim_miss,
            conflict: conflict_miss,
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
      [_, p] -> String.trim(p)
      _ ->
        case Regex.run(~r/^pdf:\s*(.+)$/m, raw) do
          [_, p] -> String.trim(p)
          _ -> nil
        end
    end
  end

  defp cite(_), do: nil

  defp pdf?(id) when is_binary(id), do: String.ends_with?(id, ".pdf")
  defp pdf?(_), do: false
end
