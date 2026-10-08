defmodule Room.SessionTtlPresenceFresh do
  @moduledoc """
  After TTL empties presence, a fresh open is a new id
  with presence again. The expired id stays empty.

  Distinct from session_ttl_presence (stops at empty;
  no fresh open) and session_ttl_id (new id + talk, no
  presence). Off mint / Match / wiki / Consent / A2A.
  """

  def look_open(id, agents), do: Room.SessionTtlPresence.look_open(id, agents)
  def look_ttl, do: Room.SessionTtlPresence.look_ttl()
  def look_empty(id), do: Room.SessionTtlPresence.look_empty(id)

  def look_fresh(id, agents) do
    listed = agents |> List.wrap() |> Enum.join(",")
    "ok  session=fresh  id=#{id}  same=false  presence=agents=[#{listed}]"
  end

  def look(pack) when is_map(pack) do
    Room.SessionTtlPresence.look(pack) ++
      [
        look_fresh(pack.fresh_id, pack[:fresh_presence][:agents] || []),
        look_empty(pack.open_id)
      ]
  end

  def look(_) do
    look(%{
      open_id: "session-a",
      fresh_id: "session-b",
      before: %{agents: ["ariel@mazel", "kai@mazel"]},
      fresh_presence: %{agents: ["ariel@mazel", "kai@mazel"]}
    })
  end

  @doc """
  Expire empties -a, then -b opens with presence.
  Old id stays empty. Isolated. Sibling ttl_presence /
  ttl_id LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-ttl-presence-fresh-" <> random_id()
    now = Keyword.get(opts, :now) || DateTime.utc_now()
    open_id = prefix <> "-a"
    fresh_id = prefix <> "-b"

    with {:ok, emptied} <-
           Room.SessionTtlPresence.demo(Keyword.merge(opts, context_id: open_id, now: now)),
         {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
         {:ok, fresh_open} <-
           Room.open(fresh_id, :direct, [
             %{handle: ariel, role: :agent},
             %{handle: kai, role: :agent}
           ]),
         {:ok, fresh_stamped} <- Room.SessionTtl.stamp(fresh_id, :fresh, now),
         {:ok, still_dead} <- Room.get(open_id) do
      fresh_p = Room.SessionTtl.presence(fresh_stamped)
      old_p = Room.SessionTtl.presence(still_dead)

      cond do
        emptied.open_id != open_id or emptied.after.agents != [] or emptied.after.humans != [] ->
          {:error, :empty_miss}

        Room.SessionContext.id(fresh_stamped) != fresh_id ->
          {:error, :fresh_id_miss}

        Room.SessionContext.same?(emptied.dead, fresh_stamped) or open_id == fresh_id ->
          {:error, :id_reuse}

        Room.SessionTtl.freshness(fresh_stamped, now) != :fresh ->
          {:error, :fresh_miss}

        Room.SessionTtl.freshness(still_dead, now) != :expired ->
          {:error, :expire_miss}

        fresh_p.agents != ["ariel@mazel", "kai@mazel"] or fresh_p.humans != [] ->
          {:error, :presence_miss}

        old_p.agents != [] or old_p.humans != [] ->
          {:error, :presence_lingers}

        minted?(fresh_open) or minted?(fresh_stamped) ->
          {:error, :minted}

        fresh_open.status != :open or fresh_stamped.status != :open ->
          {:error, :closed}

        "talk" in Enum.map(fresh_stamped.events || [], & &1.type) ->
          {:error, :talked}

        humans_awake?(fresh_stamped) ->
          {:error, :human_woke}

        true ->
          pack =
            Map.merge(emptied, %{
              fresh_id: fresh_id,
              fresh: fresh_stamped,
              fresh_presence: fresh_p,
              still: still_dead,
              still_presence: old_p,
              same: false
            })

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp minted?(session) do
    events = Enum.map(session.events || [], & &1.type)
    session.badge != nil or "morph.commit" in events or "morph.rejoin" in events
  end

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
