defmodule Room.Context do
  @moduledoc "One in-memory room. Participants, badge, morph events, PubSub fanout."
  use GenServer

  def start_link(context_id) do
    GenServer.start_link(__MODULE__, context_id, name: via(context_id))
  end

  def via(context_id), do: {:via, Registry, {Room.Registry, context_id}}

  def open(context_id, session_kind, participants) do
    GenServer.call(via(context_id), {:open, session_kind, participants})
  end

  def submit_badge(context_id, badge) do
    GenServer.call(via(context_id), {:badge, badge})
  end

  def submit_postage(context_id, badge), do: submit_badge(context_id, badge)

  def propose_morph(context_id, from), do: GenServer.call(via(context_id), {:propose, from})
  def talk(context_id, from, text, opts \\ []) do
    GenServer.call(via(context_id), {:talk, from, text, opts})
  end
  def consent(context_id, handle), do: GenServer.call(via(context_id), {:consent, handle})
  def offline(context_id, handle), do: GenServer.call(via(context_id), {:offline, handle})
  def online(context_id, handle), do: GenServer.call(via(context_id), {:online, handle})

  def commit_morph(context_id, summary, transcript) do
    GenServer.call(via(context_id), {:commit, summary, transcript})
  end

  def return(context_id), do: GenServer.call(via(context_id), :return)
  def revoke(context_id, from), do: GenServer.call(via(context_id), {:revoke, from})
  def rejoin(context_id, badge), do: GenServer.call(via(context_id), {:rejoin, badge})
  def leave(context_id, from), do: GenServer.call(via(context_id), {:leave, from})
  def join(context_id, from), do: GenServer.call(via(context_id), {:join, from})
  def sit_humans(context_id), do: GenServer.call(via(context_id), :sit_humans)
  def drop_humans(context_id), do: GenServer.call(via(context_id), :drop_humans)
  def stamp_ttl(context_id, ttl, now \\ DateTime.utc_now()) do
    GenServer.call(via(context_id), {:stamp_ttl, ttl, now})
  end

  def stamp_consent_wait(context_id, ttl, now \\ DateTime.utc_now()) do
    GenServer.call(via(context_id), {:stamp_consent_wait, ttl, now})
  end

  def expire_consent_wait(context_id, now \\ DateTime.utc_now()) do
    stamp_consent_wait(context_id, :expired, now)
  end

  def soft_no_consent_wait(context_id, handle) do
    GenServer.call(via(context_id), {:soft_no_consent_wait, handle})
  end

  def get(context_id), do: GenServer.call(via(context_id), :get)

  @impl true
  def init(context_id) do
    {:ok,
     %{
       context_id: context_id,
       session_kind: nil,
       status: :empty,
       participants: [],
       badge: nil,
       consents: [],
       events: [],
       warm_packet: nil,
       revoked_by: nil,
       expires_at: nil,
       offline: [],
       consent_wait: nil,
       consent_wait_expires_at: nil
     }}
  end

  @impl true
  def handle_call({:open, session_kind, participants}, _from, state) do
    kind = Room.Types.session_kind(session_kind)

    participants =
      Enum.map(participants, fn p ->
        handle = normalize_handle(p[:handle] || p["handle"] || p)
        role = normalize_role(p[:role] || p["role"] || :agent)
        Room.Types.participant(handle, role)
      end)

    state =
      state
      |> Map.merge(%{session_kind: kind, participants: participants, status: :open})
      |> emit("room.open", %{session_kind: kind, wings: Room.Types.wing_mark(kind)})

    {:reply, {:ok, snapshot(state)}, state}
  end

  def handle_call({:badge, badge}, _from, state) do
    badge = normalize_badge(badge)

    case Room.Types.validate_badge(badge) do
      :ok ->
        state =
          state
          |> Map.merge(%{badge: badge, status: :badge_ok})
          |> emit("badge", badge)

        {:reply, {:ok, snapshot(state)}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:talk, from, text, opts}, _from, state) do
    from = normalize_handle(from)
    text = String.trim(to_string(text))
    as_agent? = Keyword.get(opts, :as) == :agent

    cond do
      not talkable?(state) ->
        {:reply, {:error, :not_open}, state}

      state.status != :morphed and ttl_expired?(state) ->
        {:reply, {:error, :ttl_expired}, state}

      not participant?(state, from) and left_before?(state, from) and as_agent? ->
        state = emit(state, "talk", %{from: from, text: text, as: :agent})
        {:reply, {:ok, snapshot(state)}, state}

      not participant?(state, from) and left_before?(state, from) ->
        {:reply, {:error, :left}, state}

      not participant?(state, from) ->
        {:reply, {:error, :unknown_participant}, state}

      text == "" ->
        {:reply, {:error, :empty_talk}, state}

      true ->
        state = emit(state, "talk", %{from: from, text: text})
        {:reply, {:ok, snapshot(state)}, state}
    end
  end

  def handle_call({:stamp_ttl, ttl, now}, _from, state) do
    cond do
      state.status != :open or state.badge != nil ->
        {:reply, {:error, :not_open}, state}

      ttl not in [:fresh, :expired] ->
        {:reply, {:error, :bad_ttl}, state}

      true ->
        expires_at = expires_at_for(ttl, now)

        state =
          state
          |> Map.put(:expires_at, expires_at)
          |> emit("session.ttl", %{ttl: ttl})

        {:reply, {:ok, snapshot(state)}, state}
    end
  end

  def handle_call({:stamp_consent_wait, ttl, now}, _from, state) do
    cond do
      state.status in [:morphed, :returned, :revoked] ->
        {:reply, {:error, :not_waiting}, state}

      not waiting_consent?(state) ->
        {:reply, {:error, :not_waiting}, state}

      ttl not in [:fresh, :expired] ->
        {:reply, {:error, :bad_ttl}, state}

      ttl == :fresh ->
        state =
          state
          |> Map.merge(%{
            consent_wait: :wait,
            consent_wait_expires_at: expires_at_for(:fresh, now)
          })
          |> emit("consent.wait", %{ttl: :fresh})

        {:reply, {:ok, snapshot(state)}, state}

      true ->
        state =
          state
          |> Map.merge(%{
            consents: [],
            consent_wait: :expired,
            consent_wait_expires_at: expires_at_for(:expired, now)
          })
          |> emit("consent.expired", %{wait: :cleared, morph: :none})

        {:reply, {:ok, snapshot(state)}, state}
    end
  end

  def handle_call({:soft_no_consent_wait, handle}, _from, state) do
    handle = normalize_handle(handle)

    cond do
      state.status in [:morphed, :returned, :revoked] ->
        {:reply, {:error, :not_waiting}, state}

      not waiting_consent?(state) ->
        {:reply, {:error, :not_waiting}, state}

      not participant?(state, handle) ->
        {:reply, {:error, :unknown_participant}, state}

      offline?(state, handle) ->
        {:reply, {:error, :offline}, state}

      not consented?(state, handle) ->
        {:reply, {:error, :not_consented}, state}

      true ->
        state =
          state
          |> Map.merge(%{
            consents: [],
            consent_wait: :cleared,
            consent_wait_expires_at: nil
          })
          |> emit("consent.soft_no", %{handle: handle, wait: :cleared, morph: :denied})

        {:reply, {:ok, snapshot(state)}, state}
    end
  end

  def handle_call({:propose, _from}, _caller, %{badge: nil} = state) do
    {:reply, {:error, :badge_required}, state}
  end

  def handle_call({:propose, from}, _from, state) do
    from = normalize_handle(from)

    if participant?(state, from) do
      state =
        state
        |> Map.put(:status, :morph_proposed)
        |> emit("morph.propose", %{from: from})

      {:reply, {:ok, snapshot(state)}, state}
    else
      {:reply, {:error, :unknown_participant}, state}
    end
  end

  def handle_call({:offline, handle}, _from, state) do
    handle = normalize_handle(handle)

    cond do
      not participant?(state, handle) ->
        {:reply, {:error, :unknown_participant}, state}

      true ->
        ids = Enum.uniq((state[:offline] || []) ++ [handle.id])

        state =
          state
          |> Map.put(:offline, ids)
          |> maybe_arm_consent_wait()
          |> emit("consent.offline", %{handle: handle})

        {:reply, {:ok, snapshot(state)}, state}
    end
  end

  def handle_call({:online, handle}, _from, state) do
    handle = normalize_handle(handle)

    cond do
      not participant?(state, handle) ->
        {:reply, {:error, :unknown_participant}, state}

      true ->
        ids = Enum.reject(state[:offline] || [], &(&1 == handle.id))

        state =
          state
          |> Map.put(:offline, ids)
          |> maybe_clear_consent_wait_on_return()
          |> emit("consent.online", %{handle: handle})

        {:reply, {:ok, snapshot(state)}, state}
    end
  end

  def handle_call({:consent, handle}, _from, state) do
    handle = normalize_handle(handle)

    cond do
      state.status not in [:morph_proposed, :consented] ->
        {:reply, {:error, :morph_not_proposed}, state}

      not participant?(state, handle) ->
        {:reply, {:error, :unknown_participant}, state}

      offline?(state, handle) ->
        {:reply, {:error, :offline}, state}

      consented?(state, handle) ->
        {:reply, {:ok, snapshot(state)}, state}

      true ->
        consent = %{handle: handle, granted_at: Room.Types.now_iso()}
        consents = state.consents ++ [consent]
        status = if dual_consent?(state.participants, consents), do: :consented, else: :morph_proposed

        state =
          state
          |> Map.merge(%{consents: consents, status: status})
          |> emit("consent", consent)

        {:reply, {:ok, snapshot(state)}, state}
    end
  end

  def handle_call({:commit, summary, transcript}, _from, state) do
    cond do
      is_nil(state.badge) ->
        {:reply, {:error, :badge_required}, state}

      state[:consent_wait] == :expired ->
        {:reply, {:error, :consent_expired}, state}

      state[:consent_wait] == :cleared ->
        {:reply, {:error, :soft_no}, state}

      peer_offline?(state) ->
        {:reply, {:error, :peer_offline}, state}

      not dual_consent?(state.participants, state.consents) ->
        {:reply, {:error, :dual_consent_required}, state}

      String.trim(to_string(summary)) == "" ->
        {:reply, {:error, :empty_summary}, state}

      true ->
        humans = implied_humans(state.participants)
        participants = merge_participants(state.participants, humans)
        committed_at = Room.Types.now_iso()

        packet = %{
          context_id: state.context_id,
          session_kind: state.session_kind,
          participants: Enum.map(participants, &Map.take(&1, [:handle, :role])),
          badge: state.badge,
          summary: summary,
          transcript_excerpt: transcript,
          committed_at: committed_at
        }

        state =
          state
          |> Map.merge(%{
            participants: participants,
            warm_packet: packet,
            status: :morphed
          })
          |> emit("morph.commit", %{warm_packet: packet})

        {:reply, {:ok, snapshot(state)}, state}
    end
  end

  def handle_call(:return, _from, state) do
    cond do
      state.status != :morphed or is_nil(state.warm_packet) ->
        {:reply, {:error, :morph_not_committed}, state}

      true ->
        agents = Enum.filter(state.participants, &(&1.role == :agent))

        state =
          state
          |> Map.merge(%{participants: agents, status: :returned})
          |> emit("return", %{morph: "closed", session: "agent"})

        {:reply, {:ok, snapshot(state)}, state}
    end
  end

  def handle_call({:revoke, from}, _from, state) do
    from = normalize_handle(from)

    cond do
      state.status == :revoked and participant?(state, from) ->
        state = revoke_again(state, from)
        {:reply, {:ok, snapshot(state)}, state}

      state.status != :morphed ->
        {:reply, {:error, :morph_not_committed}, state}

      not participant?(state, from) ->
        {:reply, {:error, :unknown_participant}, state}

      true ->
        agents = Enum.filter(state.participants, &(&1.role == :agent))

        state =
          state
          |> Map.merge(%{
            participants: agents,
            status: :revoked,
            badge: nil,
            consents: [],
            revoked_by: from
          })
          |> emit("morph.revoke", %{from: from, morph: "closed", session: "agent"})

        {:reply, {:ok, snapshot(state)}, state}
    end
  end

  def handle_call({:rejoin, badge}, _from, state) do
    badge = normalize_badge(badge)

    cond do
      state.status not in [:revoked, :returned] ->
        {:reply, {:error, :not_revoked}, state}

      true ->
        case Room.Types.validate_badge(badge) do
          :ok ->
            state =
              state
              |> Map.merge(%{
                badge: badge,
                status: :badge_ok,
                consents: [],
                revoked_by: nil
              })
              |> emit("morph.rejoin", %{morph: "open", session: "agent"})

            {:reply, {:ok, snapshot(state)}, state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call(:sit_humans, _from, state) do
    cond do
      is_nil(state.badge) ->
        {:reply, {:error, :badge_required}, state}

      state.status in [:morphed, :returned, :revoked] ->
        {:reply, {:error, :already_morphed}, state}

      true ->
        humans = implied_humans(state.participants)
        participants = merge_participants(state.participants, humans)

        state =
          state
          |> Map.put(:participants, participants)
          |> emit("presence.sit", %{humans: Enum.map(humans, & &1.handle.id)})

        {:reply, {:ok, snapshot(state)}, state}
    end
  end

  def handle_call(:drop_humans, _from, state) do
    cond do
      state.status in [:morphed, :returned, :revoked] ->
        {:reply, {:error, :already_morphed}, state}

      not Enum.any?(state.participants, &(&1.role == :human)) ->
        {:reply, {:error, :human_none}, state}

      true ->
        agents = Enum.filter(state.participants, &(&1.role == :agent))

        state =
          state
          |> Map.put(:participants, agents)
          |> emit("presence.soft_no", %{humans: []})

        {:reply, {:ok, snapshot(state)}, state}
    end
  end

  def handle_call({:leave, from}, _from, state) do
    from = normalize_handle(from)

    cond do
      state.status != :open or state.badge != nil ->
        {:reply, {:error, :not_open}, state}

      not participant?(state, from) ->
        {:reply, {:error, :unknown_participant}, state}

      true ->
        participants = Enum.reject(state.participants, fn p -> p.handle.id == from.id end)

        state =
          state
          |> Map.put(:participants, participants)
          |> emit("session.leave", %{from: from})

        {:reply, {:ok, snapshot(state)}, state}
    end
  end

  def handle_call({:join, from}, _from, state) do
    from = normalize_handle(from)

    cond do
      state.status != :open or state.badge != nil ->
        {:reply, {:error, :not_open}, state}

      ttl_expired?(state) ->
        {:reply, {:error, :ttl_expired}, state}

      participant?(state, from) ->
        {:reply, {:error, :already_in}, state}

      not left_before?(state, from) ->
        {:reply, {:error, :not_left}, state}

      true ->
        participants = state.participants ++ [Room.Types.participant(from, :agent)]

        state =
          state
          |> Map.put(:participants, participants)
          |> emit("session.join", %{from: from})

        {:reply, {:ok, snapshot(state)}, state}
    end
  end

  def handle_call(:get, _from, state), do: {:reply, {:ok, snapshot(state)}, state}

  defp emit(state, type, payload) do
    event = %{type: type, at: Room.Types.now_iso(), payload: payload}
    state = update_in(state.events, &(&1 ++ [event]))
    Phoenix.PubSub.broadcast(Room.PubSub, Room.topic(state.context_id), {:room_event, event, snapshot(state)})
    state
  end

  defp snapshot(state) do
    Map.take(state, [
      :context_id,
      :session_kind,
      :status,
      :participants,
      :badge,
      :consents,
      :events,
      :warm_packet,
      :revoked_by,
      :expires_at,
      :offline,
      :consent_wait,
      :consent_wait_expires_at
    ])
    |> Map.put(:dual_consent, dual_consent?(state.participants, state.consents))
    |> Map.put(:wings, Room.Types.wing_mark(state.session_kind || :direct))
    |> then(fn snap ->
      snap =
        if state.status in [:morphed, :returned] do
          Map.put(snap, :warm, Room.Warm.look(snap))
        else
          snap
        end

      cond do
        state.status == :returned ->
          Map.merge(snap, %{
            morph: "closed",
            session: "agent",
            return: Room.Return.look(snap)
          })

        state.status == :revoked ->
          Map.merge(snap, %{
            morph: "closed",
            session: "agent"
          })

        true ->
          snap
      end
    end)
  end

  @idle_seconds 30 * 60

  defp expires_at_for(:fresh, now), do: DateTime.to_iso8601(DateTime.add(now, @idle_seconds, :second))
  defp expires_at_for(:expired, now), do: DateTime.to_iso8601(DateTime.add(now, -1, :second))

  defp ttl_expired?(state, now \\ DateTime.utc_now()) do
    case state[:expires_at] do
      nil ->
        false

      iso when is_binary(iso) ->
        case DateTime.from_iso8601(iso) do
          {:ok, at, _} -> DateTime.compare(at, now) != :gt
          _ -> false
        end

      _ ->
        false
    end
  end

  defp talkable?(state) do
    (state.status == :open and is_nil(state.badge)) or state.status == :morphed
  end

  defp participant?(state, handle) do
    Enum.any?(state.participants, fn p -> p.handle.id == handle.id end)
  end

  defp revoke_again(state, from) do
    first = state[:revoked_by]
    first_id = if is_map(first), do: first[:id] || first["id"]

    if first_id == from.id do
      state
    else
      emit(state, "morph.revoke", %{from: from, morph: "closed", session: "agent"})
    end
  end

  defp left_before?(state, handle) do
    Enum.any?(state.events || [], fn event ->
      event.type == "session.leave" and event_from_id(event) == handle.id
    end)
  end

  defp event_from_id(%{payload: payload}) do
    from = payload[:from] || payload["from"]

    cond do
      is_map(from) -> from[:id] || from["id"]
      true -> nil
    end
  end

  defp event_from_id(_), do: nil

  defp consented?(state, handle) do
    Enum.any?(state.consents, fn c -> c.handle.id == handle.id end)
  end

  defp offline?(state, handle) do
    handle.id in (state[:offline] || [])
  end

  defp maybe_arm_consent_wait(state, now \\ DateTime.utc_now()) do
    if waiting_consent?(state) or (state.consents != [] and peer_offline?(state)) do
      state
      |> Map.put(:consent_wait, :wait)
      |> Map.put(:consent_wait_expires_at, expires_at_for(:fresh, now))
    else
      state
    end
  end

  defp maybe_clear_consent_wait_on_return(state) do
    if state[:consent_wait] == :wait and not peer_offline?(state) do
      Map.merge(state, %{consent_wait: nil, consent_wait_expires_at: nil})
    else
      state
    end
  end

  defp waiting_consent?(state) do
    state[:consent_wait] == :wait or
      (peer_offline?(state) and state.consents != [] and
         state.status not in [:morphed, :returned, :revoked])
  end

  defp peer_offline?(state) do
    required =
      state.participants
      |> Enum.filter(&(&1.role == :agent))
      |> Enum.map(& &1.handle.id)
      |> Enum.uniq()

    granted = state.consents |> Enum.map(& &1.handle.id) |> MapSet.new()

    Enum.any?(required, fn id ->
      id in (state[:offline] || []) and not MapSet.member?(granted, id)
    end)
  end

  defp dual_consent?(participants, consents) do
    required =
      participants
      |> Enum.filter(&(&1.role == :agent))
      |> Enum.map(& &1.handle.id)
      |> Enum.uniq()

    granted = consents |> Enum.map(& &1.handle.id) |> MapSet.new()
    length(required) >= 2 and Enum.all?(required, &MapSet.member?(granted, &1))
  end

  defp implied_humans(participants) do
    participants
    |> Enum.filter(&(&1.role == :agent))
    |> Enum.map(fn %{handle: handle} ->
      human_id = human_id_for(handle.id)
      Room.Types.participant(Room.Types.handle!(human_id, handle.card_url), :human)
    end)
  end

  defp human_id_for(id) do
    case String.split(id, "@") do
      [local, domain] ->
        local
        |> String.split(".")
        |> List.last()
        |> Kernel.<>("@" <> domain)

      _ ->
        id
    end
  end

  defp merge_participants(existing, added) do
    Enum.reduce(added, existing, fn p, acc ->
      if Enum.any?(acc, &(&1.handle.id == p.handle.id and &1.role == p.role)),
        do: acc,
        else: acc ++ [p]
    end)
  end

  defp normalize_handle(%{id: id} = h), do: Room.Types.handle!(id, Map.get(h, :card_url))
  defp normalize_handle(%{"id" => id} = h), do: Room.Types.handle!(id, Map.get(h, "card_url"))
  defp normalize_handle(id) when is_binary(id), do: Room.Types.handle!(id)

  defp normalize_role(role) when role in [:agent, :human], do: role
  defp normalize_role("agent"), do: :agent
  defp normalize_role("human"), do: :human
  defp normalize_role(_), do: :agent

  defp normalize_badge(badge) when is_map(badge) do
    badge
    |> Enum.map(fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), normalize_nested(v)}
      {k, v} -> {k, normalize_nested(v)}
    end)
    |> Map.new()
  end

  defp normalize_nested(%{id: _} = handle), do: normalize_handle(handle)
  defp normalize_nested(%{"id" => _} = handle), do: normalize_handle(handle)
  defp normalize_nested(other), do: other
end
