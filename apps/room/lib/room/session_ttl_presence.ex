defmodule Room.SessionTtlPresence do
  @moduledoc """
  After idle TTL expire, presence for that session id
  is empty.

  Distinct from session_presence (no TTL) and
  session_ttl / ttl_id / ttl_mid (no empty-presence
  beat). Off mint / Match / wiki / Consent / A2A.
  """

  def look_open(id, agents) do
    listed = agents |> List.wrap() |> Enum.join(",")
    "ok  session=open  id=#{id}  presence=agents=[#{listed}]"
  end

  def look_ttl, do: "error  ttl=expired"

  def look_empty(id) do
    "ok  presence=#{id}  agents=[]  humans=[]"
  end

  def look(pack) when is_map(pack) do
    [
      look_open(pack.open_id, pack[:before][:agents] || []),
      look_ttl(),
      look_empty(pack.open_id)
    ]
  end

  def look(_), do: look(%{open_id: "session-a", before: %{agents: ["ariel@mazel", "kai@mazel"]}})

  @doc """
  Open as agents, expire, presence empty on the same id.
  Isolated. Sibling presence / ttl LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-ttl-presence-" <> random_id()
    now = Keyword.get(opts, :now) || DateTime.utc_now()
    open_id = prefix

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
         {:ok, opened} <-
           Room.open(open_id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}]),
         {:ok, stamped} <- Room.SessionTtl.stamp(open_id, :fresh, now),
         {:ok, dead} <- Room.SessionTtl.expire(open_id, now),
         {:ok, after_id} <- Room.get(open_id) do
      before = Room.SessionTtl.presence(stamped)
      after_p = Room.SessionTtl.presence(after_id)

      cond do
        Room.SessionContext.id(opened) != open_id or Room.SessionContext.id(dead) != open_id ->
          {:error, :id_miss}

        Room.SessionTtl.freshness(stamped, now) != :fresh ->
          {:error, :open_miss}

        Room.SessionTtl.freshness(dead, now) != :expired ->
          {:error, :expire_miss}

        before.agents != ["ariel@mazel", "kai@mazel"] or before.humans != [] ->
          {:error, :presence_miss}

        after_p.agents != [] or after_p.humans != [] ->
          {:error, :presence_lingers}

        Room.SessionPresence.agents(dead) != [] or Room.SessionPresence.humans(dead) != [] ->
          {:error, :presence_lingers}

        minted?(opened) or minted?(dead) ->
          {:error, :minted}

        opened.status != :open or dead.status != :open ->
          {:error, :closed}

        "talk" in Enum.map(opened.events || [], & &1.type) ->
          {:error, :talked}

        humans_awake?(opened) ->
          {:error, :human_woke}

        true ->
          pack = %{
            open_id: open_id,
            opened: opened,
            stamped: stamped,
            dead: dead,
            before: before,
            after: after_p
          }

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
