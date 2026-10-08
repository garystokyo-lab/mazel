defmodule Room.SessionLeavePeer do
  @moduledoc """
  After leave, peer still talks agent-side. Rejoin
  restores the left speaker on the same id.

  Distinct from session_leave_talk (left denied; no
  peer talk). Off mint / Match / wiki. Not Consent.
  """

  def look_open(id), do: Room.SessionLeaveTalk.look_open(id)
  def look_leave, do: Room.SessionLeaveTalk.look_leave()
  def look_peer, do: "ok  talk=@ariel  peer=agent"
  def look_denied, do: Room.SessionLeaveTalk.look_denied()
  def look_rejoin(id), do: Room.SessionLeaveTalk.look_rejoin(id)
  def look_talk, do: Room.SessionLeaveTalk.look_talk()

  def look(pack) when is_map(pack) do
    id = pack[:context_id] || pack[:id]

    [
      look_open(id),
      look_leave(),
      look_peer(),
      look_denied(),
      look_rejoin(id),
      look_talk()
    ]
  end

  def look(_), do: look(%{context_id: "session-leave-peer"})

  @doc """
  Open, kai talks, leave, ariel still talks, kai denied,
  rejoin same id, kai talks. Isolated. Sibling leave_talk
  LOOK stays (no peer=).
  """
  def demo(opts \\ []) do
    id = Keyword.get(opts, :context_id) || "session-leave-peer-" <> random_id()

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
         {:ok, opened} <-
           Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}]),
         {:ok, talked} <- Room.talk(id, kai, "hello"),
         {:ok, left} <- Room.SessionLeave.leave(id, "@kai"),
         {:ok, peer} <- Room.talk(id, ariel, "hello"),
         {:error, :left} <- Room.talk(id, kai, "hello"),
         {:ok, back} <- Room.SessionRejoin.join(id, "@kai"),
         {:ok, again} <- Room.talk(id, kai, "hello") do
      cond do
        Room.SessionContext.id(opened) != id or Room.SessionContext.id(again) != id ->
          {:error, :id_drift}

        not Room.SessionContext.same?(opened, left) or not Room.SessionContext.same?(left, again) ->
          {:error, :id_drift}

        Room.SessionLeaveTalk.sit_turn(talked, kai) != 1 ->
          {:error, :turn_miss}

        Room.SessionLeaveTalk.sit_turn(peer, ariel) != 1 ->
          {:error, :peer_miss}

        Room.SessionLeaveTalk.sit_turn(again, kai) != 1 ->
          {:error, :turn_miss}

        left.status != :open or peer.status != :open or again.status != :open ->
          {:error, :closed}

        minted?(opened) or minted?(peer) or minted?(again) ->
          {:error, :minted}

        humans_awake?(talked) or humans_awake?(peer) or humans_awake?(again) ->
          {:error, :human_woke}

        true ->
          pack = %{
            context_id: id,
            opened: opened,
            talked: talked,
            left: left,
            peer: peer,
            back: back,
            again: again,
            same: true
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
