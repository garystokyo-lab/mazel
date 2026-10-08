defmodule Room.SessionRejoinTtl do
  @moduledoc """
  Rejoin after idle TTL expire is denied. Fresh open
  needs a new id — not a zombie same-id.

  Distinct from session_ttl_id (fresh open new id, no
  rejoin-after-expire) and session_rejoin (no TTL).
  Off mint / Match / wiki. Not Consent.
  """

  def look_open(id), do: "ok  session=open  id=#{id}"
  def look_leave, do: "ok  leave=@kai"
  def look_ttl, do: "error  ttl=expired"
  def look_denied, do: "error  rejoin=@kai  denied=expired"
  def look_fresh(id), do: Room.SessionTtlId.look_fresh(id)
  def look_talk, do: Room.SessionTtlId.look_talk()

  def look(pack) when is_map(pack) do
    [
      look_open(pack.open_id),
      look_leave(),
      look_ttl(),
      look_denied(),
      look_fresh(pack.fresh_id),
      look_talk()
    ]
  end

  def look(_), do: look(%{open_id: "session-a", fresh_id: "session-b"})

  @doc """
  Leave, expire, rejoin denied, fresh id talks.
  Isolated. Sibling ttl_id / rejoin LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-rejoin-ttl-" <> random_id()
    now = Keyword.get(opts, :now) || DateTime.utc_now()
    open_id = prefix <> "-a"
    fresh_id = prefix <> "-b"

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
         {:ok, opened} <-
           Room.open(open_id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}]),
         {:ok, stamped} <- Room.SessionTtl.stamp(open_id, :fresh, now),
         {:ok, left} <- Room.SessionLeave.leave(open_id, "@kai"),
         {:ok, dead} <- Room.SessionTtl.expire(open_id, now),
         {:error, :ttl_expired} <- Room.SessionRejoin.join(open_id, "@kai"),
         {:ok, _fresh_open} <-
           Room.open(fresh_id, :direct, [
             %{handle: ariel, role: :agent},
             %{handle: kai, role: :agent}
           ]),
         {:ok, fresh_stamped} <- Room.SessionTtl.stamp(fresh_id, :fresh, now),
         {:ok, fresh_talk} <- Room.talk(fresh_id, kai, "hello") do
      cond do
        Room.SessionContext.id(opened) != open_id or Room.SessionContext.id(dead) != open_id ->
          {:error, :open_id_miss}

        Room.SessionContext.id(fresh_talk) != fresh_id ->
          {:error, :fresh_id_miss}

        Room.SessionContext.same?(opened, fresh_talk) or open_id == fresh_id ->
          {:error, :id_reuse}

        Room.SessionTtl.freshness(stamped, now) != :fresh ->
          {:error, :open_miss}

        Room.SessionTtl.freshness(dead, now) != :expired ->
          {:error, :expire_miss}

        Room.SessionTtl.turn(fresh_talk) != 1 or Room.SessionTtl.freshness(fresh_stamped, now) != :fresh ->
          {:error, :fresh_miss}

        minted?(opened) or minted?(left) or minted?(fresh_talk) ->
          {:error, :minted}

        left.status != :open or dead.status != :open or fresh_talk.status != :open ->
          {:error, :closed}

        humans_awake?(opened) or humans_awake?(fresh_talk) ->
          {:error, :human_woke}

        true ->
          pack = %{
            open_id: open_id,
            fresh_id: fresh_id,
            opened: opened,
            stamped: stamped,
            left: left,
            dead: dead,
            fresh: fresh_talk,
            same: false
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
