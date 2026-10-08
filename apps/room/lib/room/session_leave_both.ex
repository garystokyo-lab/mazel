defmodule Room.SessionLeaveBoth do
  @moduledoc """
  Both leave. Agent talk still ok both sides. Either
  rejoin restores that speaker on the same id.

  Distinct from session_leave_peer (one leaves).
  Off mint / Match / wiki. Not Consent.
  """

  def look_open(id), do: "ok  session=open  id=#{id}  talk=@kai/@ariel"
  def look_leave(who), do: "ok  leave=@#{local_of(who)}"
  def look_peer(who), do: "ok  talk=@#{local_of(who)}  peer=agent"
  def look_denied(who), do: "error  talk=@#{local_of(who)}  denied=left"
  def look_rejoin(id, who \\ "kai"), do: "ok  rejoin=@#{local_of(who)}  id=#{id}  same=true"
  def look_talk, do: "ok  talk=@kai  turn=1"

  def look(pack) when is_map(pack) do
    id = pack[:context_id] || pack[:id]

    [
      look_open(id),
      look_leave("kai"),
      look_leave("ariel"),
      look_peer("kai"),
      look_peer("ariel"),
      look_denied("kai"),
      look_denied("ariel"),
      look_rejoin(id, "kai"),
      look_talk()
    ]
  end

  def look(_), do: look(%{context_id: "session-leave-both"})

  @doc "Left speaker still talks agent-side."
  def talk_agent(context_id, who, text \\ "hello") do
    with {:ok, handle} <- Room.Cards.lookup(who) do
      Room.talk(context_id, handle, text, as: :agent)
    end
  end

  @doc """
  Both leave, both still talk as agents, human path
  denied, either rejoin talks. Isolated. Sibling peer
  / leave_talk LOOK stays.
  """
  def demo(opts \\ []) do
    id = Keyword.get(opts, :context_id) || "session-leave-both-" <> random_id()
    who = Keyword.get(opts, :rejoin) || "@kai"

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
         {:ok, opened} <-
           Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}]),
         {:ok, talked_kai} <- Room.talk(id, kai, "hello"),
         {:ok, talked_ariel} <- Room.talk(id, ariel, "hello"),
         {:ok, left_kai} <- Room.SessionLeave.leave(id, "@kai"),
         {:ok, left_ariel} <- Room.SessionLeave.leave(id, "@ariel"),
         {:ok, peer_kai} <- talk_agent(id, "@kai"),
         {:ok, peer_ariel} <- talk_agent(id, "@ariel"),
         {:error, :left} <- Room.talk(id, kai, "hello"),
         {:error, :left} <- Room.talk(id, ariel, "hello"),
         {:ok, back} <- Room.SessionRejoin.join(id, who),
         {:ok, again} <- Room.talk(id, kai, "hello") do
      cond do
        Room.SessionContext.id(opened) != id or Room.SessionContext.id(again) != id ->
          {:error, :id_drift}

        not Room.SessionContext.same?(opened, left_ariel) or
            not Room.SessionContext.same?(left_ariel, again) ->
          {:error, :id_drift}

        Room.SessionPresence.agents(left_ariel) != [] ->
          {:error, :not_empty}

        Room.SessionLeaveTalk.sit_turn(talked_kai, kai) != 1 or
            Room.SessionLeaveTalk.sit_turn(talked_ariel, ariel) != 1 ->
          {:error, :turn_miss}

        Room.SessionLeaveTalk.sit_turn(again, kai) != 1 ->
          {:error, :turn_miss}

        left_kai.status != :open or left_ariel.status != :open or again.status != :open ->
          {:error, :closed}

        minted?(opened) or minted?(peer_ariel) or minted?(again) ->
          {:error, :minted}

        humans_awake?(talked_kai) or humans_awake?(peer_ariel) or humans_awake?(again) ->
          {:error, :human_woke}

        true ->
          pack = %{
            context_id: id,
            opened: opened,
            talked_kai: talked_kai,
            talked_ariel: talked_ariel,
            left_kai: left_kai,
            left_ariel: left_ariel,
            peer_kai: peer_kai,
            peer_ariel: peer_ariel,
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

  defp local_of(who) do
    who
    |> to_string()
    |> String.trim_leading("@")
    |> String.split("@")
    |> hd()
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
