defmodule Room.SessionIntro do
  @moduledoc """
  🪽🪽 intro ask opens an agent intro session.

  Talk stays in-agent. No human wake without a Consent
  stamp. Session owns the ask — does not mint. Distinct
  from session_discovery_* (need@mazel / Direct pick),
  match_chat_* (find / Direct), and intro_e2e (mint +
  morph). Off wiki / PDF / score.
  """

  @wing "🪽🪽"
  @command "🪽🪽 @kai series-A CTO"

  def wing_mark, do: @wing
  def command, do: @command

  def look_intro(_pack \\ %{}), do: "ok  intro=#{@wing}  session=agent"
  def look_talk, do: Room.MatchChat.look_talk(%{local: "kai"}, 1)
  def look_asleep, do: "error  human=asleep  stamp=none"

  def look(_pack \\ nil) do
    [look_intro(), look_talk(), look_asleep()]
  end

  @doc """
  Parse a 🪽🪽 intro ask and open an agent intro session.
  Direct / group wings miss. Never mints a stamp.
  """
  def ask(opts \\ []) when is_list(opts) do
    command = Keyword.get(opts, :command) || @command
    prefix = Keyword.get(opts, :context_id) || "session-intro-" <> random_id()
    from = Keyword.get(opts, :from) || "@ariel"

    with {:ok, cmd} <- Room.Wings.parse(command) do
      cond do
        cmd.session_kind != :intro or Room.Types.wing_mark(cmd.session_kind) != @wing ->
          {:error, :not_intro}

        true ->
          open_agents(prefix, from, cmd)
      end
    end
  end

  @doc """
  Intro ask → agent session → one talk. Human stays asleep
  (stamp=none). Isolated. Sibling discovery / Direct / e2e
  LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-intro-" <> random_id()

    with {:ok, asked} <- ask(command: Keyword.get(opts, :command) || @command, context_id: prefix),
         {:ok, after_talk} <- Room.talk(asked.session.context_id, asked.peer, asked.cmd.text),
         {:ok, :soft_no} <- Room.SoftNo.agent(after_talk),
         {:error, :human_asleep} <- Room.SoftNo.wake(after_talk) do
      talks = Enum.filter(after_talk.events || [], &(&1.type == "talk"))
      events = Enum.map(after_talk.events || [], & &1.type)

      cond do
        asked.cmd.session_kind != :intro or after_talk.session_kind != :intro ->
          {:error, :not_intro}

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
            peer: asked.peer
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp open_agents(prefix, from, cmd) do
    with {:ok, speaker} <- Room.Cards.lookup(from),
         {:ok, peer} <- Room.Cards.lookup(cmd.target),
         {:ok, session} <-
           Room.open(prefix, :intro, [
             %{handle: speaker, role: :agent},
             %{handle: peer, role: :agent}
           ]) do
      {:ok, %{cmd: cmd, session: session, speaker: speaker, peer: peer}}
    end
  end

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
