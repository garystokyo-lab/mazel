defmodule Room.SessionLeaveTalk do
  @moduledoc """
  Leave mid-chat denies talk until rejoin. Same session
  id still talks after sit-back.

  Distinct from session_leave / session_rejoin (no talk
  gate) and session_context (contextId, no talk=). Off
  mint / Match / wiki. Not Consent remorph. Not TTL.
  """

  def look_open(id), do: "ok  session=open  id=#{id}  talk=@kai  turn=1"
  def look_leave, do: "ok  leave=@kai"
  def look_denied, do: "error  talk=@kai  denied=left"
  def look_rejoin(id), do: "ok  rejoin=@kai  id=#{id}  same=true"
  def look_talk, do: "ok  talk=@kai  turn=1"

  def look(pack) when is_map(pack) do
    id = pack[:context_id] || pack[:id]
    [look_open(id), look_leave(), look_denied(), look_rejoin(id), look_talk()]
  end

  def look(_), do: look(%{context_id: "session-leave-talk"})

  def sit_turn(session, who) when is_map(session) do
    want = local_of(who)
    events = session[:events] || session.events || []

    start =
      events
      |> Enum.with_index()
      |> Enum.filter(fn {event, _} ->
        event.type == "session.join" and from_local(event) == want
      end)
      |> List.last()
      |> case do
        {_, index} -> index + 1
        nil -> 0
      end

    events
    |> Enum.drop(start)
    |> Enum.count(fn event ->
      event.type == "talk" and from_local(event) == want
    end)
  end

  def sit_turn(_, _), do: 0

  @doc """
  Open, talk, leave → talk denied, rejoin same id → talk.
  Isolated. Sibling leave / rejoin / context LOOK stays.
  """
  def demo(opts \\ []) do
    id = Keyword.get(opts, :context_id) || "session-leave-talk-" <> random_id()

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
         {:ok, opened} <-
           Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}]),
         {:ok, talked} <- Room.talk(id, kai, "hello"),
         {:ok, left} <- Room.SessionLeave.leave(id, "@kai"),
         {:error, :left} <- Room.talk(id, kai, "hello"),
         {:ok, back} <- Room.SessionRejoin.join(id, "@kai"),
         {:ok, again} <- Room.talk(id, kai, "hello") do
      cond do
        Room.SessionContext.id(opened) != id or Room.SessionContext.id(again) != id ->
          {:error, :id_drift}

        not Room.SessionContext.same?(opened, left) or not Room.SessionContext.same?(left, again) ->
          {:error, :id_drift}

        sit_turn(talked, kai) != 1 or sit_turn(again, kai) != 1 ->
          {:error, :turn_miss}

        left.status != :open or back.status != :open or again.status != :open ->
          {:error, :closed}

        minted?(opened) or minted?(talked) or minted?(again) ->
          {:error, :minted}

        humans_awake?(talked) or humans_awake?(again) ->
          {:error, :human_woke}

        true ->
          pack = %{
            context_id: id,
            opened: opened,
            talked: talked,
            left: left,
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
    |> then(fn
      %{id: id} -> id
      other -> to_string(other)
    end)
    |> String.trim_leading("@")
    |> String.split("@")
    |> hd()
  end

  defp from_local(%{payload: payload}) do
    from = payload[:from] || payload["from"]
    local_of(from || "")
  end

  defp from_local(_), do: ""

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
