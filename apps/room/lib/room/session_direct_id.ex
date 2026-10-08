defmodule Room.SessionDirectId do
  @moduledoc """
  Direct open (no Intro) still gets a session id + talk.

  Distinct from match_chat_direct / session_discovery_direct
  (talk, no id=) and session_intro (🪽🪽). Off mint /
  Match / wiki / Consent / A2A.
  """

  def look_direct(id), do: "ok  direct=@kai  id=#{id}"
  def look_talk, do: Room.MatchChatDirect.look_talk()
  def look_denied, do: Room.MatchChatDirect.look_denied()

  def look(pack) when is_map(pack) do
    [look_direct(pack.open_id), look_talk(), look_denied()]
  end

  def look(_), do: look(%{open_id: "session-direct-a"})

  @doc """
  Open Direct @kai with an explicit id. One talk.
  Morph denied. Isolated. Sibling direct / discovery
  / intro LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-direct-" <> random_id()

    with {:ok, prior} <- Room.MatchChatDirect.demo(Keyword.put(opts, :context_id, prefix)) do
      id = Room.SessionContext.id(prior.session)

      cond do
        prior.session.session_kind != :direct ->
          {:error, :not_direct}

        id != prefix or id == nil ->
          {:error, :id_miss}

        prior.denied != :badge_required ->
          {:error, :denied_miss}

        prior.session.status != :open ->
          {:error, :session_miss}

        minted?(prior.session) ->
          {:error, :minted}

        true ->
          pack =
            Map.merge(prior, %{
              open_id: id,
              same: true
            })

          {:ok, Map.put(pack, :lines, look(pack))}
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
