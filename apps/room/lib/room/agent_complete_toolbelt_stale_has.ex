defmodule Room.AgentCompleteToolbeltStaleHas do
  @moduledoc """
  Stale proof Has still unlocks tools on complete=agent.

  Soft decay: age=stale is labeled, paths stay open.
  Distinct from agent_complete_toolbelt (no age) and
  age_demo (no mcp). Not badge. Not PDF. No morph.
  """

  def look_has(found \\ %{}, age \\ %{}) do
    hit = List.first(found[:hits] || [])
    handle = (hit && hit.handle) || "kai@mazel"
    label = age[:label] || age[:evidence_label] || "stale"
    "ok  has=1  age=#{label}  mcp=mazel_find  query=series-a→#{handle}"
  end

  def look_wing(wing \\ %{}) do
    "ok  mcp=mazel_wing  #{Room.Find.mazel_d(wing[:handle] || wing["handle"] || "kai@mazel")}"
  end

  def look_complete, do: "ok  complete=agent  morph=none  session=agent"

  def look_claim, do: "error  claim→curious  unfit=true  mcp=none"

  def look(pack) when is_map(pack) do
    [look_has(pack.has_find, pack.age), look_wing(pack.wing), look_complete(), look_claim()]
  end

  def look(_), do: look(%{has_find: %{}, age: %{label: "stale"}, wing: %{}})

  @doc """
  Stale-as_of Has unlocks MCP on complete=agent. Claim is mcp=none.
  Isolated. Sibling toolbelt / age LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "agent-toolbelt-stale-has-" <> random_id()

    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path =
            Path.join(
              System.tmp_dir!(),
              "mazel-agent-toolbelt-stale-has-#{System.unique_integer([:positive])}"
            )

          File.mkdir_p!(path)
          {path, true}
      end

    try do
      demo_on(root, prefix)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp demo_on(root, prefix) do
    has_root = Path.join(root, "has")
    dest = Path.join(has_root, "index/has/kai.md")
    File.mkdir_p!(Path.dirname(dest))
    File.cp!(Path.join(Room.Index.repo_root(), "index/has/kai.md"), dest)

    now = Room.Age.demo_now()
    stale_on = Date.add(DateTime.to_date(now), -Room.Age.demo_stale_days()) |> Date.to_iso8601()
    stamp_as_of!(dest, stale_on)
    age = Room.Age.of("kai@mazel", root: has_root, now: now)

    agree = "need: founders seeking series-a"
    boast = "claim: passionate visionary hunt for series-a"

    with {:ok, need} <- Room.NeedCheck.cast(:founder_investors, transcript: agree),
         {:ok, match} <- Room.Need.match_has(need, root: has_root, transcript: agree, now: now),
         {:ok, claim} <- Room.NeedCheck.cast(:founder_investors, transcript: boast),
         {:ok, skipped} <- Room.Need.match_has(need, root: has_root, transcript: boast, now: now),
         {:ok, has_find} <-
           Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => has_root}),
         {:ok, wing} <-
           Room.Mcp.call_tool("mazel_wing", %{
             "text" => Room.Find.wing_at("kai@mazel"),
             "root" => has_root
           }),
         {:ok, session} <- keep_agent(prefix, match) do
      has_hit = List.first(has_find[:hits] || [])
      events = Enum.map(session.events || [], & &1.type)

      cond do
        age.label != "stale" or age.still_paths != true ->
          {:error, :age_miss}

        Room.Toolbelt.proof_has_count(has_root) < 1 or not Room.Toolbelt.ready?(has_root) ->
          {:error, :has_miss}

        is_nil(has_hit) or has_hit.handle != "kai@mazel" ->
          {:error, :mcp_find_miss}

        (wing[:handle] || wing["handle"]) != "kai@mazel" ->
          {:error, :wing_miss}

        not match.ok or match.handle != "kai@mazel" ->
          {:error, :match_miss}

        not claim.unfit or skipped.ok or skipped.matches != [] ->
          {:error, :claim_fit}

        session.status != :open or session.session_kind != :direct ->
          {:error, :session_miss}

        session.badge != nil or "morph.commit" in events ->
          {:error, :morphed}

        humans_awake?(session) ->
          {:error, :human_woke}

        true ->
          pack = %{
            age: age,
            need: need,
            match: match,
            claim: claim,
            has_find: has_find,
            wing: wing,
            session: session,
            complete: :agent
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp keep_agent(id, match) do
    peer = match[:handle] || "kai@mazel"

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup(peer) do
      Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}])
    end
  end

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp stamp_as_of!(path, iso) do
    text = File.read!(path)
    File.write!(path, Regex.replace(~r/^as_of:\s*\S+/m, text, "as_of: #{iso}"))
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end