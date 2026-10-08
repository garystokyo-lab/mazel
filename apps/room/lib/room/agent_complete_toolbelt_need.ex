defmodule Room.AgentCompleteToolbeltNeed do
  @moduledoc """
  Need-only vault unlocks tools on complete=agent.

  One Need (no proof Has) unlocks mazel_find / mazel_wing.
  Claim stays curious and does not unlock. Distinct from
  agent_complete_toolbelt (has=1 only) and toolbelt_ready
  (no complete=agent). Not badge. Not PDF. No morph.
  """

  def look_need(found \\ %{}) do
    hit = List.first(found[:hits] || [])
    handle = (hit && hit.handle) || "kai@mazel"
    "ok  need=1  mcp=mazel_find  query=series-a→#{handle}"
  end

  def look_wing(wing \\ %{}) do
    "ok  mcp=mazel_wing  #{Room.Find.mazel_d(wing[:handle] || wing["handle"] || "kai@mazel")}"
  end

  def look_complete, do: "ok  complete=agent  morph=none  session=agent"

  def look_claim, do: "error  claim→curious  unfit=true  mcp=none"

  def look(pack) when is_map(pack) do
    [look_need(pack.need_find), look_wing(pack.wing), look_complete(), look_claim()]
  end

  def look(_), do: look(%{need_find: %{}, wing: %{}})

  @doc """
  Need-only vault unlocks MCP on complete=agent. Claim is mcp=none.
  Isolated. Sibling has-toolbelt / ready LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "agent-toolbelt-need-" <> random_id()

    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path =
            Path.join(System.tmp_dir!(), "mazel-agent-toolbelt-need-#{System.unique_integer([:positive])}")

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
    empty = Path.join(root, "empty")
    need_root = Path.join(root, "need")
    File.mkdir_p!(Path.join(empty, "index/has"))
    File.mkdir_p!(Path.join(need_root, "index/needs"))

    boast = "claim: passionate visionary hunt for series-a"

    with {:ok, seeded} <- Room.Need.seed("founders-investors", root: need_root),
         {:ok, claim} <- Room.NeedCheck.cast(:founder_investors, transcript: boast),
         {:error, :not_ready} <-
           Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => empty}),
         {:ok, need_find} <-
           Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => need_root}),
         {:ok, wing} <-
           Room.Mcp.call_tool("mazel_wing", %{
             "text" => Room.Find.wing_at("kai@mazel"),
             "root" => need_root
           }),
         {:ok, session} <- keep_agent(prefix) do
      need_hit = List.first(need_find[:hits] || [])
      events = Enum.map(session.events || [], & &1.type)

      cond do
        Room.Toolbelt.need_count(need_root) < 1 or Room.Toolbelt.proof_has_count(need_root) != 0 or
            not Room.Toolbelt.ready?(need_root) ->
          {:error, :need_miss}

        Room.Toolbelt.ready?(empty) or Room.Toolbelt.need_count(empty) != 0 ->
          {:error, :empty_ready}

        seeded.kind != "need" ->
          {:error, :seed_miss}

        is_nil(need_hit) or need_hit.handle != "kai@mazel" ->
          {:error, :mcp_find_miss}

        (wing[:handle] || wing["handle"]) != "kai@mazel" ->
          {:error, :wing_miss}

        not claim.unfit ->
          {:error, :claim_fit}

        session.status != :open or session.session_kind != :direct ->
          {:error, :session_miss}

        session.badge != nil or "morph.commit" in events ->
          {:error, :morphed}

        humans_awake?(session) ->
          {:error, :human_woke}

        true ->
          pack = %{
            need: seeded,
            claim: claim,
            need_find: need_find,
            wing: wing,
            session: session,
            complete: :agent
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp keep_agent(id) do
    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai") do
      Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}])
    end
  end

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
