defmodule Room.GithubWikiScore do
  @moduledoc """
  Named Factor inputs on a GH-cited wiki find.

  Fit from slice overlap. Heat stays 0 on this strip
  (cite is proof id, not vouch heat). trail/check are not
  natural here. LLM never ranks. Resume / claim still miss.
  Distinct from github_wiki_find (proof= only) and
  pdf_wiki_score (from=pdf). Off Needs. Off badge.
  """

  def look_find(rec \\ %{}) do
    Room.GithubWikiFind.look_find(rec)
  end

  def look_score(rec \\ %{}) do
    named = rec[:inputs] || rec[:factors] || %{fit: 1, heat: 0, fresh: 1}
    score = rec[:score] || 0
    "ok  from=gh  inputs=#{Room.Factors.format_inputs(named)}  score=#{fmt(score)}"
  end

  def look_resume, do: "error  gh=resume  find=none"

  def look_claim, do: "error  gh=claim  find=none"

  def look(pack) when is_map(pack) do
    [look_find(pack.hit), look_score(pack.scored), look_resume(), look_claim()]
  end

  def look(_), do: look(%{hit: %{}, scored: %{}})

  @doc "Pure score from a GH-cited wiki hit. No I/O. LLM never ranks."
  def score_hit(hit) when is_map(hit) do
    fit = if hit[:ok] == true and overlap?(hit), do: 1, else: 0
    Room.Factors.score(%{fit: fit, heat: 0, fresh: 1})
  end

  def score_hit(_), do: Room.Factors.score(%{fit: 0, heat: 0, fresh: 1})

  @doc """
  Wiki find + Factor inputs. Resume / claim miss.
  Isolated. Sibling find / pdf-score LOOK stays.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path =
            Path.join(System.tmp_dir!(), "mazel-github-wiki-score-#{System.unique_integer([:positive])}")

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
    with {:ok, found} <- Room.GithubWikiFind.demo(root: root) do
      scored = score_hit(found.hit)

      cond do
        not found.hit.ok or found.hit.proof != "kai.github.txt" ->
          {:error, :find_miss}

        found.hit.from != "gh" ->
          {:error, :not_from_gh}

        scored.unfit ->
          {:error, :score_unfit}

        scored.inputs.fit != 1 or scored.inputs.heat != 0 or scored.inputs.fresh != 1 ->
          {:error, :inputs_miss}

        Map.get(scored.inputs, :trail, 0) != 0 or Map.get(scored.inputs, :check, 0) != 0 ->
          {:error, :trail_not_natural}

        found.resume.ok or found.claim.ok ->
          {:error, :curious_hit}

        true ->
          pack = %{
            found: found,
            hit: found.hit,
            scored: scored,
            resume: found.resume,
            claim: found.claim,
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
