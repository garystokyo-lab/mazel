defmodule Room.AgentCompleteTtl do
  @moduledoc """
  Need TTL honesty on the in-agent complete path.

  Fresh Need completes mazel'd chat (`need_ttl=fresh`).
  Expired never completes. Distinct from agent_complete LOOK
  (no score / why / claim). Not badge. Not PDF.
  """

  def look_find, do: "ok  find=series-a→kai@mazel  mazel'd @kai"

  def look_match(rec) when is_map(rec) do
    peer = rec[:handle] || rec[:peer] || "kai@mazel"
    ttl = rec[:need_ttl] || rec[:freshness] || :fresh
    "ok  need×has  peer=#{peer}  check=pass  need_ttl=#{ttl}"
  end

  def look_match(_), do: look_match(%{handle: "kai@mazel", need_ttl: :fresh})

  def look_complete, do: "ok  complete=agent  morph=none  session=agent"

  def look_expired, do: "error  need_ttl=expired  unfit=true"

  def look(pack) when is_map(pack) do
    [look_find(), look_match(pack.match), look_complete(), look_expired()]
  end

  def look(_), do: look(%{match: %{}})

  @doc """
  Fresh Need×Has completes in-agent. Expired Need is unfit —
  no complete. Isolated. agent_complete LOOK stays.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-agent-ttl-#{System.unique_integer([:positive])}")
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
      Path.join(Room.Index.repo_root(), "index/has/kai.md"),
      Path.join(root, "index/has/kai.md")
    )

    agree = "need: founders seeking series-a"

    with {:ok, found} <- Room.Find.query("series-a"),
         {:ok, raw} <- Room.NeedCheck.cast(:founder_investors, transcript: agree),
         need <- Room.OpenNeed.stamp(raw, now: now),
         {:ok, match} <- Room.Need.match_has(need, root: root, now: now, transcript: agree),
         {:ok, session} <- keep_agent(match, opts) do
      dead = Room.OpenNeed.expire(need, now: now)
      {:ok, expired} = Room.Need.match_has(dead, root: root, now: now)
      hit = List.first(found[:hits] || [])
      events = Enum.map(session.events || [], & &1.type)
      ttl = match[:freshness] || match[:need_ttl] || :fresh

      cond do
        is_nil(hit) or hit.handle != "kai@mazel" ->
          {:error, :find_miss}

        need.check != "pass" or need.unfit or need.need_ttl != :fresh ->
          {:error, :check_miss}

        not match.ok or match.handle != "kai@mazel" or match[:unfit] or ttl != :fresh ->
          {:error, :match_miss}

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
            find: found,
            need: need,
            match: Map.put(match, :need_ttl, ttl),
            expired: expired,
            session: session,
            complete: :agent
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp keep_agent(match, opts) do
    id = Keyword.get(opts, :context_id) || "agent-ttl-" <> random_id()
    peer = match[:handle] || "kai@mazel"

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup(peer) do
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
