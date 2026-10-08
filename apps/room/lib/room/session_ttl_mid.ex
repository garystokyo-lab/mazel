defmodule Room.SessionTtlMid do
  @moduledoc """
  Talk, then TTL expire mid-turn. Fresh open needs a
  new id.

  Distinct from session_ttl (no id= / no mid-turn beat)
  and session_ttl_id (id change, no turn= on the open
  line). Off mint / Match / wiki / Consent / A2A.
  """

  def look_open(id), do: "ok  session=open  id=#{id}  talk=@kai  turn=1"
  def look_denied, do: Room.SessionTtl.look_denied()
  def look_fresh(id), do: Room.SessionTtlId.look_fresh(id)
  def look_talk, do: Room.SessionTtlId.look_talk()

  def look(pack) when is_map(pack) do
    [
      look_open(pack.open_id),
      look_denied(),
      look_fresh(pack.fresh_id),
      look_talk()
    ]
  end

  def look(_), do: look(%{open_id: "session-a", fresh_id: "session-b"})

  @doc """
  Open + talk (turn=1), expire mid-turn, new id talks.
  Isolated. Sibling ttl / ttl_id LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-ttl-mid-" <> random_id()

    with {:ok, prior} <-
           Room.SessionTtlId.demo(Keyword.put(opts, :context_id, prefix <> "-id")) do
      cond do
        Room.SessionTtl.turn(prior.talked) != 1 ->
          {:error, :mid_miss}

        Room.SessionTtl.freshness(prior.dead) != :expired ->
          {:error, :expire_miss}

        Room.SessionContext.same?(prior.talked, prior.fresh) ->
          {:error, :id_reuse}

        Room.SessionTtl.turn(prior.fresh) != 1 ->
          {:error, :fresh_miss}

        true ->
          {:ok, Map.put(prior, :lines, look(prior))}
      end
    end
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
