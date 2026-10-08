defmodule Room.Score do
  @moduledoc """
  JIT Need×Has score strip.

  Gathers structured factor **inputs** (I/O stays here). The
  Factor registry (`Room.Factors`) is a pure function over those
  inputs. LLM never ranks. Curious / claim → forced unfit.
  Stale or cold Has still paths.
  """

  @need %{id: "score-strip", kind: "need", wants: ["series-a"]}

  def need, do: @need

  @doc """
  Attach named factor inputs + composed `score`. heat input is
  `1` (vouch and/or optional Gmail prior) or `0`. fresh is `1`
  or `0`. Curious/claim is unfit and never matches.
  """
  def decorate(match, opts \\ []) when is_map(match) do
    handle = match[:handle]
    scored = of(handle, match, opts)

    match
    |> Map.merge(scored)
    |> Map.merge(why_fields(opts[:need], match))
    |> then(fn rec ->
      if rec[:unfit], do: refuse(rec), else: rec
    end)
  end

  @doc """
  Double-magic why from structured overlap ids. Not LLM prose.
  Unfit / curious never get a why.
  """
  def why_fields(need, match) when is_map(match) do
    cond do
      match[:unfit] == true or match[:ok] == false or is_nil(match[:handle]) ->
        %{why_need: nil, why_has: nil}

      true ->
        overlap = List.wrap(match[:overlap])

        wants =
          cond do
            match[:wants] not in [nil, []] -> List.wrap(match[:wants])
            is_map(need) -> List.wrap(need[:wants] || need["wants"])
            true -> []
          end
        has_id = List.first(overlap)
        need_id = Enum.find(wants, &(&1 in overlap)) || List.first(wants)

        if is_nil(has_id) and is_nil(need_id) do
          %{why_need: nil, why_has: nil}
        else
          %{why_need: need_id || has_id, why_has: has_id || need_id}
        end
    end
  end

  def why_fields(_, _), do: %{why_need: nil, why_has: nil}

  @doc """
  Need×Has handles → candidates with named factors composed to score.
  Curious / claim / wildcard / no-overlap never enter the list.
  New factor plugins change `Room.Factors` only — not this loop.
  """
  def candidates(need, handles, opts \\ []) do
    overlap_of = opts[:overlap] || fn _ -> [] end

    handles
    |> List.wrap()
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.map(fn handle ->
      overlap = overlap_of.(handle)
      {handle, overlap}
    end)
    |> Enum.reject(fn {_handle, overlap} -> overlap == [] end)
    |> Enum.map(fn {handle, overlap} ->
      base = %{
        ok: true,
        handle: handle,
        overlap: overlap,
        need_id: need[:id] || need[:need_id] || need["id"],
        wants: List.wrap(need[:wants] || need["wants"])
      }

      base
      |> Room.Age.decorate(Keyword.take(opts, [:root, :now]) ++ [overlap: overlap])
      |> decorate(Keyword.take(opts, [:root, :now]) ++ [need: need])
    end)
    |> Enum.reject(&(&1[:unfit] == true or &1[:ok] == false))
    |> Enum.sort_by(&{-(&1[:score] || 0), &1[:handle] || ""})
  end

  def of(handle, match \\ %{}, opts \\ []) do
    inputs = gather(handle, match, opts)
    result = Room.Factors.score(inputs)
    heat_id = if result.inputs.heat == 1, do: "has", else: "0"

    %{
      fit: result.inputs.fit,
      heat: result.inputs.heat,
      vouch_heat: heat_id,
      fresh: result.inputs.fresh,
      trail: Map.get(result.inputs, :trail, 0),
      check: Map.get(result.inputs, :check, 0),
      freshness_penalty: 1 - result.inputs.fresh,
      score: result.score,
      unfit: result.unfit,
      inputs: result.inputs,
      factors: result.factors
    }
  end

  def look(%{unfit: true}), do: "error  claim→curious  unfit=true"

  def look(rec) when is_map(rec) do
    peer = rec[:handle] || rec[:peer]
    named = rec[:inputs] || rec[:factors] || %{}
    "ok  need×has  peer=#{peer}  inputs=#{Room.Factors.format_inputs(named)}  score=#{fmt(rec[:score] || 0)}"
  end

  def look(_), do: "ok  need×has  peer=  inputs={fit:0,heat:0,fresh:0}  score=0"

  @doc """
  GH proof LOOK. Named trail/check inputs — not a find sidecar.
  Resume-alone is curious (`trail=0`). GH check lifts (`trail=1`).
  """
  def look_trail(%{unfit: true} = rec) do
    peer = rec[:handle] || rec[:peer] || "kai@mazel"
    named = rec[:inputs] || rec[:factors] || %{}

    "ok  resume-only  peer=#{peer}  inputs=#{Room.Factors.format_inputs(named, :all)}  curious  unfit=true"
  end

  def look_trail(rec) when is_map(rec) do
    peer = rec[:handle] || rec[:peer]
    named = rec[:inputs] || rec[:factors] || %{}

    "ok  gh+check  peer=#{peer}  inputs=#{Room.Factors.format_inputs(named, :all)}  score=#{fmt(rec[:score] || 0)}"
  end

  def look_trail(_),
    do: "ok  resume-only  peer=kai@mazel  inputs={fit:0,heat:0,fresh:0,trail:0,check:0}  curious  unfit=true"

  @doc """
  Double-magic LOOK. Structured why ids + factor inputs. Unfit has no why.
  """
  def look_why(%{unfit: true}), do: [look(%{unfit: true})]

  def look_why(rec) when is_map(rec) do
    peer = rec[:handle] || rec[:peer]
    named = rec[:inputs] || rec[:factors] || %{}
    why_need = rec[:why_need]
    why_has = rec[:why_has]

    if is_nil(why_need) or is_nil(why_has) do
      [look(rec)]
    else
      [
        "ok  need×has  peer=#{peer}  score=#{fmt(rec[:score] || 0)}",
        "why  need=#{why_need}  # found who I needed",
        "why  has=#{why_has}   # they needed what I have",
        "ok  inputs=#{Room.Factors.format_inputs(named)}"
      ]
    end
  end

  def look_why(_), do: [look(%{unfit: true})]

  @doc """
  Hot: vouched + fresh → score=2. Cold: no vouch + stale → score=0.
  Claim/curious → unfit. Isolated tmp.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-score-#{System.unique_integer([:positive])}")
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

    with {:ok, hot} <- hot_beat(root, dest, now),
         {:ok, cold} <- cold_beat(root, dest, now) do
      claim = Room.Factors.score(%{fit: 1, heat: 1, fresh: 1, claim: true})

      if hot.score > cold.score and hot.ok and cold.ok and claim.unfit do
        {:ok,
         %{
           hot: hot,
           cold: cold,
           claim: claim,
           lines: [look(hot), look(cold), look(claim)]
         }}
      else
        {:error, :score_order}
      end
    end
  end

  @doc """
  Structured GH proof → Factor inputs. Resume-alone curious
  (`trail=0`, `check=0`). GH + check → `trail=1` and lifts heat.
  Isolated tmp. Does not rewrite committed Has.
  """
  def trail_demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-trail-score-#{System.unique_integer([:positive])}")
          File.mkdir_p!(Path.join(path, "index/has"))
          {path, true}
      end

    try do
      trail_demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp trail_demo_on(root) do
    now = Room.Age.demo_now()
    dest = Path.join(root, "index/has/kai.md")
    File.mkdir_p!(Path.dirname(dest))

    with {:ok, resume} <- resume_trail_beat(root, dest, now),
         {:ok, gh} <- gh_trail_beat(root, dest, now) do
      if resume.unfit and resume.trail == 0 and resume.check == 0 and
           gh.ok and gh.trail == 1 and gh.check == 1 and gh.score == 2 do
        {:ok,
         %{
           resume: resume,
           gh: gh,
           lines: [look_trail(resume), look_trail(gh)]
         }}
      else
        {:error, :trail_score}
      end
    end
  end

  defp resume_trail_beat(root, dest, now) do
    File.rm(dest)

    with {:ok, curious} <-
           Room.Has.seed_resume(Room.Has.align_rel(), handle: "kai@mazel", root: root, github: false) do
      if curious.status != "curious" do
        {:error, :resume_not_curious}
      else
        stamp_as_of_if!(dest, now)
        scored = trail_beat(root, now)
        {:ok, scored}
      end
    end
  end

  defp gh_trail_beat(root, dest, now) do
    File.cp!(Path.join(Room.Index.repo_root(), "index/has/kai.md"), dest)

    with {:ok, gh} <-
           Room.Has.seed_github(Room.Has.github_rel(), handle: "kai@mazel", root: root) do
      if gh.status != "has" or Room.Has.trail_for("kai@mazel", root: root) != 1 or
           Room.Has.check_for("kai@mazel", root: root) != 1 do
        {:error, :gh_not_has}
      else
        stamp_as_of!(dest, Date.to_iso8601(DateTime.to_date(now)))
        scored = trail_beat(root, now)

        if scored.unfit do
          {:error, :gh_unfit}
        else
          {:ok, Map.put(scored, :ok, true)}
        end
      end
    end
  end

  defp trail_beat(root, now) do
    match = %{handle: "kai@mazel", overlap: ["series-a"]}

    "kai@mazel"
    |> of(match, root: root, now: now, need: @need)
    |> Map.merge(%{handle: "kai@mazel", peer: "kai@mazel"})
  end

  defp hot_beat(root, dest, now) do
    File.cp!(Path.join(Room.Index.repo_root(), "index/has/kai.md"), dest)

    with {:ok, _} <-
           Room.Has.seed_resume(Room.Has.align_rel(), handle: "kai@mazel", root: root, github: false),
         {:ok, _} <- Room.Has.vouch("ariel@mazel", "kai@mazel", root: root) do
      stamp_as_of!(dest, Date.to_iso8601(DateTime.to_date(now)))
      match_beat(root, now)
    end
  end

  defp cold_beat(root, dest, now) do
    File.cp!(Path.join(Room.Index.repo_root(), "index/has/kai.md"), dest)
    stale_on = Date.add(DateTime.to_date(now), -Room.Age.demo_stale_days()) |> Date.to_iso8601()
    stamp_as_of!(dest, stale_on)
    match_beat(root, now)
  end

  defp match_beat(root, now) do
    case Room.Need.match_has(@need, root: root, now: now) do
      {:ok, match} ->
        scored = decorate(match, root: root, now: now, need: @need)
        if scored.ok, do: {:ok, scored}, else: {:error, :no_has}

      other ->
        other
    end
  end

  defp gather(handle, match, opts) do
    root_opts = score_opts(opts)
    need = opts[:need]
    age = if is_binary(handle), do: Room.Age.of(handle, root_opts), else: %{label: "stale"}
    heat_n = if is_binary(handle), do: Room.Has.heat_for(handle, root_opts), else: 0.0
    vouch_bit = Room.HeatCompose.vouch_bit(heat_n)
    gmail_bit = Room.HeatCompose.gmail_bit(opts[:gmail] || opts[:gmail_prior])

    trail = if is_binary(handle), do: Room.Has.trail_for(handle, root_opts), else: 0
    check = if is_binary(handle), do: Room.Has.check_for(handle, root_opts), else: 0

    base = %{
      fit: fit_of(match),
      heat: Room.HeatCompose.heat(vouch_bit, gmail_bit),
      fresh: if(age.label == "fresh", do: 1, else: 0),
      trail: trail,
      check: check,
      claim: claim_flag(match),
      curious: curious_flag(match, need) or
        (is_binary(handle) and Room.Has.curious_slice?(handle, root_opts)),
      wildcard: wildcard_flag(match, need),
      need_ttl: need_ttl_of(need, opts)
    }

    merge_extract(base, match, opts)
  end

  # chat_depth extract fills named inputs. Quant still ranks.
  # Chat text / BM25 never join. trail/check stay 0 unless GH.
  defp merge_extract(base, match, opts) do
    rec = opts[:extract] || match[:extract]

    if chat_depth_extract?(rec) do
      wants = if is_map(opts[:need]), do: opts[:need][:wants], else: nil
      Map.merge(base, Room.ChatDepth.factor_inputs(rec, wants || Room.ChatDepth.need().wants))
    else
      base
    end
  end

  defp chat_depth_extract?(%{source: "chat_depth"}), do: true
  defp chat_depth_extract?(%{"source" => "chat_depth"}), do: true
  defp chat_depth_extract?(_), do: false

  defp need_ttl_of(need, opts) do
    now = opts[:now]

    cond do
      not is_map(need) -> nil
      Room.Need.freshness(need, now) == :expired -> :expired
      true -> Room.Need.freshness(need, now)
    end
  end

  defp claim_flag(match) do
    match[:claim] == true or
      match[:kind] in [:claim, "claim"] or
      match[:status] in [:claim, "claim"] or
      match[:error] == "claim"
  end

  defp curious_flag(match, need) do
    match[:curious] == true or
      match[:kind] in [:curious, "curious"] or
      match[:status] in [:curious, "curious"] or
      match[:error] == "curious" or
      match[:freshness] == :curious or
      (is_map(need) and Room.Need.curious?(need))
  end

  defp wildcard_flag(match, need) do
    match[:wildcard] == true or
      match[:kind] in [:wildcard, "wildcard"] or
      match[:status] in [:wildcard, "wildcard"] or
      match[:error] == "wildcard" or
      wildcard_wants?(match[:wants]) or
      (is_map(need) and wildcard_wants?(need[:wants] || need["wants"]))
  end

  defp wildcard_wants?(wants) do
    Enum.any?(List.wrap(wants), fn token ->
      down = token |> to_string() |> String.trim() |> String.downcase()
      down in ["*", "wildcard", "any", "anyone"]
    end)
  end

  defp refuse(rec) do
    rec
    |> Map.put(:ok, false)
    |> Map.put(:error, rec[:error] || "unfit")
    |> Map.put(:skipped, true)
    |> Map.put(:handle, nil)
    |> Map.put(:matches, [])
    |> Map.put(:hits, [])
    |> Map.put(:why_need, nil)
    |> Map.put(:why_has, nil)
  end

  defp fit_of(match) do
    if List.wrap(match[:overlap]) != [], do: 1, else: 0
  end

  defp fmt(n) when is_float(n) do
    if n == Float.floor(n), do: trunc(n), else: :erlang.float_to_binary(n, decimals: 2)
  end

  defp fmt(n) when is_integer(n), do: n
  defp fmt(_), do: 0

  defp score_opts(opts) do
    []
    |> then(&if opts[:root], do: Keyword.put(&1, :root, opts[:root]), else: &1)
    |> then(&if opts[:now], do: Keyword.put(&1, :now, opts[:now]), else: &1)
  end

  defp stamp_as_of!(path, iso) do
    text = File.read!(path)
    File.write!(path, Regex.replace(~r/^as_of:\s*\S+/m, text, "as_of: #{iso}"))
  end

  defp stamp_as_of_if!(path, now) do
    if File.regular?(path) do
      stamp_as_of!(path, Date.to_iso8601(DateTime.to_date(now)))
    end
  end

  @doc """
  Double-magic why on a real Need×Has match. Claim/unfit has no why.
  Isolated tmp.
  """
  def why_demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-why-#{System.unique_integer([:positive])}")
          File.mkdir_p!(Path.join(path, "index/has"))
          {path, true}
      end

    try do
      why_demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp why_demo_on(root) do
    now = Room.Age.demo_now()
    dest = Path.join(root, "index/has/kai.md")
    File.mkdir_p!(Path.dirname(dest))

    with {:ok, hot} <- hot_beat(root, dest, now) do
      claim = Room.Factors.score(%{fit: 1, heat: 1, fresh: 1, claim: true})
      refused = why_fields(@need, Map.merge(claim, %{unfit: true, handle: nil, ok: false}))

      if hot.ok and hot.why_need == "series-a" and hot.why_has == "series-a" and
           is_nil(refused.why_need) and is_nil(refused.why_has) do
        {:ok,
         %{
           hot: hot,
           claim: claim,
           lines: look_why(hot) ++ look_why(claim)
         }}
      else
        {:error, :why_miss}
      end
    end
  end
end
