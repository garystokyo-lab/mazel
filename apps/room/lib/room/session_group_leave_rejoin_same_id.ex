defmodule Room.SessionGroupLeaveRejoinSameId do
  @moduledoc """
  Group open → leave → rejoin keeps the same id.

  Distinct from session_group_id (Group id+talk, no
  leave) and session_intro_leave_rejoin_same_id (Intro
  path, not Group). Off mint / Match / wiki / Consent /
  A2A.
  """

  def look_group(id), do: Room.SessionGroupId.look_group(id)
  def look_talk_group, do: Room.SessionGroup.look_talk()
  def look_talk(n \\ 2), do: Room.MatchChat.look_talk(%{local: "kai"}, n)
  def look_left, do: Room.SessionDiscoveryPickLeave.look_left()
  def look_rejoin(id), do: Room.SessionLeaveTalk.look_rejoin(id)
  def look_denied, do: Room.SessionGroupId.look_denied()

  def look(pack) when is_map(pack) do
    id = pack[:open_id] || pack[:context_id]

    [
      look_group(id),
      look_talk_group(),
      look_left(),
      look_rejoin(id),
      look_talk(2),
      look_denied()
    ]
  end

  def look(_), do: look(%{open_id: "session-group-a"})

  @doc """
  Group id + talk, leave denies talk, rejoin same id
  resumes (turn=2). Morph denied. Isolated. Sibling
  group_id / intro leave-rejoin LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-group-" <> random_id()

    with {:ok, asked} <-
           Room.SessionGroup.ask(
             command: Keyword.get(opts, :command) || Room.SessionGroup.command(),
             context_id: prefix
           ),
         {:ok, talked} <- Room.talk(asked.session.context_id, asked.peer, asked.cmd.text),
         {:ok, left} <- Room.SessionLeave.leave(prefix, asked.peer),
         {:error, :left} <- Room.talk(prefix, asked.peer, asked.cmd.text),
         {:ok, back} <- Room.SessionRejoin.join(prefix, asked.peer),
         {:ok, again} <- Room.talk(prefix, asked.peer, asked.cmd.text),
         {:error, :badge_required} <- Room.propose_morph(prefix, asked.speaker) do
      events = Enum.map(again.events || [], & &1.type)
      id = Room.SessionContext.id(again)
      peers = Enum.map(asked.peers, & &1.id)

      cond do
        asked.cmd.session_kind != :group or talked.session_kind != :group or
            again.session_kind != :group ->
          {:error, :not_group}

        peers != ["kai@mazel", "nova@mazel"] ->
          {:error, :peer_miss}

        id != prefix or id == nil ->
          {:error, :id_miss}

        not Room.SessionContext.same?(talked, left) or not Room.SessionContext.same?(left, again) ->
          {:error, :id_drift}

        Room.SessionDiscoveryPickLeave.talk_turn(talked, asked.peer) != 1 ->
          {:error, :turn_miss}

        Room.SessionDiscoveryPickLeave.talk_turn(again, asked.peer) != 2 ->
          {:error, :resume_miss}

        left.status != :open or back.status != :open or again.status != :open ->
          {:error, :closed}

        again.badge != nil or "morph.commit" in events or "morph.rejoin" in events ->
          {:error, :morphed}

        humans_awake?(talked) or humans_awake?(again) ->
          {:error, :human_woke}

        look_group(id) == Room.SessionIntroId.look_intro(id) ->
          {:error, :intro_look}

        look_talk_group() == Room.MatchChat.look_talk(%{local: "kai"}, 1) ->
          {:error, :intro_talk}

        true ->
          pack = %{
            cmd: asked.cmd,
            peer: asked.peer,
            peers: asked.peers,
            speaker: asked.speaker,
            opened: asked.session,
            talked: talked,
            left: left,
            back: back,
            again: again,
            session: again,
            open_id: id,
            same: true,
            denied: :badge_required
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end