defmodule Room.WikiJit do
  @moduledoc """
  JIT read from wiki slices into find / Need×Has.

  people/*.md + needs/*.md → structured Factor inputs.
  Rebuildable vault. No ES. Distinct from jit_demo (Has age TTL)
  and from write-only wiki_slice / need_wiki LOOK.
  """

  def look_people(rec \\ %{}) do
    "ok  wiki=#{rec[:wiki] || "people/kai.md"}  read=true"
  end

  def look_need(rec \\ %{}) do
    "ok  wiki=#{rec[:wiki] || "needs/founder_investors.md"}  read=true"
  end

  def look_match(%{ok: true, handle: handle}) when is_binary(handle) do
    "ok  need×has  peer=#{handle}  from=wiki"
  end

  def look_match(_), do: "ok  need×has  peer=  from=wiki"

  def look(pack) when is_map(pack) do
    [look_people(pack.person), look_need(pack.need), look_match(pack.match)]
  end

  def look(_), do: look(%{person: %{}, need: %{}, match: %{}})

  @doc "Rebuild people + needs from the vault. No ES."
  def read(root) do
    with {:ok, people} <- Room.WikiSlice.rebuild(root),
         {:ok, needs} <- Room.NeedWiki.rebuild(root) do
      {:ok,
       %{
         people: Enum.map(people, &mark_person/1),
         needs: Enum.map(needs, &mark_need/1)
       }}
    end
  end

  @doc """
  Structured Need×Has from vault slices. Overlap is fit.
  Deterministic Factor inputs. No index/has, no ES.
  """
  def match(root) do
    with {:ok, vault} <- read(root) do
      need = Enum.find(vault.needs, &(&1.wants != []))
      person = Enum.find(vault.people, &overlap?(need, &1))

      cond do
        is_nil(need) or is_nil(person) ->
          {:ok, %{ok: false, handle: nil, from: "wiki", matches: [], unfit: true}}

        true ->
          scored = Room.Factors.score(inputs(need, person))

          {:ok,
           Map.merge(scored, %{
             ok: true,
             handle: person.handle,
             from: "wiki",
             need_id: need.id,
             overlap: overlap_ids(need, person),
             matches: [person.handle],
             person: person,
             need: need
           })}
      end
    end
  end

  def find(root), do: match(root)

  @doc """
  Write people + need slices, then JIT match from the vault only.
  Isolated. Does not rewrite wiki_slice / need_wiki / jit LOOK.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-wiki-jit-#{System.unique_integer([:positive])}")
          File.mkdir_p!(Path.join(path, Room.WikiSlice.people_rel()))
          File.mkdir_p!(Path.join(path, Room.NeedWiki.needs_rel()))
          {path, true}
      end

    try do
      demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp demo_on(root) do
    url = Room.Has.fixture_url()

    with {:ok, alone} <- Room.ProfileSeed.seed(url),
         alone <- Map.put(alone, :handle, "kai@mazel"),
         {:ok, _} <- Room.WikiSlice.promote(alone, trail: :github, root: root, handle: "kai@mazel"),
         {:ok, _} <- Room.NeedWiki.cast(:founder_investors, root: root),
         {:ok, vault} <- read(root),
         {:ok, hit} <- match(root) do
      person = Enum.find(vault.people, &(&1.handle == "kai@mazel"))
      need = Enum.find(vault.needs, &(&1.id == "founder_investors"))

      cond do
        is_nil(person) or person.read != true or person.wiki != "people/kai.md" ->
          {:error, :people_miss}

        is_nil(need) or need.read != true or need.wiki != "needs/founder_investors.md" ->
          {:error, :need_miss}

        not hit.ok or hit.handle != "kai@mazel" or hit.from != "wiki" ->
          {:error, :match_miss}

        hit.inputs.fit != 1 ->
          {:error, :fit_miss}

        File.dir?(Path.join(root, "index/has")) ->
          {:error, :used_has_index}

        true ->
          pack = %{person: person, need: need, match: hit, vault: vault}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp mark_person(row) do
    Map.merge(row, %{wiki: "people/kai.md", read: true})
  end

  defp mark_need(row) do
    Map.merge(row, %{wiki: "needs/#{row.id}.md", read: true})
  end

  defp overlap?(nil, _), do: false

  defp overlap?(need, person) do
    overlap_ids(need, person) != []
  end

  defp overlap_ids(need, person) do
    wants = MapSet.new(List.wrap(need[:wants]))
    has = MapSet.new(List.wrap(person[:has]))
    MapSet.intersection(wants, has) |> MapSet.to_list() |> Enum.sort()
  end

  defp inputs(need, person) do
    fit = if overlap?(need, person), do: 1, else: 0
    %{fit: fit, heat: 0, fresh: 1}
  end
end
