defmodule Room.SessionIntroNoBadge do
  @moduledoc """
  Intro ask without a badge: agents talk, human join blocked.

  Distinct from session_intro_badge_return (badge present →
  morph → human talk), session_intro_id (morph denied; no
  agent=1 / human=blocked strip), and session_intro
  (session=agent, no id=). Intro 1-on-1 only. Off Group /
  wiki / Match-core / A2A / Trust / Consent mint-core.
  """

  def look_intro(id), do: Room.SessionIntroId.look_intro(id)
  def look_talk, do: "ok  talk=@kai  agent=1  turn=1"
  def look_denied, do: Room.SessionIntroId.look_denied()
  def look_blocked, do: "error  human=blocked  join=none"

  def look(pack) when is_map(pack) do
    [look_intro(pack.open_id), look_talk(), look_denied(), look_blocked()]
  end

  def look(_), do: look(%{open_id: "session-intro-a"})

  @doc """
  Intro ask, one agent talk, morph denied, sit blocked.
  Isolated. Sibling intro_id / badge_return / intro stay.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-intro-no-badge-" <> random_id()

    with {:ok, opened} <-
           Room.SessionIntroId.demo(Keyword.put(opts, :context_id, prefix)),
         {:error, :badge_required} <- Room.sit_humans(prefix) do
      agents = Room.SessionPresence.agents(opened.session)
      humans = Room.SessionPresence.humans(opened.session)
      talks = Enum.filter(opened.session.events || [], &(&1.type == "talk"))
      events = Enum.map(opened.session.events || [], & &1.type)

      cond do
        opened.cmd.session_kind != :intro or opened.session.session_kind != :intro ->
          {:error, :not_intro}

        opened.denied != :badge_required ->
          {:error, :denied_miss}

        opened.session.badge != nil or "morph.commit" in events ->
          {:error, :morphed}

        length(talks) != 1 or opened.session.status != :open ->
          {:error, :talk_miss}

        humans != [] or humans_awake?(opened.session) ->
          {:error, :human_woke}

        "ariel@mazel" not in agents or "kai@mazel" not in agents ->
          {:error, :agent_miss}

        look_talk() != "ok  talk=@kai  agent=1  turn=1" ->
          {:error, :talk_miss}

        look_blocked() != "error  human=blocked  join=none" ->
          {:error, :join_miss}

        true ->
          pack =
            Map.merge(opened, %{
              blocked: :badge_required,
              join: :none,
              agents: agents,
              humans: humans
            })

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