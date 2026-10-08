defmodule Room.SessionDiscoveryId do
  @moduledoc """
  Discovery lists handles and a session id. No chat spam.

  Distinct from session_discovery (handles list; no id=),
  session_discovery_direct (pick→Direct talk), and
  session_direct_id / session_intro_id / session_group_id
  (id + talk). Off mint / Match / wiki / Consent / A2A.
  """

  def look_discovery(handles \\ ["kai@mazel"]),
    do: Room.SessionDiscovery.look_discovery(handles)

  def look_id(id), do: "ok  id=#{id}"
  def look_spam, do: Room.SessionDiscovery.look_spam()

  def look(pack) when is_map(pack) do
    [look_discovery(pack[:handles]), look_id(pack[:open_id]), look_spam()]
  end

  def look(_), do: look(%{handles: ["kai@mazel"], open_id: "session-discovery-a"})

  @doc """
  need@mazel → handles + session id. No talk. No human
  spam-open. Isolated. Sibling discovery / direct / id
  LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-discovery-" <> random_id()

    has = Room.SelfReportMatch.parse(Keyword.get(opts, :has) || "has: series-a")
    need = Room.SelfReportMatch.parse(Keyword.get(opts, :need) || "need: series-a")
    hit = Room.SelfReportMatch.match(has, need)
    found = Room.SessionDiscovery.handles(hit)

    with {:ok, session} <- Room.SessionDiscovery.keep_id(prefix, found),
         {:error, :human_asleep} <- Room.SoftNo.wake(session),
         {:error, :spam} <- Room.SessionDiscovery.open_humans(found) do
      events = Enum.map(session.events || [], & &1.type)
      id = Room.SessionContext.id(session)

      cond do
        not Room.Need.discovery_sink?("need@mazel") ->
          {:error, :sink_miss}

        found != ["kai@mazel"] or hit.handle != "kai@mazel" ->
          {:error, :handle_miss}

        id != prefix or id == nil ->
          {:error, :id_miss}

        session.status != :open or session.session_kind != :direct ->
          {:error, :session_miss}

        session.badge != nil or "morph.commit" in events or "talk" in events ->
          {:error, :chat_spam}

        humans_awake?(session) ->
          {:error, :human_woke}

        true ->
          pack = %{
            hit: hit,
            has: has,
            need: need,
            handles: found,
            session: session,
            open_id: id
          }

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
