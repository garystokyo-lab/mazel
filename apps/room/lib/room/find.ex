defmodule Room.Find do
  @moduledoc """
  Find a handle or a skill. File cards only. No live DNS.

  Shared card skills: `find`, `chat`, `direct`.
  Buddy contrast: `series-a`/`cto` → kai; `impl`/`enterprise` → nova.

  Feel id is `harp` — a quiet skill match. LOOK stays text-first
  (`find=…  mazel'd @kai`). No harp emoji.
  """

  @card_skills ~w(find chat direct)
  @kai_skill "series-a"
  @nova_skill "impl"
  @feel "harp"
  @heat_skill "chat"

  def card_skills, do: @card_skills
  def kai_skill, do: @kai_skill
  def nova_skill, do: @nova_skill
  def feel, do: @feel
  def heat_skill, do: @heat_skill

  def query(raw, opts \\ [])

  def query(raw, opts) when is_binary(raw) do
    q = String.trim(raw)

    cond do
      q == "" ->
        {:ok, %{ok: false, query: "", hits: [], error: "empty_query"}}

      handle_query?(q) ->
        find_handle(q)

      true ->
        find_skill(String.downcase(q), opts)
    end
  end

  def query(_, _), do: {:ok, %{ok: false, query: "", hits: [], error: "empty_query"}}

  def catalog do
    Room.Cards.cards_dir()
    |> list_card_files()
    |> Enum.flat_map(&card_hit/1)
  end

  @doc """
  Two buddies, opposite skills. Each query returns exactly one handle.
  """
  def contrast do
    with {:ok, kai} <- only_handle(@kai_skill, "kai@mazel"),
         {:ok, nova} <- only_handle(@nova_skill, "nova@mazel") do
      {:ok,
       %{
         kind: @feel,
         kai: kai,
         nova: nova,
         kai_skill: @kai_skill,
         nova_skill: @nova_skill,
         look: look_line(kai, nova, @kai_skill, @nova_skill)
       }}
    end
  end

  def look_line(kai, nova, kai_skill \\ @kai_skill, nova_skill \\ @nova_skill) do
    kai_h = handle_of(kai)
    nova_h = handle_of(nova)
    "find=#{kai_skill}→#{kai_h}  find=#{nova_skill}→#{nova_h}"
  end

  def wing_at(%{handle: handle}), do: wing_at(handle)

  def wing_at(handle) when is_binary(handle) do
    "mazel @#{local_of(handle)} hello"
  end

  @doc "Verb-first chat beat. Find picked them; mazel'd @handle."
  def mazel_d(handle), do: "mazel'd @#{local_of(handle)}"

  def look_chat(contrast) do
    [
      "ok  find=#{contrast.kai_skill}→#{handle_of(contrast.kai)}  #{mazel_d(contrast.kai)}",
      "ok  find=#{contrast.nova_skill}→#{handle_of(contrast.nova)}  #{mazel_d(contrast.nova)}"
    ]
  end

  @doc """
  Match a Need against Has on file cards. Rank is fit × heat
  (vouch or GitHub/connector trail).
  """
  def for_need(need, opts \\ []) do
    wants = List.wrap(need[:wants] || need["wants"])
    root = Keyword.get(opts, :root)
    heat_opts = if(root, do: [root: root], else: [])

    scored =
      catalog()
      |> Enum.map(fn hit ->
        has = Room.Has.skills_for(hit.handle, heat_opts)
        overlap = Enum.filter(wants, &(&1 in has))
        fit = length(overlap)
        heat = Room.Has.heat_for(hit.handle, heat_opts)
        ranked = decorate(hit, fit, heat)
        {ranked, fit, overlap, has}
      end)
      |> Enum.filter(fn {_hit, fit, _overlap, _has} -> fit > 0 end)
      |> Enum.sort_by(fn {hit, _, _, _} -> {-hit.rank, hit.handle} end)

    case scored do
      [] ->
        {:ok, %{ok: false, error: "no_has", hits: [], handle: nil, hit: nil}}

      [{hit, score, overlap, has} | _] = rows ->
        {:ok,
         %{
           ok: true,
           hit: hit,
           handle: hit.handle,
           score: score,
           overlap: overlap,
           has: has,
           hits: Enum.map(rows, fn {h, _, _, _} -> h end),
           error: nil
         }}
    end
  end

  @doc """
  Shared-skill find: cold order vs vouched Has rising.
  Isolated to tmp. Does not rewrite committed Has.
  """
  def heat_demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-heat-#{System.unique_integer([:positive])}")
          File.mkdir_p!(Path.join(path, "index/has"))
          {path, true}
      end

    try do
      heat_demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  def look_heat(%{query: query, without: without, with: with_heat, has: rec}) do
    [
      "ok  find=#{query}  without=[#{Enum.join(without, ",")}]",
      Room.Has.look_vouch(rec),
      "ok  find=#{query}  with=[#{Enum.join(with_heat, ",")}]"
    ]
  end

  defp heat_demo_on(root) do
    {:ok, cold} = query(@heat_skill, root: root)
    without = Enum.map(cold.hits, & &1.handle)

    with {:ok, curious} <-
           Room.Has.seed_resume(Room.Has.align_rel(), handle: "kai@mazel", root: root, github: false),
         {:ok, rec} <- Room.Has.vouch("ariel@mazel", "kai@mazel", root: root) do
      if curious.status != "curious" do
        {:error, :resume_not_curious}
      else
        {:ok, hot} = query(@heat_skill, root: root)
        with_heat = Enum.map(hot.hits, & &1.handle)

        demo = %{
          query: @heat_skill,
          without: without,
          with: with_heat,
          has: rec,
          cold: cold,
          hot: hot
        }

        if hd(without) != "kai@mazel" and hd(with_heat) == "kai@mazel" do
          {:ok, Map.put(demo, :lines, look_heat(demo))}
        else
          {:error, :heat_order}
        end
      end
    end
  end

  @doc """
  Shared-skill find: resume-only stays cold; GH trail lifts kai.
  Isolated to tmp. Does not rewrite committed Has.
  """
  def trail_demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-gh-rank-#{System.unique_integer([:positive])}")
          File.mkdir_p!(Path.join(path, "index/has"))
          {path, true}
      end

    try do
      trail_demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  def look_trail(%{query: query, without: without, with: with_trail}) do
    [
      "ok  find=#{query}  without=[#{Enum.join(without, ",")}]  trail=0",
      "ok  resume-only→curious",
      "ok  gh+check→has  trail=1",
      "ok  find=#{query}  with=[#{Enum.join(with_trail, ",")}]  trail=1"
    ]
  end

  defp trail_demo_on(root) do
    {:ok, cold} = query(@heat_skill, root: root)
    without = Enum.map(cold.hits, & &1.handle)

    with {:ok, curious} <-
           Room.Has.seed_resume(Room.Has.align_rel(), handle: "kai@mazel", root: root, github: false),
         {:ok, gh} <-
           Room.Has.seed_github(Room.Has.github_rel(), handle: "kai@mazel", root: root) do
      cond do
        curious.status != "curious" ->
          {:error, :resume_not_curious}

        gh.status != "has" or gh.provenance != "connector" ->
          {:error, :gh_not_has}

        Room.Has.trail_for("kai@mazel", root: root) != 1 ->
          {:error, :trail_miss}

        true ->
          {:ok, hot} = query(@heat_skill, root: root)
          with_trail = Enum.map(hot.hits, & &1.handle)

          demo = %{
            query: @heat_skill,
            without: without,
            with: with_trail,
            curious: curious,
            gh: gh,
            cold: cold,
            hot: hot
          }

          if hd(without) != "kai@mazel" and hd(with_trail) == "kai@mazel" do
            {:ok, Map.put(demo, :lines, look_trail(demo))}
          else
            {:error, :trail_order}
          end
      end
    end
  end

  defp local_of(handle), do: handle |> handle_of() |> String.split("@") |> hd()

  defp handle_of(%{handle: handle}), do: handle
  defp handle_of(%{id: id}), do: id
  defp handle_of(handle) when is_binary(handle), do: handle

  def only_handle(skill, handle) when is_binary(skill) and is_binary(handle) do
    case query(skill) do
      {:ok, %{ok: true, hits: [%{handle: ^handle} = hit]}} ->
        {:ok, hit}

      {:ok, %{ok: true, hits: hits}} ->
        {:error, {:not_only, skill, Enum.map(hits, & &1.handle)}}

      {:ok, %{ok: false, error: error}} ->
        {:error, {:no_skill, skill, error}}

      other ->
        other
    end
  end

  defp find_handle(raw) do
    case Room.Cards.lookup(raw) do
      {:ok, found} ->
        if Map.get(found, :sink) do
          {:ok, %{ok: false, query: raw, hits: [], error: "not_a_person"}}
        else
          hit = hit_from_card(found)
          {:ok, %{ok: true, query: raw, kind: "handle", hits: [hit], error: nil}}
        end

      {:error, reason} ->
        {:ok, %{ok: false, query: raw, hits: [], error: error_id(reason)}}
    end
  end

  defp find_skill(skill, opts) do
    heat_opts = heat_opts(opts)

    hits =
      catalog()
      |> Enum.filter(fn hit -> skill in hit.skills end)
      |> Enum.map(fn hit ->
        fit = if skill in hit.skills, do: 1.0, else: 0.0
        heat = Room.Has.heat_for(hit.handle, heat_opts)
        decorate(hit, fit, heat)
      end)
      |> Enum.sort_by(&{-&1.rank, &1.handle})

    if hits == [] do
      {:ok, %{ok: false, query: skill, kind: "skill", hits: [], error: "no_skill"}}
    else
      {:ok, %{ok: true, query: skill, kind: "skill", hits: hits, error: nil}}
    end
  end

  defp decorate(hit, fit, heat) do
    hit
    |> Map.put(:fit, fit / 1)
    |> Map.put(:heat, heat / 1)
    |> Map.put(:rank, fit / 1 * heat / 1)
  end

  defp heat_opts(opts) do
    case Keyword.get(opts, :root) do
      nil -> []
      root -> [root: root]
    end
  end

  defp handle_query?(q) do
    String.starts_with?(q, "@") or String.contains?(q, "@")
  end

  defp list_card_files(dir) do
    if File.dir?(dir) do
      dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".json"))
      |> Enum.map(&Path.join(dir, &1))
    else
      []
    end
  end

  defp card_hit(path) do
    local = path |> Path.basename() |> Path.rootname()

    case Room.Cards.lookup(local <> "@mazel") do
      {:ok, found} ->
        if Map.get(found, :sink), do: [], else: [hit_from_card(found)]

      _ ->
        []
    end
  end

  defp hit_from_card(found) do
    skills = skills_of(found)

    %{
      handle: found.id,
      card_url: found.card_url,
      source: found[:source] && to_string(found.source),
      name: get_in(found, [Access.key(:card), "name"]) || found.id,
      skills: skills
    }
  end

  defp skills_of(%{card: %{"skills" => skills}}) when is_list(skills) do
    skills |> Enum.map(&to_string/1) |> Enum.reject(&(&1 == ""))
  end

  defp skills_of(_), do: @card_skills

  defp error_id(:unknown_handle), do: "unknown_handle"
  defp error_id({:unknown_handle, _, _}), do: "unknown_handle"
  defp error_id({:invalid_card, _, _}), do: "invalid_card"
  defp error_id(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp error_id(_), do: "error"
end
