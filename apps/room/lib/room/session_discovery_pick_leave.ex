defmodule Room.SessionDiscoveryPickLeave do
  @moduledoc """
  Discovery-pick Direct, leave mid-talk, rejoin same id.

  pick kai → Direct id + talk. Leave denies talk.
  Rejoin same Direct id resumes (turn=2). Distinct from
  session_discovery_pick (pick→talk, no leave) and
  session_leave_talk (match Direct path, no discovery
  pick). Off mint / Match / wiki / Consent / A2A.
  """

  def look_discovery(handles \\ ["kai@mazel", "nova@mazel"]) do
    Room.SessionDiscoveryPick.look_discovery(handles)
  end

  def look_pick(id, handle \\ "kai@mazel") do
    Room.SessionDiscoveryPick.look_pick(id, handle)
  end

  def look_talk(n \\ 1), do: Room.MatchChat.look_talk(%{local: "kai"}, n)

  def look_left, do: "error  leave=@kai  denied=left  talk=none"

  def look_rejoin(id), do: Room.SessionLeaveTalk.look_rejoin(id)

  def look(pack) when is_map(pack) do
    id = pack[:open_id] || pack[:context_id]

    [
      look_discovery(pack[:handles]),
      look_pick(id, pack[:picked]),
      look_talk(1),
      look_left(),
      look_rejoin(id),
      look_talk(2)
    ]
  end

  def look(_),
    do: look(%{handles: ["kai@mazel", "nova@mazel"], picked: "kai@mazel", open_id: "session-direct-a"})

  @doc "Count talks from who across the whole session (resume, not sit)."
  def talk_turn(session, who) when is_map(session) do
    want = local_of(who)

    (session[:events] || session.events || [])
    |> Enum.count(fn event ->
      event.type == "talk" and from_local(event) == want
    end)
  end

  def talk_turn(_, _), do: 0

  @doc """
  Discovery pick kai → Direct talk, leave, rejoin same id.
  Isolated. Sibling pick / leave_talk LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-direct-" <> random_id()
    want = Keyword.get(opts, :pick) || "kai@mazel"

    need = Room.SelfReportMatch.parse(Keyword.get(opts, :need) || "need: series-a")
    has_kai = Room.SelfReportMatch.report(:has, "series-a", handle: "kai@mazel")
    has_nova = Room.SelfReportMatch.report(:has, "series-a", handle: "nova@mazel")
    hits = Room.SelfReportMatch.match_all([has_kai, has_nova], need)
    found = Room.SessionDiscovery.handles(hits)
    picked = Room.SessionDiscovery.pick(found, want)

    with picked when is_binary(picked) <- picked,
         {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, peer} <- Room.Cards.lookup(picked),
         {:ok, opened} <-
           Room.open(prefix, :direct, [
             %{handle: ariel, role: :agent},
             %{handle: peer, role: :agent}
           ]),
         {:ok, talked} <- Room.talk(prefix, peer, "hello"),
         {:ok, left} <- Room.SessionLeave.leave(prefix, picked),
         {:error, :left} <- Room.talk(prefix, peer, "hello"),
         {:ok, back} <- Room.SessionRejoin.join(prefix, picked),
         {:ok, again} <- Room.talk(prefix, peer, "hello") do
      id = Room.SessionContext.id(again)
      events = Enum.map(again.events || [], & &1.type)

      cond do
        not Room.Need.discovery_sink?("need@mazel") ->
          {:error, :sink_miss}

        found != ["kai@mazel", "nova@mazel"] ->
          {:error, :handle_miss}

        picked != "kai@mazel" ->
          {:error, :pick_miss}

        opened.session_kind != :direct or again.session_kind != :direct ->
          {:error, :not_direct}

        id != prefix or id == nil ->
          {:error, :id_miss}

        not Room.SessionContext.same?(opened, left) or not Room.SessionContext.same?(left, again) ->
          {:error, :id_drift}

        talk_turn(talked, peer) != 1 ->
          {:error, :turn_miss}

        talk_turn(again, peer) != 2 ->
          {:error, :resume_miss}

        left.status != :open or back.status != :open or again.status != :open ->
          {:error, :closed}

        again.badge != nil or "morph.commit" in events or "morph.rejoin" in events ->
          {:error, :morphed}

        humans_awake?(talked) or humans_awake?(again) ->
          {:error, :human_woke}

        true ->
          pack = %{
            handles: found,
            picked: picked,
            hits: hits,
            opened: opened,
            talked: talked,
            left: left,
            back: back,
            again: again,
            session: again,
            open_id: id,
            same: true
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    else
      nil -> {:error, :pick_miss}
      other -> other
    end
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
