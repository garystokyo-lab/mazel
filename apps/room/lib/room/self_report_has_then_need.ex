defmodule Room.SelfReportHasThenNeed do
  @moduledoc """
  Has already set; Need cast after. Find waits.

  Distinct from self_report_has_no_need (stops at
  find=not_called), self_report_has_cast (cast Has;
  Need already present), and self_report_cast (Need
  first; Has pre-seeded). Off PDF / badge / GH / score
  / wiki / morph / toolbelt / talk-turns.
  """

  @chat "looking for series-a"

  def chat, do: @chat

  def look_has(rec \\ %{}), do: Room.SelfReportMatch.look_has(rec)
  def look_need, do: Room.SelfReportHasNoNeed.look_need()
  def look_skip, do: Room.SelfReportHasNoNeed.look_skip()
  def look_cast(rec \\ %{}), do: Room.SelfReportCast.look_cast(rec)
  def look_find(rec \\ %{}), do: Room.SelfReportMatch.look_find(rec)
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [
      look_has(pack.has),
      look_need(),
      look_skip(),
      look_cast(pack.need),
      look_find(pack.hit),
      look_complete()
    ]
  end

  def look(_), do: look(%{has: %{}, need: %{}, hit: %{}})

  @doc """
  Has first. Find skipped. Cast Need. Then mazel'd.
  Isolated. Sibling has_no_need / has_cast / cast LOOK
  stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-has-then-need-" <> random_id()
    chat = Keyword.get(opts, :chat) || @chat

    with {:ok, prior} <-
           Room.SelfReportHasNoNeed.demo(Keyword.put(opts, :context_id, prefix <> "-prior")),
         need <- Room.SelfReportMatch.cast(:need, chat),
         {:ok, stored} <- Room.SelfReportMatch.put(prior.root, need) do
      hit = Room.SelfReportMatch.match(prior.has, stored)
      later = Room.SelfReportMatch.find_need(Room.SelfReportMatch.vault(prior.root, :has), Room.SelfReportMatch.vault(prior.root, :need))

      with {:ok, found} <- Room.Find.query(hit.query || "series-a") do
        card = List.first(found[:hits] || [])
        events = Enum.map(prior.session.events || [], & &1.type)

        cond do
          prior.found.called != false or prior.found.error != "no_need" ->
            {:error, :spam_before}

          stored[:from] != "chat" or stored[:cast] != "need" ->
            {:error, :cast_miss}

          stored.source != "self_report" or stored.tags != ["series-a"] ->
            {:error, :not_self_report}

          later.called != true or later.ok != true or later.handle != "kai@mazel" ->
            {:error, :find_miss}

          not hit.ok or hit.handle != "kai@mazel" ->
            {:error, :overlap_miss}

          is_nil(card) or card.handle != "kai@mazel" ->
            {:error, :find_miss}

          prior.session.status != :open or prior.session.badge != nil or
              "morph.commit" in events ->
            {:error, :session_miss}

          "talk" in events ->
            {:error, :talked}

          humans_awake?(prior.session) ->
            {:error, :human_woke}

          true ->
            pack =
              Map.merge(prior, %{
                need: stored,
                hit: hit,
                later: later,
                find: found,
                chat: chat
              })

            {:ok, Map.put(pack, :lines, look(pack))}
        end
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
