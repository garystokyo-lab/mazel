defmodule Room.SessionTtlTalkIds do
  @moduledoc """
  After TTL, talk on the old id is denied. Talk on a
  fresh id is ok.

  Distinct from session_ttl_id / ttl_mid (talk denied
  without id= on the deny / fresh-talk lines) and
  session_ttl_presence_fresh (presence only). Off mint /
  Match / wiki / Consent / A2A.
  """

  def look_open(id), do: Room.SessionTtlId.look_open(id)
  def look_ttl, do: Room.SessionTtlPresence.look_ttl()

  def look_denied(id) do
    "error  talk=@kai  id=#{id}  denied=expired"
  end

  def look_fresh(id), do: Room.SessionTtlId.look_fresh(id)

  def look_talk(id) do
    "ok  talk=@kai  id=#{id}  turn=1"
  end

  def look(pack) when is_map(pack) do
    [
      look_open(pack.open_id),
      look_ttl(),
      look_denied(pack.open_id),
      look_fresh(pack.fresh_id),
      look_talk(pack.fresh_id)
    ]
  end

  def look(_), do: look(%{open_id: "session-a", fresh_id: "session-b"})

  @doc """
  Expire, talk on -a denied, talk on -b ok.
  Isolated. Sibling ttl_id / ttl_mid / presence_fresh
  LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-ttl-talk-ids-" <> random_id()

    with {:ok, prior} <- Room.SessionTtlId.demo(Keyword.put(opts, :context_id, prefix)),
         {:ok, kai} <- Room.Cards.lookup("@kai") do
      cond do
        Room.talk(prior.open_id, kai, "again") != {:error, :ttl_expired} ->
          {:error, :old_talked}

        Room.SessionTtl.turn(prior.fresh) != 1 ->
          {:error, :fresh_miss}

        Room.SessionContext.same?(prior.talked, prior.fresh) ->
          {:error, :id_reuse}

        minted?(prior.talked) or minted?(prior.fresh) ->
          {:error, :minted}

        true ->
          {:ok, Map.put(prior, :lines, look(prior))}
      end
    end
  end

  defp minted?(session) do
    events = Enum.map(session.events || [], & &1.type)
    session.badge != nil or "morph.commit" in events or "morph.rejoin" in events
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
