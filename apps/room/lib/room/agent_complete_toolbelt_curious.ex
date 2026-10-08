defmodule Room.AgentCompleteToolbeltCurious do
  @moduledoc """
  Curious-only vault keeps tools locked on complete=agent.

  Curious never counts as Has or Need. mazel_find / mazel_wing
  stay not_ready. Claim stays curious / mcp=none.
  Distinct from agent_complete_toolbelt (has=1),
  agent_complete_toolbelt_need (need=1), and toolbelt_ready
  (empty, no curious beat). Not badge. Not PDF. No morph.
  """

  def look_curious, do: "error  curious=1  mcp=not_ready"

  def look_claim, do: "error  claim→curious  unfit=true  mcp=none"

  def look_complete, do: "ok  complete=agent  morph=none  session=agent"

  def look(pack) when is_map(pack) do
    [look_curious(), look_claim(), look_complete()]
  end

  def look(_), do: look(%{})

  @doc """
  Curious-only vault does not unlock MCP. Complete stays in-agent.
  Isolated. Sibling unlock / ready LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "agent-toolbelt-curious-" <> random_id()

    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path =
            Path.join(
              System.tmp_dir!(),
              "mazel-agent-toolbelt-curious-#{System.unique_integer([:positive])}"
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
    curious_root = Path.join(root, "curious")
    File.mkdir_p!(Path.join(curious_root, "index/has"))
    File.mkdir_p!(Path.join(curious_root, "index/curious"))

    boast = "claim: passionate visionary hunt for series-a"

    with {:ok, curious} <-
           Room.Has.seed_resume(Room.Has.align_rel(),
             handle: "kai@mazel",
             root: curious_root,
             github: false
           ),
         {:ok, claim} <- Room.NeedCheck.cast(:founder_investors, transcript: boast),
         {:error, :not_ready} <-
           Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => curious_root}),
         {:error, :not_ready} <-
           Room.Mcp.call_tool("mazel_wing", %{
             "text" => Room.Find.wing_at("kai@mazel"),
             "root" => curious_root
           }),
         {:ok, session} <- keep_agent(prefix) do
      events = Enum.map(session.events || [], & &1.type)

      cond do
        curious.status != "curious" or curious.reason != "resume_only" ->
          {:error, :curious_miss}

        curious_count(curious_root) < 1 ->
          {:error, :curious_count}

        Room.Toolbelt.proof_has_count(curious_root) != 0 or Room.Toolbelt.need_count(curious_root) != 0 ->
          {:error, :unlocked}

        Room.Toolbelt.ready?(curious_root) ->
          {:error, :curious_ready}

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
            curious: curious,
            claim: claim,
            session: session,
            complete: :agent,
            locked: :not_ready
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp curious_count(root) do
    root
    |> Room.Index.load("curious")
    |> Enum.count(fn row ->
      kind = row[:kind] || row["kind"]
      status = row[:status] || row["status"]
      to_string(kind) == "curious" or to_string(status) == "curious"
    end)
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