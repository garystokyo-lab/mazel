defmodule Room.Mvp do
  @moduledoc """
  Magic loop: Add Mazel → GH proof → Has → one Need → find → mazel'd.

  Prompt-check on the same path: resume-only stays curious. GH trail
  + check → Has. Contradiction → curious. No npm hero.
  """

  def github_rel, do: Room.Has.github_rel()
  def align_rel, do: Room.Has.align_rel()
  def conflict_rel, do: Room.Has.conflict_rel()

  def run(opts \\ []) do
    root = Keyword.get(opts, :root) || Room.Index.repo_root()

    with {:ok, resume_only} <-
           Room.Has.seed_resume(align_rel(), handle: "kai@mazel", root: root, github: false),
         {:ok, gh} <- Room.Has.seed_github(github_rel(), handle: "kai@mazel", root: root),
         {:ok, need} <- Room.Need.seed("founders-investors", root: root),
         {:ok, match} <- Room.Need.match_has(need, root: root),
         {:ok, chat} <- Room.Tools.wing(Room.Find.wing_at(match.handle || "kai@mazel")),
         {:ok, curious} <- Room.Has.seed_resume(conflict_rel(), handle: "kai@mazel", root: root),
         {:ok, boast} <-
           Room.Need.match_has(
             %{
               id: "linkedin-boast",
               kind: "curious",
               status: "curious",
               ask: "I am a passionate visionary thought leader in series-a",
               wants: ["series-a"]
             },
             root: root
           ) do
      cond do
        resume_only.status != "curious" ->
          {:error, :resume_alone_has}

        gh.status != "has" or "series-a" not in gh.skills ->
          {:error, :gh_not_has}

        not (match.ok and match.handle == "kai@mazel") ->
          {:error, :no_match}

        not (chat.ok and chat.handle == "kai@mazel") ->
          {:error, :no_chat}

        curious.status != "curious" ->
          {:error, :conflict_not_curious}

        boast.ok ->
          {:error, :boast_matched}

        true ->
          result = %{
            resume_only: resume_only,
            gh: gh,
            need: need,
            match: match,
            chat: chat,
            curious: curious,
            boast: boast
          }

          {:ok, Map.put(result, :lines, look(result))}
      end
    end
  end

  def look(%{
        resume_only: resume_only,
        gh: gh,
        match: match,
        curious: curious,
        boast: boast
      }) do
    Room.Ready.add_lines() ++
      Room.Has.examine_look(resume_only) ++
      Room.Has.examine_look(gh) ++
      Room.Need.split_look([match], [boast], %{
        resume_only: resume_only,
        github: gh,
        demoted: curious
      })
  end

  @need %{id: "founders-investors", kind: "need", wants: ["series-a"]}

  @doc """
  Thin find stitch. Need×Has + chat_depth factor inputs + why.
  Reuses Factor registry and why_fields. No new ranking.
  Does not rewrite `mvp_demo` LOOK.
  """
  def find_look(%{scored: scored}) do
    named = scored[:inputs] || scored[:factors] || %{}
    score = scored[:score] || 0

    [
      "ok  find=series-a→kai@mazel  mazel'd @kai",
      "ok  need×has  peer=kai@mazel  inputs=#{Room.Factors.format_inputs(named, :all)}  score=#{score}",
      "why  need=#{scored[:why_need]}  # found who I needed",
      "why  has=#{scored[:why_has]}   # they needed what I have",
      "error  claim→curious  unfit=true"
    ]
  end

  def find_look(_), do: find_look(%{scored: %{}})

  def find_run(opts \\ []) do
    root = Keyword.get(opts, :root) || Room.Index.repo_root()

    with {:ok, found} <- Room.Find.query("series-a"),
         {:ok, extract} <- Room.ChatDepth.extract(Room.ChatDepth.chat_rel(), root: root),
         {:ok, self} <- Room.ChatDepth.extract(Room.ChatDepth.self_rel(), root: root),
         {:ok, wing} <- Room.Tools.wing(Room.Find.wing_at("kai@mazel")) do
      hit = List.first(found[:hits] || [])
      overlap = Room.ChatDepth.overlap_of(extract, @need.wants)

      match = %{
        ok: true,
        handle: "kai@mazel",
        overlap: overlap,
        wants: @need.wants,
        extract: extract
      }

      scored =
        match
        |> Room.Score.decorate(need: @need, extract: extract, root: root)
        |> Map.merge(%{handle: "kai@mazel", peer: "kai@mazel"})

      claim = Room.Factors.score(%{fit: 1, heat: 1, fresh: 1, claim: true})
      self_scored = Room.ChatDepth.score_of(self, root: root)

      cond do
        is_nil(hit) or hit.handle != "kai@mazel" or not found.ok ->
          {:error, :find_miss}

        extract.status != "has" or overlap == [] ->
          {:error, :extract_miss}

        not wing.ok or wing.handle != "kai@mazel" ->
          {:error, :chat_miss}

        scored.unfit or is_nil(scored.why_need) or is_nil(scored.why_has) ->
          {:error, :why_miss}

        not claim.unfit or not self_scored.unfit ->
          {:error, :claim_fit}

        true ->
          pack = %{
            found: found,
            extract: extract,
            scored: scored,
            claim: claim,
            self: self_scored,
            wing: wing
          }

          {:ok, Map.put(pack, :lines, find_look(pack))}
      end
    end
  end
end
