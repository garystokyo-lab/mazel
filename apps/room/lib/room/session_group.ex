defmodule Room.SessionGroup do
  @moduledoc """
  🪽🪽🪽 group ask opens an agent group session.

  Talk stays in-agent. No human wake without a Consent
  stamp. Session owns the ask — does not mint. Distinct
  from session_intro (🪽🪽), session_discovery_* , and
  group_e2e (mint + morph). Off wiki / PDF / score.
  """

  @wing "🪽🪽🪽"
  @command "🪽🪽🪽 @kai @nova sit together"

  def wing_mark, do: @wing
  def command, do: @command

  def look_group(_pack \\ %{}), do: "ok  group=#{@wing}  session=agent"
  def look_talk, do: "ok  talk=@kai,@nova  turn=1"
  def look_asleep, do: "error  human=asleep  stamp=none"

  def look(_pack \\ nil) do
    [look_group(), look_talk(), look_asleep()]
  end

  @doc """
  Parse a 🪽🪽🪽 group ask and open an agent group session.
  Direct / intro wings miss. Never mints a stamp.
  """
  def ask(opts \\ []) when is_list(opts) do
    command = Keyword.get(opts, :command) || @command
    prefix = Keyword.get(opts, :context_id) || "session-group-" <> random_id()
    from = Keyword.get(opts, :from) || "@ariel"

    with {:ok, cmd} <- Room.Wings.parse(command) do
      cond do
        cmd.session_kind != :group or Room.Types.wing_mark(cmd.session_kind) != @wing ->
          {:error, :not_group}

        length(List.wrap(cmd.targets)) < 2 ->
          {:error, :need_invitees}

        true ->
          open_agents(prefix, from, cmd)
      end
    end
  end

  @doc """
  Group ask → agent session → one talk. Human stays asleep
  (stamp=none). Isolated. Sibling intro / e2e LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-group-" <> random_id()

    with {:ok, asked} <- ask(command: Keyword.get(opts, :command) || @command, context_id: prefix),
         {:ok, after_talk} <- Room.talk(asked.session.context_id, asked.peer, asked.cmd.text),
         {:ok, :soft_no} <- Room.SoftNo.agent(after_talk),
         {:error, :human_asleep} <- Room.SoftNo.wake(after_talk) do
      talks = Enum.filter(after_talk.events || [], &(&1.type == "talk"))
      events = Enum.map(after_talk.events || [], & &1.type)
      peers = Enum.map(asked.peers, & &1.id)

      cond do
        asked.cmd.session_kind != :group or after_talk.session_kind != :group ->
          {:error, :not_group}

        peers != ["kai@mazel", "nova@mazel"] ->
          {:error, :peer_miss}

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
            peers: asked.peers
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp open_agents(prefix, from, cmd) do
    with {:ok, speaker} <- Room.Cards.lookup(from),
         {:ok, peers} <- resolve_peers(cmd.targets) do
      people =
        [speaker | peers]
        |> Enum.uniq_by(& &1.id)
        |> Enum.map(&%{handle: &1, role: :agent})

      case Room.open(prefix, :group, people) do
        {:ok, session} ->
          {:ok, %{cmd: cmd, session: session, speaker: speaker, peer: hd(peers), peers: peers}}

        error ->
          error
      end
    end
  end

  defp resolve_peers(targets) do
    resolved = Enum.map(targets, &Room.Cards.lookup/1)

    case Enum.find(resolved, &match?({:error, _}, &1)) do
      {:error, reason} -> {:error, reason}
      nil -> {:ok, Enum.map(resolved, fn {:ok, card} -> card end)}
    end
  end

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
