defmodule Room.PdfWikiScore do
  @moduledoc """
  Named Factor inputs on a PDF-cited wiki find.

  Fit from slice overlap. Heat stays 0 (no vouch / GH trail).
  trail/check are not natural here. LLM never ranks.
  Claim / conflict still miss. Distinct from pdf_wiki_find
  (proof= only) and score_demo (no from=pdf).
  """

  def look_find(rec \\ %{}) do
    Room.PdfWikiFind.look_find(rec)
  end

  def look_score(rec \\ %{}) do
    named = rec[:inputs] || rec[:factors] || %{fit: 1, heat: 0, fresh: 1}
    score = rec[:score] || 0
    "ok  from=pdf  inputs=#{Room.Factors.format_inputs(named)}  score=#{fmt(score)}"
  end

  def look_claim, do: "error  pdf=claim  find=none"

  def look_conflict, do: "error  pdf=conflict  find=none"

  def look(pack) when is_map(pack) do
    [look_find(pack.hit), look_score(pack.scored), look_claim(), look_conflict()]
  end

  def look(_), do: look(%{hit: %{}, scored: %{}})

  @doc "Pure score from a PDF-cited wiki hit. No I/O. LLM never ranks."
  def score_hit(hit) when is_map(hit) do
    fit = if hit[:ok] == true and overlap?(hit), do: 1, else: 0
    Room.Factors.score(%{fit: fit, heat: 0, fresh: 1})
  end

  def score_hit(_), do: Room.Factors.score(%{fit: 0, heat: 0, fresh: 1})

  @doc """
  Wiki find + Factor inputs. Claim / conflict miss.
  Isolated. Sibling find / score LOOK stays.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-pdf-wiki-score-#{System.unique_integer([:positive])}")
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
      scored = score_hit(found.hit)

      cond do
        not found.hit.ok or found.hit.proof != "kai.resume.pdf" ->
          {:error, :find_miss}

        scored.unfit ->
          {:error, :score_unfit}

        scored.inputs.fit != 1 or scored.inputs.heat != 0 or scored.inputs.fresh != 1 ->
          {:error, :inputs_miss}

        Map.get(scored.inputs, :trail, 0) != 0 or Map.get(scored.inputs, :check, 0) != 0 ->
          {:error, :trail_not_natural}

        found.claim.ok or found.conflict.ok ->
          {:error, :curious_hit}

        true ->
          pack = %{
            found: found,
            hit: found.hit,
            scored: scored,
            claim: found.claim,
            conflict: found.conflict,
            path: found.path
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp overlap?(hit) do
    has = Enum.map(List.wrap(hit[:has]), &to_string/1)
    q = to_string(hit[:query] || "series-a")
    q in has or "series-a" in has
  end

  defp fmt(n) when is_float(n) do
    if n == Float.floor(n), do: trunc(n), else: :erlang.float_to_binary(n, decimals: 2)
  end

  defp fmt(n) when is_integer(n), do: n
  defp fmt(_), do: 0
end
