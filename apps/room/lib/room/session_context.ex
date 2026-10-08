defmodule Room.SessionContext do
  @moduledoc """
  contextId stays put across leave / rejoin.

  Distinct from session_rejoin (presence list, no
  contextId). Off mint / Match / wiki. Not Consent
  remorph (Room.rejoin).
  """

  def id(session) when is_map(session), do: session[:context_id] || session.context_id
  def id(_), do: nil

  def same?(before, after_session) do
    a = id(before)
    b = id(after_session)
    is_binary(a) and a != "" and a == b
  end

  def look_before(id), do: "ok  contextId=#{id}  before=leave"
  def look_leave, do: "ok  leave=@kai"
  def look_rejoin, do: "ok  rejoin=@kai"
  def look_same(id), do: "ok  contextId=#{id}  same=true"

  def look(pack) when is_map(pack) do
    cid = pack[:context_id] || pack[:id]
    [look_before(cid), look_leave(), look_rejoin(), look_same(cid)]
  end

  def look(_), do: look(%{context_id: "session-context"})

  @doc """
  Open Direct, leave @kai, rejoin @kai. contextId matches.
  Isolated. Sibling rejoin LOOK stays (no contextId=).
  """
  def demo(opts \\ []) do
    id = Keyword.get(opts, :context_id) || "session-context-" <> random_id()

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
         {:ok, opened} <-
           Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}]),
         {:ok, left} <- Room.SessionLeave.leave(id, "@kai"),
         {:ok, back} <- Room.SessionRejoin.join(id, "@kai") do
      cond do
        id(opened) != id or id(left) != id or id(back) != id ->
          {:error, :id_drift}

        not same?(opened, left) or not same?(left, back) ->
          {:error, :id_drift}

        left.status != :open or back.status != :open ->
          {:error, :closed}

        minted?(opened) or minted?(left) or minted?(back) ->
          {:error, :minted}

        not left_event?(left) or not joined_event?(back) ->
          {:error, :seat_miss}

        Room.SessionPresence.agents(back) != ["ariel@mazel", "kai@mazel"] ->
          {:error, :presence_miss}

        true ->
          pack = %{
            context_id: id,
            opened: opened,
            left: left,
            back: back
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp minted?(session) do
    events = Enum.map(session.events || [], & &1.type)
    session.badge != nil or "morph.commit" in events or "morph.rejoin" in events
  end

  defp left_event?(session) do
    Enum.any?(session.events || [], &(&1.type == "session.leave"))
  end

  defp joined_event?(session) do
    Enum.any?(session.events || [], &(&1.type == "session.join"))
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
