defmodule Room.SessionTtl do
  @moduledoc """
  Idle session TTL. Talk is denied after expire until
  a fresh open. Distinct from session_context / session_rejoin
  (no TTL). Off mint / Match / wiki. Not Need TTL.
  """

  def look_open, do: "ok  session=open  talk=@kai  turn=1"
  def look_denied, do: "error  ttl=expired  talk=denied"
  def look_fresh, do: "ok  session=fresh  talk=@kai  turn=1"

  def look(_pack \\ nil) do
    [look_open(), look_denied(), look_fresh()]
  end

  def stamp(context_id, ttl, now \\ DateTime.utc_now()) do
    Room.Context.stamp_ttl(context_id, ttl, now)
  end

  def expire(context_id, now \\ DateTime.utc_now()), do: stamp(context_id, :expired, now)

  def freshness(session, now \\ DateTime.utc_now())

  def freshness(session, now) when is_map(session) do
    case session[:expires_at] do
      nil ->
        :none

      iso when is_binary(iso) ->
        case DateTime.from_iso8601(iso) do
          {:ok, at, _} ->
            if DateTime.compare(at, now) == :gt, do: :fresh, else: :expired

          _ ->
            :none
        end

      _ ->
        :none
    end
  end

  def freshness(_, _), do: :none

  @doc """
  Presence for a session id. TTL expire empties
  humans and agents. Distinct from SessionPresence.of
  (no TTL gate).
  """
  def presence(session) when is_map(session) do
    %{agents: Room.SessionPresence.agents(session), humans: Room.SessionPresence.humans(session)}
  end

  def presence(_), do: %{agents: [], humans: []}

  def turn(session) when is_map(session) do
    (session[:events] || [])
    |> Enum.reduce(0, fn
      %{type: "room.open"}, _ -> 0
      %{type: "talk"}, n -> n + 1
      _, n -> n
    end)
  end

  def turn(_), do: 0

  @doc """
  Open, talk, expire → talk denied, fresh open → talk.
  Isolated. Sibling context / rejoin LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-ttl-" <> random_id()
    now = Keyword.get(opts, :now) || DateTime.utc_now()

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
         {:ok, opened} <-
           Room.open(prefix, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}]),
         {:ok, stamped} <- stamp(prefix, :fresh, now),
         {:ok, talked} <- Room.talk(prefix, kai, "hello"),
         {:ok, dead} <- expire(prefix, now),
         {:error, :ttl_expired} <- Room.talk(prefix, kai, "hello"),
         {:ok, _fresh_open} <-
           Room.open(prefix <> "-fresh", :direct, [
             %{handle: ariel, role: :agent},
             %{handle: kai, role: :agent}
           ]),
         {:ok, fresh_stamped} <- stamp(prefix <> "-fresh", :fresh, now),
         {:ok, fresh_talk} <- Room.talk(prefix <> "-fresh", kai, "hello") do
      cond do
        turn(talked) != 1 or freshness(stamped, now) != :fresh ->
          {:error, :open_miss}

        freshness(dead, now) != :expired or turn(dead) != 1 ->
          {:error, :expire_miss}

        turn(fresh_talk) != 1 or freshness(fresh_stamped, now) != :fresh ->
          {:error, :fresh_miss}

        minted?(opened) or minted?(talked) or minted?(fresh_talk) ->
          {:error, :minted}

        talked.status != :open or dead.status != :open or fresh_talk.status != :open ->
          {:error, :closed}

        humans_awake?(talked) or humans_awake?(fresh_talk) ->
          {:error, :human_woke}

        true ->
          pack = %{
            opened: opened,
            talked: talked,
            dead: dead,
            fresh: fresh_talk
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
