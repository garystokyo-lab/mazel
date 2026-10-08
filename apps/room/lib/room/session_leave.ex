defmodule Room.SessionLeave do
  @moduledoc """
  Agent leaves Direct / Intro / Group. Presence updates.

  Session stays open for remaining. Distinct from
  session_presence (static list, no leave). Off mint /
  Match / wiki.
  """

  def look_leave(who, kind, agent_ids) do
    local = who |> to_string() |> String.trim_leading("@") |> String.split("@") |> hd()
    listed = agent_ids |> List.wrap() |> Enum.join(",")
    "ok  leave=@#{local}  presence=#{kind}  agents=[#{listed}]"
  end

  def look_open, do: "ok  session=agent  still_open=true"

  def look(pack) when is_map(pack) do
    [
      look_leave("kai", :direct, pack[:direct][:agents] || []),
      look_leave("kai", :intro, pack[:intro][:agents] || []),
      look_leave("nova", :group, pack[:group][:agents] || []),
      look_open()
    ]
  end

  def look(_), do: look(%{})

  @doc "Resolve and leave. Session stays if someone remains."
  def leave(context_id, who) do
    with {:ok, handle} <- Room.Cards.lookup(who) do
      Room.leave(context_id, handle)
    end
  end

  @doc """
  Leave one agent from each wing. Presence drops them.
  Remaining stay; session stays open. Isolated.
  Sibling presence LOOK stays (no leave=).
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-leave-" <> random_id()

    with {:ok, seats} <- Room.SessionPresence.demo(context_id: prefix),
         {:ok, direct} <- leave(seats.direct.session.context_id, "@kai"),
         {:ok, intro} <- leave(seats.intro.session.context_id, "@kai"),
         {:ok, group} <- leave(seats.group.session.context_id, "@nova") do
      left = %{
        direct: Room.SessionPresence.of(direct) |> Map.put(:session, direct),
        intro: Room.SessionPresence.of(intro) |> Map.put(:session, intro),
        group: Room.SessionPresence.of(group) |> Map.put(:session, group)
      }

      cond do
        left.direct.agents != ["ariel@mazel"] ->
          {:error, :direct_miss}

        left.intro.agents != ["ariel@mazel"] ->
          {:error, :intro_miss}

        left.group.agents != ["ariel@mazel", "kai@mazel"] ->
          {:error, :group_miss}

        left.direct.session.status != :open or left.intro.session.status != :open or
            left.group.session.status != :open ->
          {:error, :closed}

        minted?(direct) or minted?(intro) or minted?(group) ->
          {:error, :minted}

        not left_event?(direct) or not left_event?(intro) or not left_event?(group) ->
          {:error, :leave_miss}

        true ->
          {:ok, Map.put(left, :lines, look(left))}
      end
    end
  end

  defp minted?(session) do
    events = Enum.map(session.events || [], & &1.type)
    session.badge != nil or "morph.commit" in events
  end

  defp left_event?(session) do
    Enum.any?(session.events || [], &(&1.type == "session.leave"))
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
