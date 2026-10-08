defmodule Room.Discovery do
  @moduledoc """
  Thin discovery. `need@mazel` / 🪽 @mazel dispatch a Need.
  Returns real person handles. Not a Direct with Mazel-as-person.
  """

  @ask "series-A CTO"
  @sink_wing "🪽 @need #{@ask}"
  @mazel_wing "🪽 @mazel #{@ask}"
  @person_wing "🪽 @kai hello"

  def ask, do: @ask
  def sink_wing, do: @sink_wing
  def mazel_wing, do: @mazel_wing

  @doc """
  Dispatch a discovery Need and attach Has handles.
  `via` is the LOOK id: `need@mazel` or `🪽@mazel`.
  """
  def dispatch(text, opts \\ []) when is_binary(text) do
    via = Keyword.get(opts, :via) || via_of(text)
    root = Keyword.get(opts, :root)
    run_opts = if(root, do: [root: root], else: [])
    run_opts = Keyword.put(run_opts, :ttl_hours, Keyword.get(opts, :ttl_hours, 72))
    run_opts =
      case Keyword.get(opts, :actor) || Keyword.get(opts, :from) do
        nil -> run_opts
        actor -> Keyword.put(run_opts, :actor, actor)
      end

    with {:ok, need} <- Room.Wings.run(text, run_opts) do
      if need[:need_id] do
        handles = person_handles(need, run_opts)
        {:ok, Map.merge(need, %{kind: "need", via: via, handles: handles, person: false})}
      else
        {:error, :not_need}
      end
    end
  end

  def look(%{via: via, kind: "need", handles: handles}) do
    listed = handles |> List.wrap() |> Enum.join(",")
    "ok  discovery=#{via}  kind=need  handles=[#{listed}]"
  end

  def look(%{via: via, kind: kind}) when kind in [:direct, "direct"] do
    "ok  discovery=#{via}  kind=direct"
  end

  def look(_), do: "ok  discovery=  kind=need  handles=[]"

  @doc """
  need@mazel + 🪽 @mazel dispatch Need and return kai.
  🪽 @kai stays Direct. Isolated to tmp.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-disco-#{System.unique_integer([:positive])}")
          File.mkdir_p!(Path.join(path, "index/has"))
          File.mkdir_p!(Path.join(path, "index/needs"))
          {path, true}
      end

    try do
      demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp demo_on(root) do
    File.mkdir_p!(Path.join(root, "index/has"))
    File.cp!(Path.join(Room.Index.repo_root(), "index/has/kai.md"), Path.join(root, "index/has/kai.md"))

    with {:ok, sink} <- dispatch(@sink_wing, root: root, via: "need@mazel"),
         {:ok, wing} <- dispatch(@mazel_wing, root: root, via: "🪽@mazel"),
         {:ok, person} <- Room.Wings.run(@person_wing, context_id: "disco-" <> random_id()) do
      person_look = %{via: "🪽@kai", kind: person.state.session_kind}

      cond do
        sink.handles != ["kai@mazel"] or sink.kind != "need" ->
          {:error, :sink_not_need}

        wing.handles != ["kai@mazel"] or wing.kind != "need" ->
          {:error, :wing_not_need}

        person.state.session_kind != :direct or Map.has_key?(person, :need_id) ->
          {:error, :person_not_direct}

        true ->
          lines = [look(sink), look(wing), look(person_look)]
          {:ok, %{sink: sink, wing: wing, person: person, lines: lines}}
      end
    end
  end

  defp person_handles(need, opts) do
    wants = wants_for(need[:topic])
    shaped = need |> Map.put(:wants, wants) |> Map.put(:id, need[:need_id] || need[:id])

    case Room.Need.match_has(shaped, opts) do
      {:ok, %{ok: true, matches: matches}} when is_list(matches) and matches != [] ->
        matches

      _ ->
        []
    end
  end

  defp wants_for("series-a"), do: ["series-a", "cto"]
  defp wants_for("impl"), do: ["impl", "enterprise"]
  defp wants_for(topic) when is_binary(topic), do: [topic]
  defp wants_for(_), do: ["series-a"]

  defp via_of(text) do
    cond do
      String.contains?(text, "@need") -> "need@mazel"
      String.contains?(text, "@mazel") -> "🪽@mazel"
      true -> "need@mazel"
    end
  end

  defp random_id do
    :crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)
  end
end
