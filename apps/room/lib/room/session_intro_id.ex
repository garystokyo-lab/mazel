defmodule Room.SessionIntroId do
  @moduledoc """
  Intro open still gets a session id + talk.

  Morph denied without a badge. Distinct from session_intro
  (🪽🪽 session=agent, no id=) and session_direct_id
  (Direct, not Intro). Off mint / Match / wiki / Consent / A2A.
  """

  def look_intro(id), do: "ok  intro=#{Room.SessionIntro.wing_mark()}  id=#{id}"
  def look_talk, do: Room.MatchChatDirect.look_talk()
  def look_denied, do: Room.MatchChatDirect.look_denied()

  def look(pack) when is_map(pack) do
    [look_intro(pack.open_id), look_talk(), look_denied()]
  end

  def look(_), do: look(%{open_id: "session-intro-a"})

  @doc """
  Open Intro @kai with an explicit id. One talk.
  Morph denied. Isolated. Sibling intro / Direct LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-intro-" <> random_id()

    with {:ok, asked} <-
           Room.SessionIntro.ask(
             command: Keyword.get(opts, :command) || Room.SessionIntro.command(),
             context_id: prefix
           ),
         {:ok, after_talk} <- Room.talk(asked.session.context_id, asked.peer, asked.cmd.text),
         {:error, :badge_required} <- Room.propose_morph(prefix, asked.speaker) do
      talks = Enum.filter(after_talk.events || [], &(&1.type == "talk"))
      events = Enum.map(after_talk.events || [], & &1.type)
      id = Room.SessionContext.id(after_talk)

      cond do
        asked.cmd.session_kind != :intro or after_talk.session_kind != :intro ->
          {:error, :not_intro}

        id != prefix or id == nil ->
          {:error, :id_miss}

        after_talk.badge != nil or "morph.commit" in events ->
          {:error, :morphed}

        length(talks) != 1 or after_talk.status != :open ->
          {:error, :talk_miss}

        humans_awake?(after_talk) ->
          {:error, :human_woke}

        true ->
          pack = %{
            cmd: asked.cmd,
            session: after_talk,
            peer: asked.peer,
            open_id: id,
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
