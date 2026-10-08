defmodule Room.SessionLeaveBothPartial do
  @moduledoc """
  Both leave. One rejoin talks; the other stays denied
  until they rejoin too.

  Distinct from session_leave_both (one rejoin restores
  that speaker; does not print the other still denied).
  Off mint / Match / wiki. Not Consent.
  """

  def look_leave(who), do: Room.SessionLeaveBoth.look_leave(who)
  def look_rejoin(who), do: "ok  rejoin=@#{local_of(who)}  same=true"
  def look_talk(who), do: "ok  talk=@#{local_of(who)}  turn=1"
  def look_denied(who), do: Room.SessionLeaveBoth.look_denied(who)

  def look(_pack \\ %{}) do
    [
      look_leave("kai"),
      look_leave("ariel"),
      look_rejoin("kai"),
      look_talk("kai"),
      look_denied("ariel"),
      look_rejoin("ariel"),
      look_talk("ariel")
    ]
  end

  @doc """
  Both leave, kai rejoins and talks, ariel still denied,
  ariel rejoins and talks. Isolated. Sibling leave_both
  LOOK stays.
  """
  def demo(opts \\ []) do
    id = Keyword.get(opts, :context_id) || "session-leave-both-partial-" <> random_id()

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
         {:ok, opened} <-
           Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}]),
         {:ok, left_kai} <- Room.SessionLeave.leave(id, "@kai"),
         {:ok, left_ariel} <- Room.SessionLeave.leave(id, "@ariel"),
         {:ok, kai_back} <- Room.SessionRejoin.join(id, "@kai"),
         {:ok, kai_talk} <- Room.talk(id, kai, "hello"),
         {:error, :left} <- Room.talk(id, ariel, "hello"),
         {:ok, ariel_back} <- Room.SessionRejoin.join(id, "@ariel"),
         {:ok, ariel_talk} <- Room.talk(id, ariel, "hello") do
      cond do
        Room.SessionContext.id(opened) != id or Room.SessionContext.id(ariel_talk) != id ->
          {:error, :id_drift}

        not Room.SessionContext.same?(opened, left_ariel) or
            not Room.SessionContext.same?(left_ariel, kai_talk) or
            not Room.SessionContext.same?(kai_talk, ariel_talk) ->
          {:error, :id_drift}

        Room.SessionPresence.agents(left_ariel) != [] ->
          {:error, :not_empty}

        Room.SessionLeaveTalk.sit_turn(kai_talk, kai) != 1 ->
          {:error, :turn_miss}

        Room.SessionLeaveTalk.sit_turn(ariel_talk, ariel) != 1 ->
          {:error, :turn_miss}

        left_kai.status != :open or left_ariel.status != :open or ariel_talk.status != :open ->
          {:error, :closed}

        minted?(opened) or minted?(kai_talk) or minted?(ariel_talk) ->
          {:error, :minted}

        humans_awake?(opened) or humans_awake?(kai_talk) or humans_awake?(ariel_talk) ->
          {:error, :human_woke}

        true ->
          pack = %{
            context_id: id,
            opened: opened,
            left_kai: left_kai,
            left_ariel: left_ariel,
            kai_back: kai_back,
            kai_talk: kai_talk,
            ariel_back: ariel_back,
            ariel_talk: ariel_talk,
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