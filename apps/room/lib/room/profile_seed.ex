defmodule Room.ProfileSeed do
  @moduledoc """
  Thin profile-URL scrape → curious seed.

  Skills / about / links land as scaffolding. URL alone is never
  Has. Promote only when a trail / proof (GH, vouch) is present.
  Fixture fetch only. Does not rewrite has_demo LOOK.
  """

  def look_url(rec) when is_map(rec) do
    "ok  url=#{rec[:url]} →curious"
  end

  def look_scaffold(rec) when is_map(rec) do
    listed = Enum.join(rec[:curious] || [], ",")
    "ok  has=[] / curious=[#{listed}]"
  end

  def look_trail(_rec \\ %{}), do: "ok  +trail →has"

  def look(pack) when is_map(pack) do
    [look_url(pack.alone), look_scaffold(pack.alone), look_trail(pack.trailed)]
  end

  def look(_), do: look(%{alone: %{url: Room.Has.fixture_url(), curious: []}, trailed: %{}})

  @doc """
  Scrape a profile URL. Without a trail, status stays curious.
  """
  def seed(url, opts \\ []) when is_binary(url) do
    fetch = Keyword.get(opts, :fetch, &Room.Has.fetch/1)

    case fetch.(String.trim(url)) do
      {:ok, html} ->
        case Room.Has.distill(html, url) do
          {:ok, distilled} -> {:ok, judge(distilled, opts)}
          other -> other
        end

      {:error, _} = err ->
        err
    end
  end

  @doc """
  URL seed stays curious. Trail / proof can promote to Has.
  """
  def promote(rec, opts \\ [])

  def promote(rec, opts) when is_map(rec) do
    ids = List.wrap(rec[:curious] || rec[:skills] || rec[:proof] || [])

    cond do
      not trail?(opts) or ids == [] ->
        {:error, :url_alone}

      true ->
        {:ok, to_has(rec, ids, opts)}
    end
  end

  def promote(_, _), do: {:error, :url_alone}

  @doc """
  URL alone → curious scaffolding. Same URL + trail → Has.
  Isolated. Does not rewrite has_demo LOOK.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-profile-seed-#{System.unique_integer([:positive])}")
          File.mkdir_p!(Path.join(path, "index/has"))
          {path, true}
      end

    try do
      demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp demo_on(_root) do
    url = Room.Has.fixture_url()

    with {:ok, alone} <- seed(url),
         {:error, :url_alone} <- promote(alone),
         {:ok, trailed} <- promote(alone, trail: :github) do
      cond do
        alone.status != "curious" or alone.unfit != true or alone.has != [] ->
          {:error, :url_was_has}

        alone.curious == [] or alone.about == [] or alone.links == [] ->
          {:error, :scaffold_miss}

        trailed.status != "has" or trailed.has == [] ->
          {:error, :trail_miss}

        true ->
          pack = %{alone: alone, trailed: trailed}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp judge(distilled, opts) do
    skills = List.wrap(distilled[:skills] || distilled[:proof] || [])
    about = List.wrap(distilled[:about] || [])
    links = List.wrap(distilled[:links] || [])
    seed = scaffold(distilled, skills, about, links)

    if trail?(opts) and skills != [] do
      to_has(seed, skills, opts)
    else
      seed
    end
  end

  defp scaffold(distilled, skills, about, links) do
    %{
      url: distilled[:url],
      status: "curious",
      kind: :curious,
      source: "web",
      seed: "curious",
      has: [],
      skills: [],
      proof: [],
      about: about,
      links: links,
      curious: skills,
      scaffold: field_ids(skills, about, links),
      unfit: true,
      reason: "url_alone",
      error: "url_alone"
    }
  end

  defp to_has(rec, ids, opts) do
    Map.merge(rec, %{
      status: "has",
      kind: "has",
      has: ids,
      skills: ids,
      proof: ids,
      curious: [],
      unfit: false,
      reason: "trail",
      error: nil,
      trail: Keyword.get(opts, :trail, true)
    })
  end

  defp field_ids(skills, about, links) do
    []
    |> then(&if(skills != [], do: &1 ++ ["skills"], else: &1))
    |> then(&if(about != [], do: &1 ++ ["about"], else: &1))
    |> then(&if(links != [], do: &1 ++ ["links"], else: &1))
  end

  defp trail?(opts) when is_list(opts) do
    Keyword.get(opts, :trail) in [true, :github, :vouch, "github", "vouch", "gh"]
  end

  defp trail?(_), do: false
end
