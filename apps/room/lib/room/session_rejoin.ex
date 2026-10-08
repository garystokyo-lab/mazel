defmodule Room.SessionRejoin do
  @moduledoc """
  Left agent rejoins Direct / Intro / Group. Presence
  updates. Session stays open. Distinct from
  session_leave (leave only, no rejoin). Off mint /
  Match / wiki. Not Consent remorph (Room.rejoin).
  """

  def look_rejoin(who, kind, agent_ids) do
    local = who |> to_string() |> String.trim_leading("@") |> String.split("@") |> hd()
    listed = agent_ids |> List.wrap() |> Enum.join(",")
    "ok  rejoin=@#{local}  presence=#{kind}  agents=[#{listed}]"
  end

  def look(pack) when is_map(pack) do
    [
      Room.SessionLeave.look_leave("kai", :direct, pack[:left][:direct][:agents] || []),
      look_rejoin("kai", :direct, pack[:direct][:agents] || []),
      Room.SessionLeave.look_leave("kai", :intro, pack[:left][:intro][:agents] || []),
      look_rejoin("kai", :intro, pack[:intro][:agents] || []),
      Room.SessionLeave.look_leave("nova", :group, pack[:left][:group][:agents] || []),
      look_rejoin("nova", :group, pack[:group][:agents] || []),
      Room.SessionLeave.look_open()
    ]
  end

  def look(_), do: look(%{})

  @doc "Resolve and sit back down. Needs a prior session.leave."
  def join(context_id, who) do
    with {:ok, handle} <- Room.Cards.lookup(who) do
      Room.join(context_id, handle)
    end
  end

  @doc """
  Leave one agent from each wing, then rejoin them.
  Presence lists them again. Session stays open. Isolated.
  Sibling leave LOOK stays (no rejoin=).
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-rejoin-" <> random_id()

    with {:ok, left} <- Room.SessionLeave.demo(context_id: prefix),
         {:ok, direct} <- join(left.direct.session.context_id, "@kai"),
         {:ok, intro} <- join(left.intro.session.context_id, "@kai"),
         {:ok, group} <- join(left.group.session.context_id, "@nova") do
      seats = %{
        left: left,
        direct: Room.SessionPresence.of(direct) |> Map.put(:session, direct),
        intro: Room.SessionPresence.of(intro) |> Map.put(:session, intro),
        group: Room.SessionPresence.of(group) |> Map.put(:session, group)
      }

      cond do
        seats.direct.agents != ["ariel@mazel", "kai@mazel"] ->
          {:error, :direct_miss}

        seats.intro.agents != ["ariel@mazel", "kai@mazel"] ->
          {:error, :intro_miss}

        seats.group.agents != ["ariel@mazel", "kai@mazel", "nova@mazel"] ->
          {:error, :group_miss}

        seats.direct.session.status != :open or seats.intro.session.status != :open or
            seats.group.session.status != :open ->
          {:error, :closed}

        minted?(direct) or minted?(intro) or minted?(group) ->
          {:error, :minted}

        not joined_event?(direct) or not joined_event?(intro) or not joined_event?(group) ->
          {:error, :join_miss}

        not left_event?(direct) or not left_event?(intro) or not left_event?(group) ->
          {:error, :leave_miss}

        true ->
          {:ok, Map.put(seats, :lines, look(seats))}
      end
    end
  end

  defp minted?(session) do
    events = Enum.map(session.events || [], & &1.type)
    session.badge != nil or "morph.commit" in events or "morph.rejoin" in events
  end

  defp joined_event?(session) do
    Enum.any?(session.events || [], &(&1.type == "session.join"))
  end

  defp left_event?(session) do
    Enum.any?(session.events || [], &(&1.type == "session.leave"))
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
