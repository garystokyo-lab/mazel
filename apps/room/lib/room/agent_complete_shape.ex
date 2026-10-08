defmodule Room.AgentCompleteShape do
  @moduledoc """
  Need shape on the in-agent complete path.

  `icp_pain` matches nova. Vibe is curious and never completes.
  Distinct from agent_complete (score/why/claim) and
  agent_complete_ttl (no shape=). Not badge. Not PDF.
  """

  def look_find, do: "ok  find=impl→nova@mazel  mazel'd @nova"

  def look_match(rec) when is_map(rec) do
    peer = rec[:handle] || rec[:peer] || "nova@mazel"
    shape = rec[:shape] || :icp_pain
    ttl = rec[:need_ttl] || rec[:freshness] || :fresh
    "ok  need×has  peer=#{peer}  shape=#{shape}  check=pass  need_ttl=#{ttl}"
  end

  def look_match(_), do: look_match(%{handle: "nova@mazel", shape: :icp_pain, need_ttl: :fresh})

  def look_complete, do: "ok  complete=agent  morph=none  session=agent"

  def look_vibe, do: "error  vibe→curious  unfit=true"

  def look(pack) when is_map(pack) do
    [look_find(), look_match(pack.match), look_complete(), look_vibe()]
  end

  def look(_), do: look(%{match: %{}})

  @doc """
  Shape-cast icp_pain completes in-agent with nova. Vibe refused.
  Isolated. Sibling complete / shape LOOK stays.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-agent-shape-#{System.unique_integer([:positive])}")
          File.mkdir_p!(Path.join(path, "index/has"))
          {path, true}
      end

    try do
      demo_on(root, opts)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp demo_on(root, opts) do
    now = Room.Age.demo_now()

    File.cp!(
      Path.join(Room.Index.repo_root(), "index/has/nova.md"),
      Path.join(root, "index/has/nova.md")
    )

    agree = "need: ICP pain enterprise impl"

    with {:ok, found} <- Room.Find.query("impl"),
         {:ok, raw} <- Room.NeedCheck.cast(:icp_pain, transcript: agree),
         need <- Room.OpenNeed.stamp(raw, now: now),
         {:ok, match} <- Room.Need.match_has(need, root: root, now: now, transcript: agree),
         {:ok, vibe} <- Room.Need.Shape.cast("vibe: passionate visionary energy"),
         {:ok, skipped} <- Room.Need.match_has(vibe, root: root, now: now),
         {:ok, session} <- keep_agent(match, opts) do
      hit = List.first(found[:hits] || [])
      events = Enum.map(session.events || [], & &1.type)
      ttl = match[:freshness] || match[:need_ttl] || :fresh

      cond do
        is_nil(hit) or hit.handle != "nova@mazel" ->
          {:error, :find_miss}

        need.shape != :icp_pain or need.check != "pass" or need.unfit or need.need_ttl != :fresh ->
          {:error, :shape_miss}

        not match.ok or match.handle != "nova@mazel" or match[:unfit] or ttl != :fresh ->
          {:error, :match_miss}

        not vibe.unfit or vibe.ok or skipped.ok or skipped.matches != [] ->
          {:error, :vibe_matched}

        session.status != :open or session.session_kind != :direct ->
          {:error, :session_miss}

        session.badge != nil or "morph.commit" in events ->
          {:error, :morphed}

        humans_awake?(session) ->
          {:error, :human_woke}

        true ->
          pack = %{
            find: found,
            need: need,
            match: Map.merge(match, %{shape: need.shape, need_ttl: ttl}),
            vibe: vibe,
            session: session,
            complete: :agent
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp keep_agent(match, opts) do
    id = Keyword.get(opts, :context_id) || "agent-shape-" <> random_id()
    peer = match[:handle] || "nova@mazel"

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, nova} <- Room.Cards.lookup(peer) do
      Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: nova, role: :agent}])
    end
  end

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end