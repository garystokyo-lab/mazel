defmodule Room.SessionDiscoveryPickBlank do
  @moduledoc """
  Pick an empty / whitespace handle. Reject. No open.

  need@mazel lists kai + nova. pick "" (or "   ") stays
  clear. No id. No talk. Distinct from
  session_discovery_pick_unknown (@ghost rejected=unknown)
  and session_discovery_pick (known→Direct). Off mint /
  Match / wiki / Consent / A2A.
  """

  @blank ""
  @ws "   "

  def blank, do: @blank
  def ws, do: @ws

  def look_discovery(handles \\ ["kai@mazel", "nova@mazel"]),
    do: Room.SessionDiscoveryPick.look_discovery(handles)

  def look_pick(handle \\ @blank) do
    "error  pick=#{inspect(handle)}  rejected=blank  open=none  id=none"
  end

  def look_talk, do: "error  talk=none"

  def look(pack) when is_map(pack) do
    [look_discovery(pack[:handles]), look_pick(pack[:want] || @blank), look_talk()]
  end

  def look(_), do: look(%{handles: ["kai@mazel", "nova@mazel"], want: @blank})

  @doc """
  Discovery lists kai + nova. pick "" → reject blank.
  Whitespace-only is the same reject. No session.
  Isolated. Sibling pick / unknown LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-discovery-pick-blank-" <> random_id()
    want = Keyword.get(opts, :pick) || @blank

    need = Room.SelfReportMatch.parse(Keyword.get(opts, :need) || "need: series-a")
    has_kai = Room.SelfReportMatch.report(:has, "series-a", handle: "kai@mazel")
    has_nova = Room.SelfReportMatch.report(:has, "series-a", handle: "nova@mazel")
    hits = Room.SelfReportMatch.match_all([has_kai, has_nova], need)
    found = Room.SessionDiscovery.handles(hits)
    picked = Room.SessionDiscovery.pick(found, want)
    opened = Room.SessionDiscovery.open_picked(prefix, found, want)
    ws_opened = Room.SessionDiscovery.open_picked(prefix, found, @ws)

    cond do
      not Room.Need.discovery_sink?("need@mazel") ->
        {:error, :sink_miss}

      found != ["kai@mazel", "nova@mazel"] ->
        {:error, :handle_miss}

      not Room.SessionDiscovery.blank_handle?(want) ->
        {:error, :not_blank}

      not Room.SessionDiscovery.blank_handle?(@ws) ->
        {:error, :ws_miss}

      picked != nil ->
        {:error, :blank_hit}

      Room.SessionDiscovery.pick(found, @ws) != nil ->
        {:error, :ws_hit}

      opened != {:error, :blank} ->
        {:error, :opened}

      ws_opened != {:error, :blank} ->
        {:error, :ws_opened}

      Room.SessionDiscovery.open_picked(prefix, found, "@ghost") != {:error, :unknown} ->
        {:error, :ghost_miss}

      Room.SessionDiscovery.pick(found, "kai@mazel") != "kai@mazel" ->
        {:error, :list_miss}

      Room.SessionDiscovery.pick(found, "@nova") != "nova@mazel" ->
        {:error, :list_miss}

      true ->
        pack = %{
          handles: found,
          hits: hits,
          want: want,
          picked: picked,
          session: nil,
          open_id: nil,
          rejected: :blank
        }

        {:ok, Map.put(pack, :lines, look(pack))}
    end
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
