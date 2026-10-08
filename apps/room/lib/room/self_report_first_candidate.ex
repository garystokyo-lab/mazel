defmodule Room.SelfReportFirstCandidate do
  @moduledoc """
  Two same-tag Has peers; no pick. First by order is
  mazel'd. The leftover is not.

  Distinct from self_report_pick (explicit pick=@nova),
  self_report_match (single Has peer), and Session
  match_chat_multi (talk turns). Off PDF / badge / GH /
  score / wiki / morph / toolbelt.
  """

  def look_need(rec \\ %{}), do: Room.SelfReportPick.look_need(rec)
  def look_has(rec \\ %{}), do: Room.SelfReportPick.look_has(rec)
  def look_candidates(rec \\ %{}), do: Room.SelfReportPick.look_candidates(rec)
  def look_miss(handle \\ "nova@mazel"), do: Room.SelfReportPick.look_miss(handle)
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look_find(rec \\ %{}) do
    "#{Room.SelfReportMatch.look_find(rec)}  order=first"
  end

  def look(pack) when is_map(pack) do
    [
      look_need(pack.need),
      look_has(pack.has_kai),
      look_has(pack.has_nova),
      look_candidates(pack),
      look_find(pack.hit),
      look_miss(pack.miss || "nova@mazel"),
      look_complete()
    ]
  end

  def look(_),
    do:
      look(%{
        need: %{},
        has_kai: %{handle: "kai@mazel"},
        has_nova: %{handle: "nova@mazel"},
        candidates: ["kai@mazel", "nova@mazel"],
        hit: %{handle: "kai@mazel"},
        miss: "nova@mazel"
      })

  @doc """
  Two Has, same tags. First (kai) mazel'd; nova none.
  Isolated. Sibling pick / match / Session multi LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-first-candidate-" <> random_id()

    need = Room.SelfReportMatch.parse(Keyword.get(opts, :need) || "need: series-a")
    has_kai = Room.SelfReportMatch.report(:has, "series-a", handle: "kai@mazel")
    has_nova = Room.SelfReportMatch.report(:has, "series-a", handle: "nova@mazel")
    found = Room.SelfReportMatch.first_find([has_kai, has_nova], need)
    picked = Room.SelfReportMatch.pick_find([has_kai, has_nova], need, "@nova")

    with {:ok, session} <- keep_agent(prefix, found.first) do
      events = Enum.map(session.events || [], & &1.type)

      cond do
        need.source != "self_report" or need.tags != ["series-a"] ->
          {:error, :not_self_report}

        has_kai.source != "self_report" or has_nova.source != "self_report" ->
          {:error, :not_self_report}

        length(found.hits) != 2 or found.candidates != ["kai@mazel", "nova@mazel"] ->
          {:error, :peer_miss}

        is_nil(found.first) or found.first.handle != "kai@mazel" ->
          {:error, :order_miss}

        Enum.map(found.leftover, & &1.handle) != ["nova@mazel"] ->
          {:error, :leftover_miss}

        is_nil(picked.picked) or picked.picked.handle != "nova@mazel" ->
          {:error, :pick_path}

        found.first.handle == picked.picked.handle ->
          {:error, :pick_path}

        Map.has_key?(found, :picked) ->
          {:error, :pick_path}

        session.status != :open or session.session_kind != :direct ->
          {:error, :session_miss}

        session.badge != nil or "morph.commit" in events or "talk" in events ->
          {:error, :morphed}

        humans_awake?(session) ->
          {:error, :human_woke}

        seated?(session, "nova@mazel") ->
          {:error, :nova_seated}

        not seated?(session, "kai@mazel") ->
          {:error, :kai_miss}

        look_find() == Room.SelfReportMatch.look_find() ->
          {:error, :match_look}

        look_find() == Room.SelfReportPick.look_pick() ->
          {:error, :pick_look}

        look_find() == Room.MatchChatMulti.look_find() ->
          {:error, :session_look}

        true ->
          pack = %{
            need: need,
            has_kai: has_kai,
            has_nova: has_nova,
            hit: found.first,
            first: found.first,
            hits: found.hits,
            candidates: found.candidates,
            leftover: found.leftover,
            miss: "nova@mazel",
            session: session,
            complete: :agent
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp keep_agent(_id, nil), do: {:error, :order_miss}

  defp keep_agent(id, hit) do
    peer = hit[:handle] || hit.handle

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, other} <- Room.Cards.lookup(peer) do
      Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: other, role: :agent}])
    end
  end

  defp seated?(state, handle) do
    Enum.any?(state.participants || [], fn p ->
      id = p[:handle] || p.handle
      id = if is_map(id), do: id.id, else: id
      to_string(id) == handle
    end)
  end

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end