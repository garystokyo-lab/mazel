defmodule Room.HeatCompose do
  @moduledoc """
  One heat. Human vouch and optional Gmail edge prior compose
  into the existing Factor input. No new plugin. LLM never ranks.
  Bodies stay redacted.
  """

  @need %{id: "founders-investors", kind: "need", wants: ["series-a"]}
  @peer "kai@mazel"

  def need, do: @need
  def peer, do: @peer

  @doc """
  Binary heat. Vouch or Gmail prior lifts. Both still `1`.
  Neither is `0`. Not a second plugin.
  """
  def heat(vouch, gmail) do
    if bit(vouch) == 1 or bit(gmail) == 1, do: 1, else: 0
  end

  def heat(%{} = rec) do
    heat(Map.get(rec, :vouch) || Map.get(rec, "vouch"), Map.get(rec, :gmail) || Map.get(rec, "gmail"))
  end

  def vouch_bit(raw) do
    cond do
      raw == true -> 1
      raw == Room.Has.heat_has() -> 1
      to_string(raw) in ["has", "vouch"] -> 1
      true -> 0
    end
  end

  def gmail_bit(nil), do: 0
  def gmail_bit(:none), do: 0
  def gmail_bit(false), do: 0

  def gmail_bit(%{} = rec) do
    bit(Map.get(rec, :heat) || Map.get(rec, "heat"))
  end

  def gmail_bit(raw), do: bit(raw)

  def inputs(vouch, gmail, extra \\ %{}) do
    Map.merge(
      %{
        fit: 1,
        heat: heat(vouch, gmail),
        fresh: 1,
        trail: 0,
        check: 0
      },
      extra
    )
  end

  def look_vouch(scored) when is_map(scored) do
    "ok  heat=vouch  inputs=#{fmt(scored)}  score=#{score_of(scored)}"
  end

  def look_gmail(scored) when is_map(scored) do
    "ok  heat=gmail  inputs=#{fmt(scored)}  score=#{score_of(scored)}  prior=gmail"
  end

  def look_both(scored) when is_map(scored) do
    "ok  heat=vouch+gmail  inputs=#{fmt(scored)}  score=#{score_of(scored)}"
  end

  def look_none(scored) when is_map(scored) do
    "ok  heat=0  inputs=#{fmt(scored)}  score=#{score_of(scored)}  redacted=true"
  end

  def look(pack) when is_map(pack) do
    [look_vouch(pack.vouch), look_gmail(pack.gmail), look_both(pack.both), look_none(pack.none)]
  end

  def look(_), do: look(%{vouch: %{}, gmail: %{}, both: %{}, none: %{}})

  @doc """
  Four beats on the Score path: vouch, gmail, both, neither.
  Isolated. Does not rewrite heat_demo / gmail_heat_demo LOOK.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-heat-compose-#{System.unique_integer([:positive])}")
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
    File.cp!(Path.join(Room.Index.repo_root(), "index/has/kai.md"), dest)

    with {:ok, pack} <- Room.GmailHeat.load(Room.GmailHeat.fixture_rel(), root: Room.Index.repo_root()) do
      edges = Room.GmailHeat.edges(pack)
      match = %{handle: @peer, overlap: @need.wants, wants: @need.wants}
      none = beat(root, now, match, nil)
      gmail = beat(root, now, match, edges)

      {:ok, vouched} = Room.Has.vouch("ariel@mazel", @peer, root: root)
      stamp_as_of!(dest, Date.to_iso8601(DateTime.to_date(now)))
      vouch = beat(root, now, match, nil)
      both = beat(root, now, match, edges)

      cond do
        none.inputs.heat != 0 or none.score != 0 or none.unfit ->
          {:error, :none_hot}

        gmail.inputs.heat != 1 or gmail.score != 2 ->
          {:error, :gmail_miss}

        vouch.inputs.heat != 1 or vouch.score != 2 ->
          {:error, :vouch_miss}

        both.inputs.heat != 1 or both.score != 2 ->
          {:error, :both_split}

        vouched.status != "has" ->
          {:error, :vouch_not_has}

        edges.heat != 1 or edges.redacted != true ->
          {:error, :gmail_edge}

        leaked?(look(%{vouch: vouch, gmail: gmail, both: both, none: none}), pack) ->
          {:error, :body_leaked}

        true ->
          out = %{vouch: vouch, gmail: gmail, both: both, none: none, edges: edges, has: vouched}
          {:ok, Map.put(out, :lines, look(out))}
      end
    end
  end

  defp beat(root, now, match, gmail) do
    opts = [root: root, now: now, need: @need]
    opts = if gmail, do: Keyword.put(opts, :gmail, gmail), else: opts

    @peer
    |> Room.Score.of(match, opts)
    |> Map.merge(%{handle: @peer, peer: @peer})
  end

  defp leaked?(lines, pack) do
    hay = Enum.join(List.wrap(lines), "\n")

    List.wrap(pack["threads"] || pack[:threads])
    |> Enum.flat_map(fn thread ->
      Enum.map(Room.GmailHeat.secret_keys(), fn key ->
        to_string(thread[key] || thread[String.to_atom(key)] || "")
      end)
    end)
    |> Enum.reject(&(&1 == ""))
    |> Enum.any?(&String.contains?(hay, &1))
  end

  defp stamp_as_of!(path, iso) do
    text = File.read!(path)
    File.write!(path, Regex.replace(~r/^as_of:\s*\S+/m, text, "as_of: #{iso}"))
  end

  defp bit(1), do: 1
  defp bit(true), do: 1
  defp bit("1"), do: 1
  defp bit("has"), do: 1
  defp bit(n) when is_number(n) and n > 0, do: 1
  defp bit(_), do: 0

  defp fmt(scored) when is_map(scored) do
    Room.Factors.format_inputs(scored[:inputs] || scored[:factors] || %{})
  end

  defp score_of(scored) when is_map(scored), do: scored[:score] || 0
end
