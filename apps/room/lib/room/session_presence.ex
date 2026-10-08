defmodule Room.SessionPresence do
  @moduledoc """
  Agent presence in Direct / Intro / Group.

  Who's in session. Humans only after Consent. Session
  owns the list — does not mint. Distinct from
  session_labels (id/label table) and session_intro /
  session_group (no presence list). Off Match / wiki.
  """

  @kinds [:direct, :intro, :group]

  def kinds, do: @kinds

  @doc "Agent handle ids in the session. Humans are not listed."
  def agents(session) when is_map(session) do
    if expired?(session) do
      []
    else
      session
      |> participants()
      |> Enum.filter(&(role(&1) == :agent))
      |> Enum.map(&handle_id/1)
      |> Enum.reject(&is_nil/1)
    end
  end

  def agents(_), do: []

  @doc "Human handle ids. Empty until Consent wakes them."
  def humans(session) when is_map(session) do
    if expired?(session) do
      []
    else
      session
      |> participants()
      |> Enum.filter(&(role(&1) == :human))
      |> Enum.map(&handle_id/1)
      |> Enum.reject(&is_nil/1)
    end
  end

  def humans(_), do: []

  def of(session) when is_map(session) do
    %{kind: session.session_kind, agents: agents(session), humans: humans(session)}
  end

  def look_presence(kind, agent_ids) do
    listed = agent_ids |> List.wrap() |> Enum.join(",")
    "ok  presence=#{kind}  agents=[#{listed}]"
  end

  def look_human(session \\ %{}) do
    if humans(session) == [] do
      "error  human=none  stamp=none"
    else
      listed = Enum.join(humans(session), ",")
      "ok  human=[#{listed}]  stamp=consent"
    end
  end

  def look(pack) when is_map(pack) do
    Enum.map(@kinds, fn kind ->
      look_presence(kind, pack[kind][:agents] || [])
    end) ++ [look_human(pack[:direct][:session] || %{})]
  end

  def look(_), do: look(%{})

  @doc """
  Open Direct / Intro / Group as agents. Presence lists
  who's in. Human stays none (stamp=none). Isolated.
  Sibling labels / intro / group LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-presence-" <> random_id()

    with {:ok, direct} <- open_kind(prefix, :direct, ["@ariel", "@kai"]),
         {:ok, intro} <- open_kind(prefix, :intro, ["@ariel", "@kai"]),
         {:ok, group} <- open_kind(prefix, :group, ["@ariel", "@kai", "@nova"]),
         {:error, :human_asleep} <- Room.SoftNo.wake(direct),
         {:error, :human_asleep} <- Room.SoftNo.wake(intro),
         {:error, :human_asleep} <- Room.SoftNo.wake(group) do
      seats = %{
        direct: of(direct) |> Map.put(:session, direct),
        intro: of(intro) |> Map.put(:session, intro),
        group: of(group) |> Map.put(:session, group)
      }

      cond do
        seats.direct.agents != ["ariel@mazel", "kai@mazel"] ->
          {:error, :direct_miss}

        seats.intro.agents != ["ariel@mazel", "kai@mazel"] ->
          {:error, :intro_miss}

        seats.group.agents != ["ariel@mazel", "kai@mazel", "nova@mazel"] ->
          {:error, :group_miss}

        seats.direct.humans != [] or seats.intro.humans != [] or seats.group.humans != [] ->
          {:error, :human_woke}

        minted?(direct) or minted?(intro) or minted?(group) ->
          {:error, :minted}

        true ->
          {:ok, Map.put(seats, :lines, look(seats))}
      end
    end
  end

  defp open_kind(prefix, kind, handles) do
    with {:ok, people} <- resolve(handles) do
      Room.open(
        "#{prefix}-#{kind}",
        kind,
        Enum.map(people, &%{handle: &1, role: :agent})
      )
    end
  end

  defp resolve(handles) do
    resolved = Enum.map(handles, &Room.Cards.lookup/1)

    case Enum.find(resolved, &match?({:error, _}, &1)) do
      {:error, reason} -> {:error, reason}
      nil -> {:ok, Enum.map(resolved, fn {:ok, card} -> card end)}
    end
  end

  defp minted?(session) do
    events = Enum.map(session.events || [], & &1.type)
    session.badge != nil or "morph.commit" in events or session.status != :open
  end

  defp expired?(session), do: Room.SessionTtl.freshness(session) == :expired

  defp participants(session) do
    session[:participants] || session.participants || []
  end

  defp role(p), do: p[:role] || p.role

  defp handle_id(p) do
    handle = p[:handle] || p.handle

    cond do
      is_map(handle) -> handle[:id] || handle.id
      is_binary(handle) -> handle
      true -> nil
    end
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
