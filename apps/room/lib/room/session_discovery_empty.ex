defmodule Room.SessionDiscoveryEmpty do
  @moduledoc """
  Discovery with zero handles stays clear. No session id.
  No chat spam.

  Distinct from session_discovery_id (handles + id=),
  session_discovery (non-empty handles + session=agent),
  and session_discovery_direct (pick→talk). Off mint /
  Match / wiki / Consent / A2A.
  """

  def look_discovery, do: Room.SessionDiscovery.look_discovery([])
  def look_empty, do: "ok  empty=clear  id=none  open=none"
  def look_spam, do: "error  spam=human  open=none"

  def look(_pack \\ %{}) do
    [look_discovery(), look_empty(), look_spam()]
  end

  @doc """
  need@mazel → zero handles. No id. No open. No talk.
  Isolated. Sibling discovery / discovery_id LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-discovery-empty-" <> random_id()

    has = Room.SelfReportMatch.parse(Keyword.get(opts, :has) || "has: series-a")
    need = Room.SelfReportMatch.parse(Keyword.get(opts, :need) || "need: impl")
    hit = Room.SelfReportMatch.match(has, need)
    found = Room.SessionDiscovery.handles(hit)

    with {:error, :empty} <- Room.SessionDiscovery.keep_id(prefix, found),
         {:error, :spam} <- Room.SessionDiscovery.open_humans(found) do
      cond do
        not Room.Need.discovery_sink?("need@mazel") ->
          {:error, :sink_miss}

        found != [] or hit[:ok] == true or hit[:handle] != nil ->
          {:error, :handle_hit}

        Room.SessionDiscovery.keep_id(prefix, []) != {:error, :empty} ->
          {:error, :id_opened}

        true ->
          pack = %{
            hit: hit,
            has: has,
            need: need,
            handles: found,
            session: nil,
            open_id: nil
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
