defmodule Room.Need do
  @moduledoc """
  Need seed (ask + hard TTL + shape) and the `@mazel` discovery sink.

  Agents emit `{has, needs, curious}`.
  Has = proof only (artifacts, real trails). Claims and LinkedIn
  boasts are curious and never match. No human Need form.
  """

  @vibe ~r/\b(vibe|vibes|passionate|visionary|energy|wondering|maybe|feel like|thought leader)\b/i

  @default_ttl_hours 72
  @soft_ratio 0.5
  @drop_penalty 0.85

  @shapes [
    %{
      id: "founders-investors",
      ask: "Founders seeking investors and customers",
      wants: ["series-a", "cto"],
      ttl_hours: 168
    },
    %{
      id: "icp-pain",
      ask: "ICP pain: enterprise customer needs impl",
      wants: ["impl", "enterprise"],
      ttl_hours: 72
    },
    %{
      id: "package-x",
      ask: "N companies on package X need impl",
      wants: ["impl"],
      ttl_hours: 48
    }
  ]

  def shapes, do: @shapes

  def shape(id) when is_atom(id), do: shape(Atom.to_string(id))

  def shape(id) when is_binary(id) do
    Enum.find(@shapes, &(&1.id == id))
  end

  @doc "Cast a fixture Need. Hard TTL. Writes a stable Need slice."
  def seed(id, opts \\ []) do
    case shape(id) do
      nil ->
        {:error, :unknown_shape}

      spec ->
        now = Keyword.get(opts, :now) || ~U[2026-09-10 12:00:00Z]
        ttl = spec.ttl_hours
        as_of = DateTime.to_date(now) |> Date.to_iso8601()
        expires_at = DateTime.add(now, ttl * 3600, :second) |> DateTime.to_iso8601()
        root = Keyword.get(opts, :root) || repo_root()

        need = %{
          id: spec.id,
          kind: "need",
          shape: spec.id,
          ask: spec.ask,
          wants: spec.wants,
          topic: hd(spec.wants),
          title: "Need: #{spec.id}",
          body: spec.ask,
          as_of: as_of,
          ttl_hours: ttl,
          expires_at: expires_at,
          sink: "need@mazel"
        }

        path = write_seed_slice(root, need)
        {:ok, Map.merge(need, %{ok: true, path: path, need_id: spec.id})}
    end
  end

  def seed_all(opts \\ []) do
    Enum.reduce_while(@shapes, {:ok, []}, fn spec, {:ok, acc} ->
      case seed(spec.id, opts) do
        {:ok, need} -> {:cont, {:ok, acc ++ [need]}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  @doc """
  Agent emit. Splits `{has, needs, curious}`. Curious never matches.

  Same ship: resume-only stays curious. GitHub trail + check → Has.
  Contradiction → curious (never Has). Boast stays curious.
  """
  def emit(opts \\ []) do
    root = Keyword.get(opts, :root) || repo_root()
    handle = Keyword.get(opts, :handle) || "kai@mazel"

    with {:ok, needs} <- seed_all(opts),
         {:ok, resume_only} <-
           Room.Has.seed_resume(Room.Has.align_rel(),
             handle: handle,
             root: root,
             github: false
           ),
         {:ok, github} <-
           Room.Has.seed_github(Room.Has.github_rel(), handle: handle, root: root),
         {:ok, demoted} <-
           Room.Has.seed_resume(Room.Has.conflict_rel(), handle: handle, root: root) do
      cond do
        resume_only.status != "curious" ->
          {:error, :resume_alone_has}

        github.status != "has" ->
          {:error, :gh_not_has}

        demoted.status != "curious" ->
          {:error, :conflict_not_curious}

        true ->
          curious = write_curious(root, boast_fixture())
          has = has_evidence(root)

          {:ok,
           %{
             has: has,
             needs: needs,
             curious: [curious],
             resume_only: resume_only,
             github: github,
             aligned: github,
             demoted: demoted,
             source: "agent"
           }}
      end
    end
  end

  def classify(item) when is_map(item) do
    cond do
      wildcard?(item) ->
        :curious

      item[:kind] in ["curious", :curious, "claim", :claim, "wildcard", :wildcard] or
          item[:status] in ["curious", :curious, "claim", :claim, "wildcard", :wildcard] ->
        :curious

      item[:kind] in ["has", :has] or item[:status] in ["has", :has] ->
        :has

      item[:kind] in ["need", :need] ->
        :need

      is_binary(item[:ask] || item[:body]) ->
        classify(item[:ask] || item[:body])

      true ->
        :curious
    end
  end

  def classify(text) when is_binary(text) do
    down = String.downcase(String.trim(text))

    cond do
      down == "" ->
        :curious

      wildcard_text?(down) ->
        :curious

      String.starts_with?(down, "curious:") or String.starts_with?(down, "vibe:") or
          String.starts_with?(down, "claim:") or boast?(down) or vibe?(down) ->
        :curious

      String.starts_with?(down, "proof:") or String.starts_with?(down, "has:") ->
        :has

      String.starts_with?(down, "need:") or String.starts_with?(down, "wants:") or clear_hunt?(text) ->
        :need

      true ->
        :curious
    end
  end

  def curious?(item), do: classify(item) == :curious

  def match_has(need, opts \\ []) do
    {need, opts} = Room.NeedCheck.decorate(need, opts)
    now = Keyword.get(opts, :now) || DateTime.utc_now()
    root = Keyword.get(opts, :root) || repo_root()

    freshness = freshness(need, now)
    penalty = penalty(need, now)

    cond do
      curious?(need) ->
        scored = Room.Factors.score(%{fit: 0, heat: 0, fresh: 0, curious: true})

        {:ok,
         Map.merge(
           %{
             ok: false,
             error: "curious",
             skipped: true,
             hits: [],
             handle: nil,
             matches: [],
             curious: true,
             need_id: need_id_of(need),
             wants: List.wrap(need[:wants] || need["wants"]),
             provenance: "inference",
             freshness: :curious,
             penalty: 0.0
           },
           scored
         )}

      freshness == :expired ->
        scored = Room.Factors.score(%{fit: 0, heat: 0, fresh: 0, need_ttl: :expired})

        {:ok,
         Map.merge(
           %{
             ok: false,
             error: "expired",
             skipped: true,
             hits: [],
             handle: nil,
             matches: [],
             need_id: need_id_of(need),
             wants: List.wrap(need[:wants] || need["wants"]),
             freshness: :expired,
             need_ttl: :expired,
             penalty: 1.0
           },
           scored
         )}

      freshness == :stale and penalty >= @drop_penalty ->
        {:ok,
         %{
           ok: false,
           error: "stale",
           hits: [],
           handle: nil,
           matches: [],
           need_id: need_id_of(need),
           wants: List.wrap(need[:wants] || need["wants"]),
           freshness: :stale,
           penalty: penalty
         }}

      true ->
        {:ok, cards} = Room.Find.for_need(need, opts)
        jit = jit_has(need, root, now)
        opens = Room.Open.for_need(need, root: root, now: now)
        handles = merge_handles(cards, jit ++ opens)

        ranked =
          Room.Score.candidates(need, handles,
            root: root,
            now: now,
            overlap: fn handle -> pair_overlap(need, handle, root, cards) end
          )

        {:ok, pick_candidate(ranked, cards, jit, need, root, freshness, penalty)}
    end
  end

  defp pick_candidate([], cards, jit, need, _root, freshness, penalty) do
    %{
      ok: false,
      error: "no_has",
      handle: nil,
      hit: cards[:hit],
      hits: cards[:hits] || [],
      matches: [],
      jit: jit,
      overlap: [],
      need_id: need_id_of(need),
      wants: List.wrap(need[:wants] || need["wants"]),
      provenance: "artifact",
      freshness: freshness,
      penalty: penalty
    }
  end

  defp pick_candidate([best | _] = ranked, cards, jit, need, root, freshness, penalty) do
    best
    |> Map.merge(%{
      ok: true,
      error: nil,
      hit: cards[:hit],
      hits: cards[:hits] || [],
      matches: Enum.map(ranked, & &1.handle),
      jit: jit,
      need_id: need_id_of(need),
      wants: List.wrap(need[:wants] || need["wants"]),
      provenance: has_provenance(best.handle, root),
      freshness: freshness,
      penalty: penalty
    })
  end

  def look_line(need, match) do
    listed = Enum.join(match[:matches] || [], ",")
    "ok  need=#{need.id}  matches=[#{listed}]"
  end

  def freshness(need, now \\ nil) do
    now = now || DateTime.utc_now()

    cond do
      expired?(need, now) -> :expired
      penalty(need, now) > 0.0 -> :stale
      true -> :fresh
    end
  end

  def penalty(need, now \\ nil) do
    now = now || DateTime.utc_now()

    cond do
      expired?(need, now) ->
        1.0

      true ->
        ttl = need[:ttl_hours] || need["ttl_hours"] || @default_ttl_hours
        age = age_hours(need, now)
        ratio = if ttl > 0, do: age / ttl, else: 0.0

        if ratio <= @soft_ratio do
          0.0
        else
          Float.round((ratio - @soft_ratio) / (1.0 - @soft_ratio), 2) |> min(0.99)
        end
    end
  end

  def ttl_look(need, match) do
    listed = Enum.join(match[:matches] || [], ",")
    ttl = ttl_label(need)
    pen = match[:penalty] || 0.0

    case match[:freshness] || freshness(need) do
      :fresh ->
        "ok  need=fresh  ttl=#{ttl}  matches=[#{listed}]"

      :stale ->
        if match[:ok] do
          "ok  need=stale  penalty=#{fmt_pen(pen)}  matches=[#{listed}]"
        else
          "ok  need=stale  penalty=#{fmt_pen(pen)}  dropped"
        end

      :expired ->
        "ok  need=expired  matches=[]"

      _ ->
        look_line(need, match)
    end
  end

  def ttl_demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} -> {given, false}
        :error -> {ttl_demo_root(), true}
      end

    try do
      ttl_demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  @doc """
  Double magic. Every has×need match prints both reasons.
  Need-side: found who I needed. Has-side: they needed what I have.
  """
  def pair_look(need, match) do
    handle = match[:handle]

    if handle do
      overlap = match[:overlap] || pair_overlap(need, handle, repo_root(), %{})
      wants = match[:wants] || List.wrap(need[:wants] || need["wants"])

      [
        "match  #{handle}",
        "need   found who I needed: #{need_phrase(wants)}",
        "has    they needed what I have: #{has_phrase(overlap, wants)}",
        "ok  #{Room.Find.mazel_d(handle)}"
      ]
    else
      []
    end
  end

  def look(need, match) do
    ["need  #{need.id}  #{need.ask}", look_line(need, match)] ++ pair_look(need, match)
  end

  def split_look(matches, curious \\ [], pack \\ %{}) do
    pair_lines =
      matches
      |> List.wrap()
      |> Enum.filter(& &1[:ok])
      |> Enum.flat_map(fn match ->
        need = %{id: match[:need_id], wants: match[:wants] || []}
        [look_line(need, match)] ++ pair_look(need, match)
      end)

    skipped =
      curious
      |> List.wrap()
      |> Enum.count(fn row ->
        is_map(row) and (row[:skipped] == true or row[:error] == "curious" or curious?(row))
      end)
      |> then(fn n -> if n == 0, do: length(List.wrap(curious)), else: n end)

    moat =
      []
      |> Kernel.++(if pack[:resume_only], do: [Room.Has.resume_only_look(pack.resume_only)], else: [])
      |> Kernel.++(if pack[:demoted], do: [Room.Has.contradict_look(pack.demoted)], else: [])
      |> Kernel.++(
        if pack[:github],
          do: [Room.Has.gh_check_look(pack.github)],
          else: if(pack[:aligned], do: [Room.Has.corroborate_look(pack.aligned)], else: [])
      )

    ["ok  claim→curious  skipped"] ++ moat ++ pair_lines ++
      if(skipped > 0, do: ["ok  curious≠has  skipped=#{skipped}"], else: [])
  end

  defp need_id_of(need) do
    need[:id] || need["id"] || need[:need_id] || need["need_id"]
  end

  defp pair_overlap(_need, nil, _root, _cards), do: []

  defp pair_overlap(need, handle, root, cards) do
    if handle == cards[:handle] and is_list(cards[:overlap]) do
      cards.overlap
    else
      wants = List.wrap(need[:wants] || need["wants"])
      has = Room.Has.skills_for(handle, root: root)
      Enum.filter(wants, &(&1 in has))
    end
  end

  defp need_phrase(wants) do
    wants
    |> List.wrap()
    |> Enum.map(fn
      "cto" -> "CTO"
      id -> to_string(id)
    end)
    |> Enum.join(" ")
  end

  defp has_phrase(overlap, wants) do
    pick = List.first(overlap) || List.first(wants) || "has"
    to_string(pick)
  end

  defp has_provenance(nil, _root), do: "artifact"

  defp has_provenance(handle, root) do
    local = handle |> to_string() |> String.split("@") |> hd()
    path = Path.join(Room.Index.dir(root, "has"), local <> ".md")

    cond do
      File.regular?(path) ->
        text = File.read!(path)

        cond do
          Regex.match?(~r/^provenance:\s*(\S+)/m, text) ->
            [_, p] = Regex.run(~r/^provenance:\s*(\S+)/m, text)
            p

          Regex.match?(~r/^source:\s*(upload|web)\s*$/m, text) ->
            "artifact"

          Regex.match?(~r/^source:\s*(github|mcp)\s*$/m, text) ->
            "connector"

          true ->
            "artifact"
        end

      true ->
        "artifact"
    end
  end

  defp jit_has(need, root, now) do
    root
    |> Room.Index.load("has")
    |> Enum.filter(&(to_string(&1[:kind] || "") == "has"))
    |> Room.Index.live(now)
    |> then(&Room.Index.rank(need, &1))
  end

  defp wildcard?(item) when is_map(item) do
    item[:wildcard] == true or
      wildcard_wants?(item[:wants] || item["wants"]) or
      wildcard_text?(item[:ask] || item[:body] || item["ask"] || item["body"] || "")
  end

  defp wildcard?(_), do: false

  defp wildcard_wants?(wants) do
    Enum.any?(List.wrap(wants), &wildcard_token?/1)
  end

  defp wildcard_token?(token) do
    token
    |> to_string()
    |> String.trim()
    |> String.downcase()
    |> then(&(&1 in ["*", "wildcard", "any", "anyone"]))
  end

  defp wildcard_text?(text) when is_binary(text) do
    down = String.downcase(String.trim(text))
    down in ["*", "wildcard", "anyone", "any"] or String.starts_with?(down, "wildcard:")
  end

  defp wildcard_text?(_), do: false

  defp vibe?(text), do: Regex.match?(@vibe, text)

  defp boast?(text) do
    Regex.match?(~r/^(i am |i'm |as a )/i, text) or
      Regex.match?(~r/\b(thought leader|visionary|linkedin|self-report|boast)\b/i, text)
  end

  defp clear_hunt?(text) do
    Enum.any?(@shapes, fn spec ->
      spec.id == text or spec.ask == text or String.contains?(text, spec.ask)
    end)
  end

  defp boast_fixture do
    %{
      id: "linkedin-boast",
      kind: "curious",
      status: "curious",
      ask: "I am a passionate visionary thought leader in series-a",
      wants: ["series-a"],
      topic: "series-a",
      title: "Curious boast",
      body: "claim: I am a passionate visionary thought leader."
    }
  end

  defp has_evidence(root) do
    root
    |> Room.Index.load("has")
    |> Enum.filter(&(to_string(&1[:kind] || "") == "has"))
  end

  defp write_curious(root, item) do
    folder = Room.Index.dir(root, "curious")
    File.mkdir_p!(folder)
    path = Path.join(folder, item.id <> ".md")

    File.write!(path, """
    ---
    id: #{item.id}
    kind: curious
    status: curious
    topic: #{item.topic}
    ---

    # Curious #{item.id}

    #{item.body}
    """)

    Map.put(item, :path, path)
  end

  defp merge_handles(cards, jit) do
    from_cards =
      (cards[:hits] || [])
      |> Enum.map(& &1.handle)

    from_jit =
      jit
      |> Enum.map(& &1.handle)
      |> Enum.filter(&(is_binary(&1) and String.contains?(&1, "@") and not String.starts_with?(&1, "need@")))

    (from_cards ++ from_jit)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp write_seed_slice(root, need) do
    folder = Room.Index.dir(root, "need")
    File.mkdir_p!(folder)
    path = Path.join(folder, need.id <> ".md")
    File.write!(path, seed_markdown(need))
    path
  end

  defp seed_markdown(need) do
    wants = Enum.join(need.wants, ", ")

    """
    ---
    id: #{need.id}
    kind: need
    topic: #{need.topic}
    as_of: #{need.as_of}
    ttl_hours: #{need.ttl_hours}
    expires_at: #{need.expires_at}
    handle: #{need.sink}
    ---

    # Need #{need.id}

    #{need.ask}

    wants: #{wants}
    """
  end


  def discovery_sink?(%{id: id}), do: discovery_id?(id)

  def discovery_sink?(raw) when is_binary(raw) do
    case Room.Wings.parse_handle(raw) do
      {:ok, handle} -> discovery_id?(handle.id)
      _ -> false
    end
  end

  def discovery_id?(id) when is_binary(id) do
    id in ~w(mazel@mazel need@mazel mazel@mazel.ai need@mazel.ai mazel@mazal.ai)
  end

  def dispatch(body, opts \\ []) when is_binary(body) do
    body = String.trim(body)

    if body == "" do
      {:error, :empty_text}
    else
      ttl = Room.Index.ttl_hours(Keyword.get(opts, :ttl_hours), @default_ttl_hours)
      now = Keyword.get(opts, :now) || DateTime.utc_now() |> DateTime.truncate(:second)
      as_of = DateTime.to_date(now) |> Date.to_iso8601()
      expires_at = DateTime.add(now, ttl * 3600, :second) |> DateTime.to_iso8601()
      topic = Keyword.get(opts, :topic) || Room.Index.topic_from(body)
      suffix = Keyword.get(opts, :id_suffix) || random_id()
      need_id = Keyword.get(opts, :need_id) || "need-#{topic}-#{suffix}"
      sink = Keyword.get(opts, :sink, "need@mazel")
      root = Keyword.get(opts, :root) || repo_root()

      need = %{
        id: need_id,
        kind: "need",
        topic: topic,
        title: "Need: #{topic}",
        body: body,
        as_of: as_of,
        ttl_hours: ttl,
        expires_at: expires_at,
        sink: sink
      }

      path = Room.Index.write(root, need)
      matches = match(need, root, now)
      actor = Keyword.get(opts, :actor) || Keyword.get(opts, :from)
      badge = mint_badge(need, matches, actor)

      {:ok,
       Map.merge(need, %{
         ok: true,
         need_id: need_id,
         path: path,
         matches: matches,
         badge: badge,
         expired: false
       })}
    end
  end

  def match(need, root \\ nil, now \\ nil) do
    root = root || repo_root()
    now = now || DateTime.utc_now()

    if expired?(need, now) do
      []
    else
      knows = Room.Index.load(root, "know")
      opens = root |> Room.Index.load("open") |> Room.Index.live(now)
      Room.Index.rank(need, knows ++ opens)
    end
  end

  def expired?(need, now), do: Room.Index.expired?(need, now)
  def topic_from(text), do: Room.Index.topic_from(text)
  def repo_root, do: Room.Index.repo_root()

  defp ttl_demo_on(root) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    with {:ok, fresh_need} <- seed("founders-investors", root: root, now: now),
         {:ok, fresh} <- match_has(fresh_need, root: root, now: now) do
      stale_need =
        fresh_need
        |> Map.put(:as_of, Date.add(DateTime.to_date(now), -5) |> Date.to_iso8601())
        |> Map.put(:expires_at, DateTime.add(now, 48 * 3600, :second) |> DateTime.to_iso8601())

      dead_need =
        fresh_need
        |> Map.put(:expires_at, DateTime.add(now, -3600, :second) |> DateTime.to_iso8601())

      {:ok, stale} = match_has(stale_need, root: root, now: now)
      {:ok, dead} = match_has(dead_need, root: root, now: now)

      lines = [ttl_look(fresh_need, fresh), ttl_look(stale_need, stale), ttl_look(dead_need, dead)]

      cond do
        not fresh.ok or fresh.handle != "kai@mazel" or fresh.freshness != :fresh ->
          {:error, :fresh_miss}

        stale.freshness != :stale or stale.penalty <= 0 ->
          {:error, :stale_miss}

        dead.matches != [] or dead.freshness != :expired ->
          {:error, :expired_matched}

        true ->
          {:ok, %{fresh: fresh, stale: stale, expired: dead, lines: lines}}
      end
    end
  end

  defp ttl_demo_root do
    root = Path.join(System.tmp_dir!(), "mazel-need-ttl-#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, "index/needs"))
    File.mkdir_p!(Path.join(root, "index/has"))

    Enum.each(["kai.md", "nova.md"], fn name ->
      File.cp!(
        Path.join(repo_root(), Path.join("index/has", name)),
        Path.join(root, Path.join("index/has", name))
      )
    end)

    root
  end

  defp age_hours(need, now) do
    case born_at(need) do
      nil -> 0.0
      born -> DateTime.diff(now, born, :second) / 3600.0
    end
  end

  defp born_at(need) do
    case need[:expires_at] || need["expires_at"] do
      iso when is_binary(iso) ->
        case DateTime.from_iso8601(iso) do
          {:ok, exp, _} ->
            ttl = need[:ttl_hours] || need["ttl_hours"] || @default_ttl_hours
            DateTime.add(exp, -ttl * 3600, :second)

          _ ->
            from_as_of(need)
        end

      _ ->
        from_as_of(need)
    end
  end

  defp from_as_of(need) do
    case need[:as_of] || need["as_of"] do
      iso when is_binary(iso) ->
        case Date.from_iso8601(iso) do
          {:ok, date} -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp ttl_label(need) do
    need[:expires_at] || need["expires_at"] || "#{need[:ttl_hours] || need["ttl_hours"] || @default_ttl_hours}h"
  end

  defp fmt_pen(n) when is_float(n), do: :erlang.float_to_binary(n, decimals: 2)
  defp fmt_pen(n), do: to_string(n)

  defp mint_badge(_need, _matches, nil), do: nil

  defp mint_badge(need, matches, actor) do
    case Room.Badge.from_need_matches(need, matches, actor) do
      {:ok, badge} -> badge
      _ -> nil
    end
  end

  defp random_id do
    :crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)
  end
end
