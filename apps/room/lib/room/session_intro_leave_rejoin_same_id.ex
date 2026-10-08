defmodule Room.SessionIntroLeaveRejoinSameId do
  @moduledoc """
  Intro open → leave → rejoin keeps the same id.

  Distinct from session_intro_id (Intro id+talk, no leave),
  session_leave_talk / session_discovery_pick_leave (Direct
  path, not Intro), and session_rejoin (presence rejoin
  without Intro id strip). Off mint / Match / wiki /
  Consent / A2A.
  """

  def look_intro(id), do: Room.SessionIntroId.look_intro(id)
  def look_talk(n \\ 1), do: Room.MatchChat.look_talk(%{local: "kai"}, n)
  def look_left, do: Room.SessionDiscoveryPickLeave.look_left()
  def look_rejoin(id), do: Room.SessionLeaveTalk.look_rejoin(id)
  def look_denied, do: Room.SessionIntroId.look_denied()

  def look(pack) when is_map(pack) do
    id = pack[:open_id] || pack[:context_id]

    [
      look_intro(id),
      look_talk(1),
      look_left(),
      look_rejoin(id),
      look_talk(2),
      look_denied()
    ]
  end

  def look(_), do: look(%{open_id: "session-intro-a"})

  @doc """
  Intro id + talk, leave denies talk, rejoin same id
  resumes (turn=2). Morph denied. Isolated. Sibling
  intro_id / leave_talk / pick_leave / rejoin LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-intro-" <> random_id()

    with {:ok, asked} <-
           Room.SessionIntro.ask(
             command: Keyword.get(opts, :command) || Room.SessionIntro.command(),
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

      cond do
        asked.cmd.session_kind != :intro or talked.session_kind != :intro or
            again.session_kind != :intro ->
          {:error, :not_intro}

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

        true ->
          pack = %{
            cmd: asked.cmd,
            peer: asked.peer,
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
