defmodule Room.SessionDiscoveryPickUnknown do
  @moduledoc """
  Pick an unknown handle from a discovery list. Reject.

  need@mazel lists kai + nova. pick @ghost stays clear.
  No open. No id. No talk. Distinct from
  session_discovery_pick (known pick→Direct id+talk) and
  session_discovery_empty (handles=[]). Off mint / Match /
  wiki / Consent / A2A.
  """

  @ghost "@ghost"

  def ghost, do: @ghost

  def look_discovery(handles \\ ["kai@mazel", "nova@mazel"]),
    do: Room.SessionDiscoveryPick.look_discovery(handles)

  def look_pick(handle \\ @ghost) do
    "error  pick=#{handle}  rejected=unknown  open=none  id=none"
  end

  def look_talk, do: "error  talk=none"

  def look(pack) when is_map(pack) do
    [look_discovery(pack[:handles]), look_pick(pack[:want] || @ghost), look_talk()]
  end

  def look(_), do: look(%{handles: ["kai@mazel", "nova@mazel"], want: @ghost})

  @doc """
  Discovery lists kai + nova. pick @ghost → reject.
  No session. Isolated. Sibling pick / empty LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-discovery-pick-unknown-" <> random_id()
    want = Keyword.get(opts, :pick) || @ghost

    need = Room.SelfReportMatch.parse(Keyword.get(opts, :need) || "need: series-a")
    has_kai = Room.SelfReportMatch.report(:has, "series-a", handle: "kai@mazel")
    has_nova = Room.SelfReportMatch.report(:has, "series-a", handle: "nova@mazel")
    hits = Room.SelfReportMatch.match_all([has_kai, has_nova], need)
    found = Room.SessionDiscovery.handles(hits)
    picked = Room.SessionDiscovery.pick(found, want)
    opened = Room.SessionDiscovery.open_picked(prefix, found, want)

    cond do
      not Room.Need.discovery_sink?("need@mazel") ->
        {:error, :sink_miss}

      found != ["kai@mazel", "nova@mazel"] ->
        {:error, :handle_miss}

      picked != nil ->
        {:error, :ghost_hit}

      opened != {:error, :unknown} ->
        {:error, :opened}

      Room.SessionDiscovery.pick(found, "kai@mazel") != "kai@mazel" ->
        {:error, :list_miss}

      Room.SessionDiscovery.pick(found, "@nova") != "nova@mazel" ->
        {:error, :list_miss}

      Room.SessionDiscovery.keep_id(prefix, []) != {:error, :empty} ->
        {:error, :empty_opened}

      true ->
        pack = %{
          handles: found,
          hits: hits,
          want: want,
          picked: picked,
          session: nil,
          open_id: nil,
          rejected: :unknown
        }

        {:ok, Map.put(pack, :lines, look(pack))}
    end
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
