defmodule Room.McpTrail do
  @moduledoc """
  MCP / non-AI artifact trail → Has weight in find + quant.

  Claims never Has. Trails only. Does not rewrite trail_score / gh_rank LOOK.
  """

  def look_mcp(rec) when is_map(rec) do
    "ok  mcp=artifact  trail=#{rec[:trail] || 1}  check=#{rec[:check] || 1}"
  end

  def look_mcp(_), do: "ok  mcp=artifact  trail=1  check=1"

  def look_find(found) when is_map(found) do
    hit = List.first(found[:hits] || [])
    handle = (hit && hit.handle) || "kai@mazel"
    "ok  find=series-a→#{handle}  trail=1"
  end

  def look_find(_), do: "ok  find=series-a→kai@mazel  trail=1"

  def look_score(rec) when is_map(rec) do
    named = rec[:inputs] || rec[:factors] || %{}
    score = rec[:score] || 0
    "ok  need×has  peer=#{rec[:handle] || "kai@mazel"}  inputs=#{Room.Factors.format_inputs(named, :all)}  score=#{score}"
  end

  def look_claim, do: "error  claim→curious  unfit=true"

  def look(pack) when is_map(pack) do
    [look_mcp(pack.has), look_find(pack.found), look_score(pack.scored), look_claim()]
  end

  def look(_) do
    look(%{
      has: %{trail: 1, check: 1},
      found: %{hits: [%{handle: "kai@mazel"}]},
      scored: %{handle: "kai@mazel", score: 2, inputs: %{fit: 1, heat: 1, fresh: 1, trail: 1, check: 1}}
    })
  end

  @doc """
  MCP artifact trail lifts find + Factor score. Claim stays curious.
  Isolated. Does not rewrite trail_score_demo / has_gh LOOK.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-mcp-trail-#{System.unique_integer([:positive])}")
          File.mkdir_p!(Path.join(path, "index/has"))
          {path, true}
      end

    try do
      demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp demo_on(root) do
    now = Room.Age.demo_now()
    dest = Path.join(root, "index/has/kai.md")
    File.mkdir_p!(Path.dirname(dest))

    with {:ok, has} <- Room.Has.seed_mcp(Room.Has.github_rel(), handle: "kai@mazel", root: root),
         {:ok, found} <- Room.Find.query("series-a", root: root),
         {:ok, need} <- Room.Need.seed("founders-investors", root: root, now: now),
         {:ok, match} <- Room.Need.match_has(need, root: root, now: now) do
      scored = Room.Score.decorate(match, root: root, now: now, need: need)

      claim =
        Room.Factors.score(%{fit: 1, heat: 1, fresh: 1, trail: 1, check: 1, claim: true})

      hit = List.first(found[:hits] || [])

      cond do
        has.status != "has" or has.source != "mcp" ->
          {:error, :mcp_not_has}

        Room.Has.trail_for("kai@mazel", root: root) != 1 or
            Room.Has.check_for("kai@mazel", root: root) != 1 ->
          {:error, :trail_miss}

        is_nil(hit) or hit.handle != "kai@mazel" ->
          {:error, :find_miss}

        not scored.ok or scored.unfit or scored.score != 2 ->
          {:error, :score_miss}

        scored.inputs.trail != 1 or scored.inputs.check != 1 or scored.inputs.heat != 1 ->
          {:error, :inputs_miss}

        not claim.unfit ->
          {:error, :claim_fit}

        true ->
          pack = %{
            has: Map.merge(has, %{trail: 1, check: 1}),
            found: found,
            scored: scored,
            claim: claim
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end
end
