defmodule Room.PdfWikiWhy do
  @moduledoc """
  Double-magic why on a PDF-cited wiki find.

  why_fields from slice overlap ids — not LLM prose.
  Claim / conflict still miss and get no why.
  Distinct from pdf_wiki_score (inputs= only), why_demo
  (need×has comments), and agent_complete_why (non-pdf).
  Off Needs. Off badge.
  """

  def look_find(rec \\ %{}) do
    Room.PdfWikiFind.look_find(rec)
  end

  def look_why(rec \\ %{}) do
    [
      "why  need=#{rec[:why_need] || "series-a"}",
      "why  has=#{rec[:why_has] || "series-a"}"
    ]
  end

  def look_claim, do: "error  pdf=claim  find=none"

  def look_conflict, do: "error  pdf=conflict  find=none"

  def look(pack) when is_map(pack) do
    [look_find(pack.hit)] ++ look_why(pack.why) ++ [look_claim(), look_conflict()]
  end

  def look(_), do: look(%{hit: %{}, why: %{}})

  @doc "Structured why from a PDF-cited wiki hit. No I/O. Unfit never why."
  def why_hit(hit) when is_map(hit) do
    has = Enum.map(List.wrap(hit[:has]), &to_string/1)
    q = to_string(hit[:query] || "series-a")
    overlap = Enum.filter(has, &(&1 == q or &1 == "series-a"))
    need = %{wants: [q]}

    match = %{
      ok: hit[:ok] == true,
      handle: hit[:handle],
      overlap: overlap,
      wants: [q]
    }

    Room.Score.why_fields(need, match)
  end

  def why_hit(_), do: Room.Score.why_fields(nil, %{ok: false})

  @doc """
  Wiki find + why need/has. Claim / conflict miss.
  Isolated. Sibling find / score / why LOOK stays.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-pdf-wiki-why-#{System.unique_integer([:positive])}")
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
    with {:ok, found} <- Room.PdfWikiFind.demo(root: root) do
      why = why_hit(found.hit)
      claim_why = why_hit(found.claim)
      conflict_why = why_hit(found.conflict)

      cond do
        not found.hit.ok or found.hit.proof != "kai.resume.pdf" ->
          {:error, :find_miss}

        why.why_need != "series-a" or why.why_has != "series-a" ->
          {:error, :why_miss}

        not is_nil(claim_why.why_need) or not is_nil(claim_why.why_has) ->
          {:error, :claim_why}

        not is_nil(conflict_why.why_need) or not is_nil(conflict_why.why_has) ->
          {:error, :conflict_why}

        found.claim.ok or found.conflict.ok ->
          {:error, :curious_hit}

        Enum.any?(found.lines, &String.starts_with?(&1, "why  ")) ->
          {:error, :find_already_why}

        true ->
          pack = %{
            found: found,
            hit: found.hit,
            why: why,
            claim: found.claim,
            conflict: found.conflict,
            path: found.path
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end
end