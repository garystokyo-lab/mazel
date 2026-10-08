defmodule Room.Has do
  @moduledoc """
  Outside-knows seed. Has is proof only.

  Upload is never auto-strong Has. MVP weight is a GitHub trail.
  Flow: upload → candidate → cross-examine vs GH/transcripts →
  pass→Has / fail→curious. Resume alone is insufficient.
  Empty repos are still prompt-checked (empty/contradict → curious).
  `source=upload` is a provenance tag, not a trust freebie.
  Fake resumes expected. Claims never enter Has.

  Rank: artifact > connector > chat > inference.
  Web fetch and GH/MCP trails can be strong after distill.
  Chat = medium. High-turn chat depth (`source=chat_depth`) lands
  in the chat band — mine turns for **proof factor inputs**, then
  quant ranks. Not chat-BM25 / message-text similarity.
  Self-report / inference alone stays curious unless a trail
  backs it. Claims never enter Has.
  """

  @skill_ids ~w(series-a cto impl enterprise find chat direct)
  @domain_skills ~w(series-a cto impl enterprise)
  @max_about 3
  @max_links 5
  @as_of "2026-09-11"

  @web_fixtures %{
    "https://kai.example" => "fixtures/has/kai.html",
    "https://kai.example/" => "fixtures/has/kai.html"
  }

  @github_fixtures %{
    "https://github.com/kai" => "priv/fixtures/kai.github.txt",
    "https://github.com/kai/" => "priv/fixtures/kai.github.txt"
  }

  @fluff ~r/\b(passionate|visionary|thought[- ]leader|world-class|ai-powered|synergy|ninja|rockstar|guru)\b/i

  def skill_ids, do: @skill_ids
  def domain_skills, do: @domain_skills
  def fixture_url, do: "https://kai.example"
  def github_rel, do: "priv/fixtures/kai.github.txt"
  def github_json_rel, do: "priv/fixtures/kai.github.json"
  def github_empty_rel, do: "priv/fixtures/kai.github.empty.txt"
  def conflict_rel, do: "priv/fixtures/kai.resume.conflict.txt"
  def align_rel, do: "priv/fixtures/kai.resume.align.txt"
  def fluff_rel, do: "priv/fixtures/fluff.resume.txt"
  def pdf_rel, do: "priv/fixtures/kai.resume.pdf"

  def seed(url, opts \\ []) when is_binary(url) do
    url = String.trim(url)
    fetch = Keyword.get(opts, :fetch, &fetch/1)

    cond do
      url == "" ->
        {:error, :empty_url}

      true ->
        case fetch.(url) do
          {:ok, html} ->
            case distill(html, url) do
              {:ok, has} -> {:ok, has}
              other -> other
            end

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  def seed_card(raw, opts \\ []) do
    with {:ok, found} <- Room.Cards.lookup(raw),
         url when is_binary(url) and url != "" <- website_of(found),
         {:ok, has} <- seed(url, opts) do
      has = has |> Map.put(:handle, found.id) |> persist_has(found, opts)
      {:ok, has}
    else
      {:error, _} = err -> err
      _ -> {:error, :no_website}
    end
  end

  @doc """
  GitHub trail → candidate → examine. Fixture path or github.com URL.
  Promotes to Has when proof aligns (or no conflicting trail).
  """
  def seed_github(raw, opts \\ []) when is_binary(raw) do
    seed_artifact(raw, Keyword.put(opts, :source, "github"))
  end

  @doc """
  MCP / non-AI artifact trail. Same examine as GitHub.
  Claims never Has. Connector provenance.
  """
  def seed_mcp(raw, opts \\ []) when is_binary(raw) do
    seed_artifact(raw, Keyword.put(opts, :source, "mcp"))
  end

  @doc """
  Resume/PDF upload. Lands as candidate. source=upload is provenance
  only. Trail check decides Has vs curious. Fluff never Has.
  """
  def seed_resume(raw, opts \\ []) when is_binary(raw) do
    seed_artifact(raw, Keyword.put(opts, :source, "upload"))
  end

  def strength_for("upload"), do: "candidate"
  def strength_for(source), do: strength_of_prov(provenance_for(source))

  def provenance_for(source) when source in ["upload", "web"], do: "artifact"
  def provenance_for(source) when source in ["github", "mcp"], do: "connector"
  # chat_depth = high-turn extract of structured Has. Same band as chat.
  # Still not a match factor — Factors scores proof inputs only.
  def provenance_for(source) when source in ["chat", "vouch", "chat_depth"], do: "chat"
  # LinkedIn zip/export is self-report scaffolding. Never a trail.
  def provenance_for(source) when source in ["inference", "agent", "linkedin"], do: "inference"
  def provenance_for(_), do: "inference"

  def rank_of("artifact"), do: 3
  def rank_of("connector"), do: 2
  # chat / chat_depth beat self-report (inference). Not BM25.
  def rank_of("chat"), do: 1
  def rank_of("inference"), do: 0
  def rank_of(_), do: 0

  @heat_has 2.0
  @heat_plain 1.0

  def heat_has, do: @heat_has
  def heat_plain, do: @heat_plain

  @doc """
  Numeric heat. Vouched Has or GitHub/connector proof is hotter.
  Resume-alone / curious stays 1.0. Find rank is fit × heat.
  """
  def heat_of(rec) when is_map(rec) do
    heat = rec[:heat] || rec["heat"]
    source = rec[:source] || rec["source"]

    cond do
      to_string(heat) == "has" -> @heat_has
      to_string(source) == "vouch" -> @heat_has
      trail?(rec) -> @heat_has
      true -> @heat_plain
    end
  end

  def heat_of(_), do: @heat_plain

  @doc "1 when Has is GitHub/connector proof. 0 when curious or resume-only."
  def trail_for(raw, opts \\ []) do
    meta = slice_meta(raw, opts)
    if trail?(meta), do: 1, else: 0
  end

  @doc """
  1 when a GitHub trail was prompt-checked and promoted to Has.
  Structured score input. Resume-only / curious is 0.
  """
  def check_for(raw, opts \\ []) do
    meta = slice_meta(raw, opts)
    if check?(meta), do: 1, else: 0
  end

  @doc "True when the Has slice is curious (resume-alone, conflict, claim)."
  def curious_slice?(raw, opts \\ []) do
    meta = slice_meta(raw, opts)
    status = meta[:status] || meta["status"]
    kind = meta[:kind] || meta["kind"]

    to_string(status) in ["curious", "claim"] or to_string(kind) in ["curious", "claim"]
  end

  defp trail?(rec) when is_map(rec) do
    status = rec[:status] || rec["status"]
    source = rec[:source] || rec["source"]
    provenance = rec[:provenance] || rec["provenance"]

    to_string(status) == "has" and
      (to_string(source) in ["github", "mcp"] or to_string(provenance) == "connector")
  end

  defp trail?(_), do: false

  defp check?(rec) when is_map(rec) do
    check = rec[:check] || rec["check"]
    source = rec[:source] || rec["source"]

    cond do
      to_string(check) in ["1", "true", "has"] -> true
      trail?(rec) and to_string(source) in ["github", "mcp"] -> true
      true -> false
    end
  end

  defp check?(_), do: false

  @doc "Read vouch / GH-trail heat from the subject's Has slice."
  def heat_for(raw, opts \\ []) do
    heat_of(slice_meta(raw, opts))
  end

  defp slice_meta(raw, opts) do
    root = Keyword.get(opts, :root) || Room.Index.repo_root()
    local = raw |> to_string() |> String.trim_leading("@") |> String.split("@") |> hd()
    has_path = Path.join(Room.Index.dir(root, "has"), local <> ".md")
    curious_path = Path.join(Room.Index.dir(root, "curious"), local <> ".md")

    cond do
      File.regular?(has_path) -> slice_heat_meta(File.read!(has_path))
      File.regular?(curious_path) -> slice_heat_meta(File.read!(curious_path))
      true -> %{}
    end
  end

  def provenance_of(rec) when is_map(rec) do
    rec[:provenance] || provenance_for(rec[:source] || rec["source"])
  end

  def skill_look(id, rec) when is_map(rec) do
    "has  #{id}  provenance=#{provenance_of(rec)}"
  end

  defp strength_of_prov(prov) when prov in ["artifact", "connector"], do: "strong"
  defp strength_of_prov("chat"), do: "medium"
  defp strength_of_prov(_), do: "curious"

  def seed_artifact(raw, opts \\ []) when is_binary(raw) do
    source = opts[:source] || "upload"
    read = Keyword.get(opts, :read, &File.read/1)
    handle = normalize_handle(opts[:handle] || opts[:raw] || default_handle(source))

    case resolve_artifact(raw, source) do
      {:error, _} = err ->
        err

      {:ok, path, file} ->
        case read.(path) do
          {:ok, bytes} ->
            text = decode_bytes(path, bytes)
            examine_artifact(text, file, handle, source, opts)

          {:error, _} ->
            {:error, :bad_file}
        end
    end
  end

  def payload(has) do
    skills = has[:skills] || []

    %{
      "url" => has[:url],
      "file" => has[:file],
      "skills" => skills,
      "proof" => has[:proof] || skills,
      "claim" => has[:claim] || has[:about] || [],
      "about" => has[:about] || [],
      "links" => has[:links] || [],
      "source" => has[:source],
      "status" => has[:status],
      "strength" => has[:strength],
      "provenance" => has[:provenance] || provenance_for(has[:source])
    }
  end

  def apply_to_card(card, has) when is_map(card) do
    if has[:kind] == "has" and has[:status] == "has" do
      Map.put(card, "has", payload(has))
    else
      card
    end
  end

  def look_line(%{status: "curious"} = rec) do
    ids = rec[:curious] || rec[:proof] || []
    "ok  file=#{display_path(rec[:file])}  curious=[#{Enum.join(ids, ",")}]  provenance=#{provenance_of(rec)}"
  end

  def look_line(%{source: "github", status: "has"} = rec) do
    listed = Enum.join(rec[:skills] || rec[:proof] || [], ",")
    "ok  gh=#{display_path(rec[:file])}  has=[#{listed}]  provenance=#{provenance_of(rec)}"
  end

  def look_line(%{source: "upload", status: "has"} = rec) do
    listed = Enum.join(rec[:skills] || rec[:proof] || [], ",")
    "ok  file=#{display_path(rec[:file])}  has=[#{listed}]  provenance=#{provenance_of(rec)}"
  end

  def look_line(%{url: url, skills: skills} = rec) do
    listed = if skills == [], do: "", else: Enum.join(skills, ",")
    "ok  url=#{url}  has=[#{listed}]  provenance=#{provenance_of(rec)}"
  end

  def look_line(rec) when is_map(rec) do
    listed = Enum.join(rec[:skills] || [], ",")
    loc = rec[:file] || rec[:url] || ""
    "ok  file=#{display_path(loc)}  has=[#{listed}]  provenance=#{provenance_of(rec)}"
  end

  def candidate_line(rec) when is_map(rec) do
    key = if rec[:source] == "github", do: "gh", else: "file"
    "ok  #{key}=#{display_path(rec[:file])}  status=candidate"
  end

  @doc """
  Upload LOOK. Always candidate first. Pass → Has; fail → curious.
  Claims and fluff are not printed as Has.
  """
  def examine_look(rec) when is_map(rec) do
    [candidate_line(rec), look_line(rec)]
  end

  def pdf_look(%{status: "has"} = rec) do
    ids = rec[:skills] || rec[:proof] || []

    ["file  #{display_path(rec[:file])}"] ++
      Enum.map(ids, &skill_look(&1, rec)) ++
      examine_look(rec)
  end

  def pdf_look(rec) when is_map(rec) do
    ids = rec[:curious] || rec[:proof] || []

    ["file  #{display_path(rec[:file])}"] ++
      Enum.map(ids, &"curious  #{&1}") ++
      examine_look(rec)
  end

  def look(%{status: "curious"} = rec) do
    ids = rec[:curious] || rec[:proof] || []

    ["file  #{display_path(rec[:file])}"] ++
      Enum.map(ids, &"curious  #{&1}") ++
      examine_look(rec)
  end

  def look(%{source: "upload", status: "has"} = rec) do
    skills = rec[:skills] || rec[:proof] || []

    ["file  #{display_path(rec[:file])}"] ++
      Enum.map(skills, &skill_look(&1, rec)) ++
      examine_look(rec)
  end

  def look(%{source: "github"} = rec) do
    skills = rec[:skills] || rec[:proof] || []

    ["gh   #{display_path(rec[:file])}"] ++
      Enum.map(skills, &skill_look(&1, rec)) ++
      [look_line(rec)]
  end

  def look(has) when is_map(has) do
    url = has[:url] || has["url"] || ""
    skills = has[:skills] || []
    bullets = Enum.map(skills, &skill_look(&1, has))
    ["url  #{url}" | bullets] ++ [look_line(has)]
  end

  def look(_), do: ["ok  url=  has=[]"]

  @doc """
  Other-human vouch is proof heat. Lifts the subject's proof to Has.
  Self-vouch fails. Vouch cannot invent skills.
  """
  def vouch(voucher, subject, opts \\ []) do
    root = Keyword.get(opts, :root) || Room.Index.repo_root()
    voucher_id = normalize_handle(voucher)
    subject_id = normalize_handle(subject)

    cond do
      voucher_id == subject_id ->
        {:error, :self_vouch}

      true ->
        skills = lift_skills(subject_id, root)

        if skills == [] do
          {:error, :no_proof}
        else
          rec = %{
            kind: "has",
            handle: subject_id,
            skills: skills,
            proof: skills,
            claim: [],
            source: "vouch",
            status: "has",
            strength: "medium",
            provenance: "chat",
            heat: "has",
            vouched_by: voucher_id,
            reason: "vouch"
          }

          found =
            case Room.Cards.lookup(subject_id) do
              {:ok, hit} -> hit
              _ -> %{card: %{}, id: subject_id}
            end

          {:ok, persist_has(rec, found, opts)}
        end
    end
  end

  def look_vouch({:ok, rec}) when is_map(rec) do
    listed = Enum.join(rec[:skills] || rec[:proof] || [], ",")
    "ok  vouch=#{rec[:vouched_by]}→#{rec[:handle]}  heat=has  has=[#{listed}]"
  end

  def look_vouch({:error, :self_vouch}), do: "error  vouch=self  error=self_vouch"
  def look_vouch({:error, reason}), do: "error  vouch=#{reason}"

  def look_vouch(rec) when is_map(rec), do: look_vouch({:ok, rec})

  def vouch_demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} -> {given, false}
        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-vouch-#{System.unique_integer([:positive])}")
          File.mkdir_p!(Path.join(path, "index/has"))
          {path, true}
      end

    try do
      vouch_demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp vouch_demo_on(root) do
    with {:ok, curious} <-
           seed_resume(align_rel(), handle: "kai@mazel", root: root, github: false) do
      if curious.status != "curious" do
        {:error, :resume_not_curious}
      else
        lifted = vouch("ariel@mazel", "kai@mazel", root: root)
        self = vouch("kai@mazel", "kai@mazel", root: root)
        lines = [resume_only_look(curious), look_vouch(lifted), look_vouch(self)]

        case lifted do
          {:ok, rec} when rec.status == "has" and self == {:error, :self_vouch} ->
            {:ok, %{curious: curious, has: rec, lines: lines}}

          _ ->
            {:error, :vouch_not_has}
        end
      end
    end
  end

  @doc """
  Has match inventory for a handle. Proof only.

  Card has-payload proof/skills, then Has slice `proof:` / `skills:`.
  Curious slices and claims are ignored. Card skills are not Has.
  """
  def skills_for(raw, opts \\ []) do
    root = Keyword.get(opts, :root) || Room.Index.repo_root()

    case Room.Cards.lookup(to_string(raw)) do
      {:ok, found} ->
        payload_skills(found) || slice_skills(found.id, root) || []

      _ ->
        []
    end
  end

  def website_of(%{card: %{"website" => url}}) when is_binary(url), do: String.trim(url)
  def website_of(%{"website" => url}) when is_binary(url), do: String.trim(url)
  def website_of(_), do: nil

  def fetch(url) when is_binary(url) do
    cond do
      Map.has_key?(@web_fixtures, String.trim_trailing(url, "/")) or Map.has_key?(@web_fixtures, url) ->
        read_web_fixture(url)

      Map.has_key?(@github_fixtures, String.trim_trailing(url, "/")) or Map.has_key?(@github_fixtures, url) ->
        read_github_fixture(url)

      file_url?(url) ->
        File.read(file_path(url))

      File.regular?(url) ->
        File.read(url)

      live?(url) ->
        http_get(url)

      http?(url) ->
        {:error, :offline}

      true ->
        {:error, :bad_url}
    end
  end

  def distill(html, url) when is_binary(html) do
    if login_wall?(html) do
      {:error, :login_wall}
    else
      text = html_to_text(html)
      {text_proof, text_claim} = distill_text(text)
      lis = skill_lis(html)
      about = about_of(html, text)
      links = links_of(html)
      claim = (text_claim ++ about) |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == "")) |> Enum.uniq()

      proof =
        if linkedin?(url) do
          []
        else
          (lis ++ text_proof)
          |> Enum.uniq()
          |> Enum.filter(&(&1 in @domain_skills))
        end

      cond do
        about == [] and proof == [] and links == [] and claim == [] ->
          {:error, :empty_page}

        proof == [] ->
          {:ok, web_curious(url, claim, links)}

        true ->
          {:ok, web_has(url, proof, about, links, claim)}
      end
    end
  end

  def distill_text(text) when is_binary(text) do
    lines =
      text
      |> String.split(~r/\r?\n/)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    tagged_proof =
      lines
      |> Enum.filter(&prefix?(&1, "proof:"))
      |> Enum.flat_map(&ids_in/1)

    tagged_claim =
      lines
      |> Enum.filter(&prefix?(&1, "claim:"))
      |> Enum.map(&strip_prefix(&1, "claim:"))

    claim_lines = Enum.filter(lines, &claim_line?/1)

    inferred =
      lines
      |> Enum.reject(&claim_line?/1)
      |> Enum.flat_map(&ids_in/1)

    proof =
      (tagged_proof ++ inferred)
      |> Enum.uniq()
      |> Enum.filter(&(&1 in @domain_skills))

    claim =
      (tagged_claim ++ Enum.map(claim_lines, &strip_prefix(&1, "claim:")))
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    {proof, claim}
  end

  @doc """
  String extract from a PDF. No OCR. Parenthetical literals only.
  """
  def extract_pdf(bytes) when is_binary(bytes) do
    ascii = keep_ascii(bytes)

    ascii
    |> then(&Regex.scan(~r/\(((?:\\.|[^\\)])*)\)/, &1))
    |> Enum.map(fn [_, inner] -> unescape_pdf_string(inner) end)
    |> Enum.join("\n")
    |> String.trim()
  end

  def decode_bytes(path, bytes) when is_binary(bytes) do
    cond do
      json_bytes?(path, bytes) -> flatten_github_json(bytes)
      pdf_bytes?(path, bytes) -> extract_pdf(bytes)
      true -> bytes
    end
  end

  @doc """
  Recorded GH trail (repos/commits/PRs) → distillable text. No live GitHub.
  """
  def flatten_github_json(bytes) when is_binary(bytes) do
    case Jason.decode(bytes) do
      {:ok, map} when is_map(map) -> github_json_text(map)
      _ -> bytes
    end
  end

  def write_slice(root, rec) do
    kind = rec[:kind] || "has"
    local = rec[:handle] |> to_string() |> String.split("@") |> hd()
    local = if local == "", do: kind, else: local
    folder = Room.Index.dir(root, kind)
    File.mkdir_p!(folder)
    path = Path.join(folder, local <> ".md")
    File.write!(path, slice_markdown(rec, local))
    path
  end

  def display_path(nil), do: ""

  def display_path(path) when is_binary(path) do
    root = Room.Index.repo_root()

    cond do
      String.starts_with?(path, root <> "/") -> String.replace_prefix(path, root <> "/", "")
      true -> path
    end
  end

  defp examine_artifact(text, file, handle, source, opts) do
    {proof, claim} = distill_text(text)

    candidate = %{
      kind: "candidate",
      source: source,
      status: "candidate",
      strength: strength_for(source),
      provenance: provenance_for(source),
      handle: handle,
      file: file,
      proof: proof,
      claim: claim,
      skills: [],
      curious: []
    }

    trails = trails_for(handle, Keyword.get(opts, :root) || Room.Index.repo_root(), opts)
    judged = prompt_check(candidate, trails)
    persist_judged(judged, opts)
  end

  @doc """
  Moat. Do not trust a file alone. Check proof against cards, Has
  slices, fixtures, and transcripts. Contradiction → curious.
  """
  def prompt_check(candidate, trails) do
    strength = candidate[:strength] || strength_for(candidate.source)
    source = candidate[:source]
    proof = candidate.proof || []

    cond do
      strength == "curious" ->
        curious_rec(candidate, "inference")

      strength == "medium" ->
        curious_rec(candidate, "medium")

      conflict?(proof, trails) ->
        curious_rec(candidate, "conflict")

      source in ["github", "mcp"] and proof == [] ->
        curious_rec(candidate, "empty")

      source == "upload" and proof == [] ->
        curious_rec(candidate, "claim")

      source == "upload" and not github?(trails) ->
        curious_rec(candidate, "resume_only")

      source == "upload" and own_of(trails) == [] ->
        curious_rec(candidate, "unverified")

      true ->
        connector? = source in ["github", "mcp"]

        candidate
        |> Map.merge(%{
          kind: "has",
          status: "has",
          strength: "strong",
          provenance: candidate[:provenance] || provenance_for(source),
          reason: "aligned",
          skills: proof,
          curious: [],
          trail: if(connector?, do: 1, else: 0),
          check: if(connector?, do: 1, else: 0)
        })
    end
  end

  def contradict_look(rec) when is_map(rec) do
    "ok  contradict→curious  demoted"
  end

  def corroborate_look(rec) when is_map(rec) do
    "ok  artifact+trail→has  match=#{rec[:handle]}"
  end

  def resume_only_look(rec) when is_map(rec) do
    "ok  resume-only→curious"
  end

  def gh_check_look(rec) when is_map(rec) do
    "ok  gh+check→has  match=#{rec[:handle]}"
  end

  @doc """
  Built-in prompt-check LOOK. Upload is always a candidate.
  Named reason → has | curious. Claims never Has.
  """
  def check_look(%{status: "has"} = rec) do
    "ok  check=#{rec[:reason] || "aligned"}  →has"
  end

  def check_look(%{status: "curious"} = rec) do
    "ok  check=#{rec[:reason] || "curious"}  →curious"
  end

  def check_look(_), do: "ok  check=claim  →curious"

  def upload_candidate_look, do: "ok  upload=candidate"

  @doc """
  Upload prompt-check LOOK. Isolated tmp. Resume-only / claim /
  conflict stay curious. Aligned resume after a GH trail is Has.
  """
  def upload_check_demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-upload-check-#{System.unique_integer([:positive])}")
          File.mkdir_p!(Path.join(path, "index/has"))
          {path, true}
      end

    try do
      upload_check_demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp upload_check_demo_on(root) do
    with {:ok, resume} <-
           seed_resume(align_rel(), handle: "kai@mazel", root: root, github: false),
         {:ok, claim} <-
           seed_resume(fluff_rel(), handle: "kai@mazel", root: root, github: false),
         {:ok, conflict} <-
           seed_resume(conflict_rel(), handle: "kai@mazel", root: root),
         {:ok, gh} <- seed_github(github_rel(), handle: "kai@mazel", root: root),
         {:ok, aligned} <- seed_resume(align_rel(), handle: "kai@mazel", root: root) do
      cond do
        resume.status != "curious" or resume.reason != "resume_only" ->
          {:error, :resume_not_curious}

        claim.status != "curious" or claim.reason != "claim" ->
          {:error, :claim_not_curious}

        conflict.status != "curious" or conflict.reason != "conflict" ->
          {:error, :conflict_not_curious}

        gh.status != "has" or aligned.status != "has" or aligned.reason != "aligned" ->
          {:error, :align_not_has}

        true ->
          lines = [
            upload_candidate_look(),
            check_look(resume),
            check_look(claim),
            check_look(conflict),
            check_look(aligned)
          ]

          {:ok,
           %{
             resume: resume,
             claim: claim,
             conflict: conflict,
             aligned: aligned,
             lines: lines
           }}
      end
    end
  end

  @doc """
  GitHub-lane LOOK. Candidate first, then Has after the fixture trail checks.
  """
  def gh_look(%{status: "has"} = rec) do
    examine_look(rec) ++ [gh_check_look(rec)]
  end

  def gh_look(rec) when is_map(rec), do: examine_look(rec)

  defp curious_rec(candidate, reason) do
    candidate
    |> Map.merge(%{
      kind: "curious",
      status: "curious",
      strength: "curious",
      reason: reason,
      skills: [],
      curious: candidate.proof,
      trail: 0,
      check: 0
    })
  end

  defp conflict?(proof, trails) do
    own = trails.own
    foreign = trails.foreign
    proof_domain = Enum.filter(proof, &(&1 in @domain_skills))

    cond do
      Enum.any?(proof_domain, &(&1 in foreign)) ->
        true

      own != [] and proof_domain != [] and MapSet.disjoint?(MapSet.new(proof_domain), MapSet.new(own)) ->
        true

      true ->
        false
    end
  end

  def trails(handle, root \\ nil, opts \\ []) do
    trails_for(handle, root || Room.Index.repo_root(), opts)
  end

  defp trails_for(handle, root, opts) do
    local = handle |> to_string() |> String.split("@") |> hd()

    own =
      []
      |> Kernel.++(card_domain(handle))
      |> Kernel.++(slice_domain(local, root, "has"))
      |> Kernel.++(fixture_domain(handle))
      |> Kernel.++(transcript_domain(handle, root))
      |> Enum.uniq()

    foreign =
      Room.Find.catalog()
      |> Enum.reject(&(&1.handle == handle))
      |> Enum.flat_map(fn hit -> Enum.filter(hit.skills, &(&1 in @domain_skills)) end)
      |> Enum.uniq()

    github =
      case Keyword.get(opts, :github, :auto) do
        false -> false
        true -> true
        _ -> github_connected?(local, root)
      end

    %{own: own, foreign: foreign, handle: handle, github: github}
  end

  defp github?(trails) when is_map(trails), do: trails[:github] == true
  defp github?(_), do: false

  defp own_of(trails) when is_map(trails), do: trails[:own] || []
  defp own_of(_), do: []

  defp github_connected?(local, root) do
    path = Path.join(Room.Index.dir(root, "has"), local <> ".md")

    if File.regular?(path) do
      text = File.read!(path)

      Regex.match?(~r/^source:\s*github\s*$/m, text) and
        not Regex.match?(~r/^kind:\s*curious/m, text)
    else
      false
    end
  end

  defp card_domain(handle) do
    case Room.Cards.lookup(handle) do
      {:ok, %{card: %{"skills" => skills}}} when is_list(skills) ->
        skills |> Enum.map(&to_string/1) |> Enum.filter(&(&1 in @domain_skills))

      _ ->
        []
    end
  end

  defp slice_domain(local, root, kind) do
    path = Path.join(Room.Index.dir(root, kind), local <> ".md")

    if File.regular?(path) do
      text = File.read!(path)

      if kind == "has" and not String.contains?(text, "kind: curious") do
        ids_from_slice(text)
      else
        []
      end
    else
      []
    end
  end

  defp fixture_domain(handle) do
    local = handle |> to_string() |> String.split("@") |> hd()

    [
      Path.join(Room.Index.repo_root(), "priv/fixtures/#{local}.github.txt"),
      Path.join(Room.Index.repo_root(), "fixtures/has/#{local}.html")
    ]
    |> Enum.filter(&File.regular?/1)
    |> Enum.flat_map(fn path ->
      path |> File.read!() |> then(fn text -> elem(distill_text(text), 0) end)
    end)
    |> Enum.uniq()
  end

  # Transcript check: know slices only (opens are wants, not Has).
  # Match the slice handle or a full `local@mazel` mention — never a bare
  # first name (that used to treat nova's impl as kai's trail).
  # Only tagged `proof:` lines count; chat vibes stay off the trail.
  defp transcript_domain(handle, root) do
    owner = String.downcase(to_string(handle))

    root
    |> Room.Index.load("know")
    |> Enum.flat_map(fn item ->
      who = String.downcase(to_string(item[:handle] || item["handle"] || ""))
      body = to_string(item[:body] || item["body"] || "")
      hay = String.downcase(body)

      if who == owner or String.contains?(hay, owner) do
        body
        |> String.split(~r/\r?\n/)
        |> Enum.filter(&prefix?(&1, "proof:"))
        |> Enum.flat_map(&ids_in/1)
      else
        []
      end
    end)
    |> Enum.filter(&(&1 in @domain_skills))
    |> Enum.uniq()
  end

  defp persist_judged(%{status: "has"} = has, opts) do
    root = Keyword.get(opts, :root) || Room.Index.repo_root()
    local = has.handle |> to_string() |> String.split("@") |> hd()

    if has.source == "upload" and github_connected?(local, root) do
      path = Path.join(Room.Index.dir(root, "has"), local <> ".md")

      case Room.Cards.lookup(has.handle) do
        {:ok, found} ->
          {:ok, has |> Map.put(:card, apply_to_card(found[:card] || %{}, has)) |> Map.put(:slice, path)}

        _ ->
          {:ok, Map.put(has, :slice, path)}
      end
    else
      case Room.Cards.lookup(has.handle) do
        {:ok, found} -> {:ok, persist_has(has, found, opts)}
        _ -> {:ok, persist_has(has, %{card: %{}, id: has.handle}, opts)}
      end
    end
  end

  defp persist_judged(%{status: "curious"} = curious, opts) do
    root = Keyword.get(opts, :root) || Room.Index.repo_root()
    path = write_slice(root, curious)
    {:ok, Map.put(curious, :slice, path)}
  end

  defp persist_has(has, found, opts) do
    root = Keyword.get(opts, :root) || Room.Index.repo_root()
    card = apply_to_card(found[:card] || %{}, has)
    path = write_slice(root, has)
    has |> Map.put(:card, card) |> Map.put(:slice, path)
  end

  defp lift_skills(handle, root) do
    case skills_for(handle, root: root) do
      [] -> slice_proof(handle, root)
      ids -> ids
    end
  end

  defp slice_proof(handle, root) do
    local = handle |> to_string() |> String.split("@") |> hd()

    Enum.find_value(["has", "curious"], [], fn kind ->
      path = Path.join(Room.Index.dir(root, kind), local <> ".md")

      if File.regular?(path) do
        case ids_from_slice(File.read!(path)) do
          [] -> nil
          ids -> ids
        end
      end
    end)
  end

  defp payload_skills(%{card: %{"has" => has}}) when is_map(has) do
    proof = has["proof"] || has["skills"]

    if is_list(proof) and proof != [] do
      proof |> Enum.map(&to_string/1) |> Enum.filter(&(&1 in @domain_skills or &1 in @skill_ids))
    end
  end

  defp payload_skills(_), do: nil

  defp slice_skills(id, root) when is_binary(id) do
    local = id |> String.split("@") |> hd()
    path = Path.join(Room.Index.dir(root, "has"), local <> ".md")

    if File.regular?(path) do
      text = File.read!(path)

      cond do
        Regex.match?(~r/^kind:\s*curious\s*$/m, text) ->
          nil

        true ->
          case ids_from_slice(text) do
            [] -> nil
            ids -> ids
          end
      end
    end
  end

  defp ids_from_slice(text) do
    lines = text |> String.split("\n") |> Enum.map(&String.trim/1)

    proof =
      Enum.find_value(lines, fn line ->
        if prefix?(line, "proof:"), do: comma_ids(line), else: nil
      end)

    skills =
      Enum.find_value(lines, fn line ->
        if prefix?(line, "skills:"), do: comma_ids(line), else: nil
      end)

    proof || skills || []
  end

  defp slice_heat_meta(text) do
    lines = text |> String.split("\n") |> Enum.map(&String.trim/1)

    pick = fn key ->
      Enum.find_value(lines, fn line ->
        if prefix?(line, key <> ":") do
          line |> String.replace_prefix(key <> ":", "") |> String.trim()
        end
      end)
    end

    %{
      heat: pick.("heat"),
      source: pick.("source"),
      vouched_by: pick.("vouched_by"),
      status: pick.("status"),
      kind: pick.("kind"),
      provenance: pick.("provenance"),
      trail: pick.("trail"),
      check: pick.("check")
    }
  end

  defp comma_ids(line) do
    line
    |> String.replace(~r/^(proof|skills):\s*/i, "")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp slice_markdown(rec, local) do
    handle = rec[:handle] || local
    kind = rec[:kind] || "has"
    source = rec[:source] || "web"
    status = rec[:status] || kind
    strength = rec[:strength] || strength_for(source)
    provenance = rec[:provenance] || provenance_for(source)
    proof = rec[:proof] || rec[:skills] || []
    claim = rec[:claim] || rec[:about] || []
    skills = if kind == "has", do: rec[:skills] || proof, else: []
    topic = List.first(proof) || List.first(skills) || kind
    title = if kind == "has", do: "Has #{local}", else: "Curious #{local}"

    skills_line = if skills == [], do: "", else: "skills: #{Enum.join(skills, ", ")}\n"
    proof_line = "proof: #{Enum.join(proof, ", ")}"
    claim_block = claim |> Enum.map(&("claim: " <> &1)) |> Enum.join("\n")

    extra =
      []
      |> then(&if rec[:heat], do: &1 ++ ["heat: #{rec[:heat]}"], else: &1)
      |> then(&if rec[:vouched_by], do: &1 ++ ["vouched_by: #{rec[:vouched_by]}"], else: &1)
      |> then(&if rec[:trail] in [1, "1", true], do: &1 ++ ["trail: #{rec[:trail]}"], else: &1)
      |> then(&if rec[:check] in [1, "1", true], do: &1 ++ ["check: #{rec[:check]}"], else: &1)

    front_extra =
      if extra == [] do
        ""
      else
        "\n" <> Enum.map_join(extra, "\n", &("    #{&1}"))
      end

    """
    ---
    id: #{local}
    kind: #{kind}
    source: #{source}
    status: #{status}
    strength: #{strength}
    provenance: #{provenance}
    topic: #{topic}
    as_of: #{@as_of}
    handle: #{handle}#{front_extra}
    ---

    # #{title}

    #{proof_line}
    #{skills_line}#{claim_block}
    """
  end

  defp resolve_artifact(raw, source) do
    raw = String.trim(raw)

    cond do
      raw == "" ->
        {:error, :bad_file}

      source == "github" and (Map.has_key?(@github_fixtures, raw) or Map.has_key?(@github_fixtures, String.trim_trailing(raw, "/"))) ->
        rel = @github_fixtures[raw] || @github_fixtures[String.trim_trailing(raw, "/")]
        path = Path.join(Room.Index.repo_root(), rel)
        {:ok, path, rel}

      File.regular?(raw) ->
        {:ok, raw, display_path(raw)}

      File.regular?(Path.join(Room.Index.repo_root(), raw)) ->
        {:ok, Path.join(Room.Index.repo_root(), raw), display_path(raw)}

      true ->
        {:error, :bad_file}
    end
  end

  defp normalize_handle(raw) do
    case Room.Cards.lookup(to_string(raw)) do
      {:ok, found} -> found.id
      _ ->
        trimmed = String.trim(to_string(raw)) |> String.trim_leading("@")
        if String.contains?(trimmed, "@"), do: trimmed, else: trimmed <> "@mazel"
    end
  end

  defp default_handle("github"), do: "kai@mazel"
  defp default_handle(_), do: "kai@mazel"

  defp json_bytes?(path, _bytes) do
    String.ends_with?(String.downcase(to_string(path)), ".json")
  end

  defp github_json_text(map) do
    proof =
      (map["proof"] || [])
      |> List.wrap()
      |> Enum.map(&to_string/1)
      |> Enum.reject(&(&1 == ""))

    proof_line = if proof == [], do: [], else: ["proof: #{Enum.join(proof, ", ")}"]

    repos =
      List.wrap(map["repos"] || map["repositories"] || [])
      |> Enum.map(fn repo ->
        name = repo["name"] || ""
        desc = repo["description"] || ""
        "repo: #{name} #{desc}" |> String.trim()
      end)

    commits =
      List.wrap(map["commits"] || [])
      |> Enum.map(fn commit ->
        "commit: #{commit["sha"] || ""} #{commit["message"] || ""}" |> String.trim()
      end)

    pulls =
      List.wrap(map["pulls"] || map["prs"] || [])
      |> Enum.map(fn pull ->
        "pr: #{pull["title"] || ""}" |> String.trim()
      end)

    (proof_line ++ repos ++ commits ++ pulls)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  defp pdf_bytes?(path, bytes) do
    String.ends_with?(String.downcase(to_string(path)), ".pdf") or
      String.starts_with?(bytes, "%PDF")
  end

  defp keep_ascii(bytes) do
    for <<c <- bytes>>, c in [9, 10, 13] or c in 32..126, into: "", do: <<c>>
  end

  defp unescape_pdf_string(text) do
    text
    |> String.replace("\\n", "\n")
    |> String.replace("\\r", "\r")
    |> String.replace("\\t", "\t")
    |> String.replace("\\(", "(")
    |> String.replace("\\)", ")")
    |> String.replace("\\\\", "\\")
  end

  defp prefix?(line, prefix) do
    String.starts_with?(String.downcase(line), prefix)
  end

  defp strip_prefix(line, prefix) do
    if prefix?(line, prefix) do
      String.slice(line, String.length(prefix)..-1//1) |> String.trim()
    else
      line
    end
  end

  defp claim_line?(line) do
    prefix?(line, "claim:") or fluff?(line) or first_person_boast?(line)
  end

  defp fluff?(line), do: Regex.match?(@fluff, line)

  defp first_person_boast?(line) do
    Regex.match?(~r/^(i am |i'm |as a )/i, line)
  end

  defp ids_in(text) do
    hay = String.downcase(text)

    Enum.filter(@skill_ids, fn id ->
      String.contains?(hay, id) or String.contains?(hay, String.replace(id, "-", " "))
    end)
  end

  defp read_web_fixture(url) do
    rel = @web_fixtures[url] || @web_fixtures[String.trim_trailing(url, "/")]
    File.read(Path.join(Room.Index.repo_root(), rel))
  end

  defp read_github_fixture(url) do
    rel = @github_fixtures[url] || @github_fixtures[String.trim_trailing(url, "/")]
    File.read(Path.join(Room.Index.repo_root(), rel))
  end

  defp file_url?(url), do: String.starts_with?(url, "file:")

  defp file_path("file://" <> rest), do: rest
  defp file_path("file:" <> rest), do: rest

  defp http?(url), do: String.starts_with?(url, "http://") or String.starts_with?(url, "https://")

  defp live?(url) do
    http?(url) and System.get_env("MAZEL_HAS_LIVE") == "1"
  end

  defp http_get(url) do
    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)

    request = {String.to_charlist(url), [{~c"user-agent", ~c"mazel-has/0.1"}]}

    http_opts = [timeout: 5_000, connect_timeout: 3_000]
    opts = [body_format: :binary]

    case :httpc.request(:get, request, http_opts, opts) do
      {:ok, {{_, 200, _}, _, body}} when is_binary(body) -> {:ok, body}
      {:ok, {{_, status, _}, _, _}} -> {:error, {:http_status, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp login_wall?(html) do
    Regex.match?(~r/type\s*=\s*["']password["']/i, html) and
      not Regex.match?(~r/<h1[\s>]/i, html) and
      meta_description(html) == nil
  end

  defp html_to_text(html) do
    html
    |> String.replace(~r/<script[\s\S]*?<\/script>/i, " ")
    |> String.replace(~r/<style[\s\S]*?<\/style>/i, " ")
    |> String.replace(~r/<[^>]+>/, " ")
    |> String.replace("&amp;", "&")
    |> String.replace("&nbsp;", " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp skill_lis(html) do
    Regex.scan(~r/<li[^>]*>([\s\S]*?)<\/li>/i, html)
    |> Enum.map(fn [_, inner] -> html_to_text(inner) end)
    |> Enum.flat_map(fn line ->
      if claim_line?(line), do: [], else: ids_in(line)
    end)
    |> Enum.filter(&(&1 in @domain_skills))
  end

  defp linkedin?(url) when is_binary(url) do
    String.contains?(String.downcase(url), "linkedin.")
  end

  defp linkedin?(_), do: false

  defp web_has(url, proof, about, links, claim) do
    %{
      kind: "has",
      url: url,
      skills: proof,
      about: about,
      links: links,
      proof: proof,
      claim: claim,
      source: "web",
      status: "has",
      strength: "strong",
      provenance: "artifact"
    }
  end

  defp web_curious(url, claim, links) do
    ids =
      claim
      |> Enum.join(" ")
      |> then(&ids_in/1)
      |> Enum.filter(&(&1 in @domain_skills))

    %{
      kind: "curious",
      url: url,
      skills: [],
      about: claim,
      links: links,
      proof: [],
      claim: claim,
      curious: ids,
      source: "web",
      status: "curious",
      strength: "curious",
      provenance: "artifact",
      reason: "claim"
    }
  end

  defp about_of(html, text) do
    candidates =
      [
        meta_description(html),
        first_tag(html, "p"),
        first_tag(html, "h1"),
        title_of(html)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&shorten/1)
      |> Enum.uniq()
      |> Enum.reject(&(&1 == ""))

    if candidates == [] do
      case shorten(text) do
        "" -> []
        line -> [line]
      end
    else
      Enum.take(candidates, @max_about)
    end
  end

  defp links_of(html) do
    Regex.scan(~r/href\s*=\s*["']([^"']+)["']/i, html)
    |> Enum.map(fn [_, href] -> String.trim(href) end)
    |> Enum.filter(&http?/1)
    |> Enum.uniq()
    |> Enum.take(@max_links)
  end

  defp meta_description(html) do
    case Regex.run(~r/<meta\b[^>]*\bname=["']description["'][^>]*>/i, html) do
      [tag] ->
        case Regex.run(~r/\bcontent="([^"]+)"/i, tag) ||
               Regex.run(~r/\bcontent='([^']+)'/i, tag) do
          [_, content] -> String.trim(content)
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp title_of(html) do
    case Regex.run(~r/<title[^>]*>([\s\S]*?)<\/title>/i, html) do
      [_, title] -> html_to_text(title)
      _ -> nil
    end
  end

  defp first_tag(html, tag) do
    case Regex.run(~r/<#{tag}[^>]*>([\s\S]*?)<\/#{tag}>/i, html) do
      [_, inner] ->
        line = html_to_text(inner)
        if line == "", do: nil, else: line

      _ ->
        nil
    end
  end

  defp shorten(text) do
    text
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
    |> then(fn line ->
      if String.length(line) > 120, do: String.slice(line, 0, 117) <> "…", else: line
    end)
  end
end
