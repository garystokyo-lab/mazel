defmodule Room.SessionDiscovery do
  @moduledoc """
  need@mazel lists real handles. Does not spam-open humans.

  Self-report match path. No PDF / GH proof. Distinct from
  discovery (kind=need / 🪽 Direct), match_chat_direct
  (talk turns), and agent_stay (no discovery=). Off wiki.
  """

  def look_discovery(handles \\ ["kai@mazel"]) do
    listed = handles |> List.wrap() |> Enum.join(",")
    "ok  discovery=need@mazel  handles=[#{listed}]"
  end

  def look_find(rec \\ %{}), do: Room.AgentStay.look_find(rec)
  def look_session, do: Room.AgentStay.look_session()
  def look_spam, do: "error  spam=human  open=none  human=asleep"

  def look(pack) when is_map(pack) do
    handles = pack[:handles] || handles(pack[:hit] || %{})
    [look_discovery(handles), look_find(pack.hit), look_session(), look_spam()]
  end

  def look(_), do: look(%{hit: %{}})

  @doc "Person handles from a self-report hit. Empty miss is none."
  def handles(hits) when is_list(hits) do
    hits
    |> Enum.flat_map(&handles/1)
    |> Enum.uniq()
  end

  def handles(hit) when is_map(hit) do
    handle = hit[:handle]

    if hit[:ok] == true and is_binary(handle) and handle != "" do
      [handle]
    else
      []
    end
  end

  def handles(_), do: []

  @doc "Pick a handle from a discovery list. Missing or blank handle is none."
  def pick(handles, handle) when is_list(handles) do
    want = normalize_handle(handle)
    Enum.find(handles, &(&1 == want))
  end

  def pick(_, _), do: nil

  @doc "Empty or whitespace-only pick. Same reject as blank."
  def blank_handle?(handle) do
    handle |> to_string() |> String.trim() == ""
  end

  @doc """
  Open Direct only for a listed handle. Unknown pick
  stays clear — no id, no open, no talk. Blank pick
  (empty / whitespace) is the same reject, no open.
  """
  def open_picked(id, handles, handle) when is_list(handles) do
    cond do
      blank_handle?(handle) ->
        {:error, :blank}

      true ->
        case pick(handles, handle) do
          nil ->
            {:error, :unknown}

          picked ->
            with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
                 {:ok, other} <- Room.Cards.lookup(picked) do
              Room.open(open_id(id), :direct, [
                %{handle: ariel, role: :agent},
                %{handle: other, role: :agent}
              ])
            end
        end
    end
  end

  def open_picked(_, _, _), do: {:error, :unknown}

  @doc "Discovery must not open a human session per handle."
  def open_humans(_handles), do: {:error, :spam}

  @doc """
  Keep an agent session id for a discovery list.
  Empty handles stay clear — no id, no open.
  Does not spam-open humans. No talk.
  """
  def keep_id(_id, []), do: {:error, :empty}

  def keep_id(id, handles) when is_binary(id) and is_list(handles) do
    peer = List.first(handles) || "kai@mazel"

    with {:error, :spam} <- open_humans(handles),
         {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, other} <- Room.Cards.lookup(peer) do
      Room.open(id, :direct, [
        %{handle: ariel, role: :agent},
        %{handle: other, role: :agent}
      ])
    end
  end

  def keep_id(_, _), do: {:error, :spam}

  @doc """
  need@mazel → handles from self-report. One agent session.
  No human spam-open. Isolated. Sibling discovery LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-discovery-" <> random_id()

    with {:ok, matched} <- Room.SelfReportMatch.demo(context_id: prefix <> "-match"),
         {:error, :human_asleep} <- Room.SoftNo.wake(matched.session),
         {:error, :spam} <- open_humans(handles(matched.hit)) do
      events = Enum.map(matched.session.events || [], & &1.type)
      found = handles(matched.hit)

      cond do
        not Room.Need.discovery_sink?("need@mazel") ->
          {:error, :sink_miss}

        matched.has.source != "self_report" or matched.need.source != "self_report" ->
          {:error, :not_self_report}

        found != ["kai@mazel"] ->
          {:error, :handle_miss}

        matched.session.status != :open or matched.session.session_kind != :direct ->
          {:error, :session_miss}

        matched.session.badge != nil or "morph.commit" in events ->
          {:error, :morphed}

        humans_awake?(matched.session) ->
          {:error, :human_woke}

        true ->
          pack = %{
            hit: matched.hit,
            has: matched.has,
            need: matched.need,
            session: matched.session,
            handles: found,
            matched: matched
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp open_id(id) when is_binary(id) and id != "", do: id
  defp open_id(_), do: "session-direct-" <> random_id()

  defp normalize_handle(handle) do
    text = handle |> to_string() |> String.trim() |> String.trim_leading("@")

    cond do
      text == "" -> nil
      String.contains?(text, "@") -> text
      true -> text <> "@mazel"
    end
  end

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
