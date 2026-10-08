defmodule Room.AgentCompleteToolbeltExpired do
  @moduledoc """
  Expired Need keeps tools locked on complete=agent.

  Hard TTL dead does not unlock mazel_find / mazel_wing
  even when a Need slice still exists. Distinct from
  agent_complete_toolbelt_need (fresh need=1) and
  agent_complete_ttl (no mcp beats). Not badge. Not PDF.
  No morph.
  """

  def look_locked, do: "error  need_ttl=expired  mcp=not_ready"

  def look_unfit, do: "error  need_ttl=expired  unfit=true  mcp=none"

  def look_complete, do: "ok  complete=agent  morph=none  session=agent"

  def look(pack) when is_map(pack) do
    [look_locked(), look_unfit(), look_complete()]
  end

  def look(_), do: look(%{})

  @doc """
  Expired Need vault stays not_ready. Complete stays in-agent.
  Isolated. Sibling need-unlock / ttl LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "agent-toolbelt-expired-" <> random_id()

    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path =
            Path.join(
              System.tmp_dir!(),
              "mazel-agent-toolbelt-expired-#{System.unique_integer([:positive])}"
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
    need_root = Path.join(root, "need")
    File.mkdir_p!(Path.join(need_root, "index/needs"))
    File.mkdir_p!(Path.join(need_root, "index/has"))

    now = DateTime.utc_now()
    agree = "need: founders seeking series-a"

    with {:ok, seeded} <-
           Room.Need.seed("founders-investors", root: need_root, now: ~U[2020-01-01 12:00:00Z]),
         {:ok, raw} <- Room.NeedCheck.cast(:founder_investors, transcript: agree),
         need <- Room.OpenNeed.stamp(raw, now: now),
         dead <- Room.OpenNeed.expire(need, now: now),
         {:ok, expired} <- Room.Need.match_has(dead, root: need_root, now: now),
         {:error, :not_ready} <-
           Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => need_root}),
         {:error, :not_ready} <-
           Room.Mcp.call_tool("mazel_wing", %{
             "text" => Room.Find.wing_at("kai@mazel"),
             "root" => need_root
           }),
         {:ok, session} <- keep_agent(prefix) do
      events = Enum.map(session.events || [], & &1.type)

      cond do
        seeded.kind != "need" or not File.regular?(seeded.path) ->
          {:error, :seed_miss}

        Room.Toolbelt.proof_has_count(need_root) != 0 ->
          {:error, :has_unlock}

        Room.Toolbelt.need_count(need_root, now) != 0 or Room.Toolbelt.ready?(need_root) ->
          {:error, :expired_ready}

        expired.ok or not expired.unfit or expired.need_ttl != :expired ->
          {:error, :expired_matched}

        session.status != :open or session.session_kind != :direct ->
          {:error, :session_miss}

        session.badge != nil or "morph.commit" in events ->
          {:error, :morphed}

        humans_awake?(session) ->
          {:error, :human_woke}

        true ->
          pack = %{
            need: seeded,
            expired: expired,
            session: session,
            complete: :agent,
            locked: :not_ready
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
