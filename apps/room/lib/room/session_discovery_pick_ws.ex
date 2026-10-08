defmodule Room.SessionDiscoveryPickWs do
  @moduledoc """
  Pick a whitespace-only handle. Same blank reject.

  need@mazel lists kai + nova. pick "   " stays clear.
  No id. No talk. Distinct from
  session_discovery_pick_blank (LOOK pick="") and
  session_discovery_pick_unknown (@ghost). Off mint /
  Match / wiki / Consent / A2A.
  """

  @ws "   "

  def ws, do: @ws

  def look_discovery(handles \\ ["kai@mazel", "nova@mazel"]),
    do: Room.SessionDiscoveryPickBlank.look_discovery(handles)

  def look_pick(handle \\ @ws) do
    "error  pick=#{inspect(handle)}  rejected=blank  open=none  id=none"
  end

  def look_talk, do: Room.SessionDiscoveryPickBlank.look_talk()

  def look(pack) when is_map(pack) do
    [look_discovery(pack[:handles]), look_pick(pack[:want] || @ws), look_talk()]
  end

  def look(_), do: look(%{handles: ["kai@mazel", "nova@mazel"], want: @ws})

  @doc """
  Discovery lists kai + nova. pick "   " → reject blank.
  Empty "" is the same reject. No session. Isolated.
  Sibling pick_blank / unknown / pick LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-discovery-pick-ws-" <> random_id()
    want = Keyword.get(opts, :pick) || @ws

    need = Room.SelfReportMatch.parse(Keyword.get(opts, :need) || "need: series-a")
    has_kai = Room.SelfReportMatch.report(:has, "series-a", handle: "kai@mazel")
    has_nova = Room.SelfReportMatch.report(:has, "series-a", handle: "nova@mazel")
    hits = Room.SelfReportMatch.match_all([has_kai, has_nova], need)
    found = Room.SessionDiscovery.handles(hits)
    picked = Room.SessionDiscovery.pick(found, want)
    opened = Room.SessionDiscovery.open_picked(prefix, found, want)
    empty_opened = Room.SessionDiscovery.open_picked(prefix, found, "")

    cond do
      not Room.Need.discovery_sink?("need@mazel") ->
        {:error, :sink_miss}

      found != ["kai@mazel", "nova@mazel"] ->
        {:error, :handle_miss}

      want |> to_string() |> String.trim() == "" and want == "" ->
        {:error, :not_ws}

      not Room.SessionDiscovery.blank_handle?(want) ->
        {:error, :not_blank}

      not Room.SessionDiscovery.blank_handle?("") ->
        {:error, :empty_miss}

      picked != nil ->
        {:error, :ws_hit}

      Room.SessionDiscovery.pick(found, "") != nil ->
        {:error, :empty_hit}

      opened != {:error, :blank} ->
        {:error, :opened}

      empty_opened != {:error, :blank} ->
        {:error, :empty_opened}

      Room.SessionDiscovery.open_picked(prefix, found, "@ghost") != {:error, :unknown} ->
        {:error, :ghost_miss}

      Room.SessionDiscovery.pick(found, "kai@mazel") != "kai@mazel" ->
        {:error, :list_miss}

      Room.SessionDiscovery.pick(found, "@nova") != "nova@mazel" ->
        {:error, :list_miss}

      look_pick(want) != "error  pick=\"   \"  rejected=blank  open=none  id=none" ->
        {:error, :look_miss}

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