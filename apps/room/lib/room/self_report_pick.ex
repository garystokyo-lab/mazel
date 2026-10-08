defmodule Room.SelfReportPick do
  @moduledoc """
  Two same-tag Has peers; pick one. The other is not mazel'd.

  Explicit pick — not first-by-order. Distinct from
  self_report_match / overlap (single Has) and Session
  match_chat_multi / match_chat_pick (talk turns).
  Off PDF / badge / GH / score / wiki / morph / toolbelt.
  """

  def look_need(rec \\ %{}), do: Room.SelfReportMatch.look_need(rec)

  def look_has(rec \\ %{}) do
    who = local_of(rec[:handle] || "kai@mazel")
    tags = rec[:tags] || ["series-a"]
    "ok  has=@#{who}  tags=[#{Enum.join(List.wrap(tags), ",")}]"
  end

  def look_candidates(rec \\ %{}) do
    ids = rec[:candidates] || ["kai@mazel", "nova@mazel"]
    "ok  candidates=[#{Enum.join(List.wrap(ids), ",")}]"
  end

  def look_pick(rec \\ %{}) do
    peer = rec[:handle] || "nova@mazel"
    who = local_of(peer)
    tag = rec[:query] || List.first(List.wrap(rec[:tags])) || "series-a"
    "ok  pick=@#{who}  find=#{tag}→#{peer}  #{Room.Find.mazel_d(peer)}"
  end

  def look_miss(handle \\ "kai@mazel") do
    "error  mazel'd=@#{local_of(handle)}  none"
  end

  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [
      look_need(pack.need),
      look_has(pack.has_kai),
      look_has(pack.has_nova),
      look_candidates(pack),
      look_pick(pack.hit),
      look_miss(pack.miss || "kai@mazel"),
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
        hit: %{handle: "nova@mazel"},
        miss: "kai@mazel"
      })

  @doc """
  Two Has, same tags. pick nova mazel'd; kai none.
  Isolated. Sibling match / Session pick LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-pick-" <> random_id()
    want = Keyword.get(opts, :pick) || "nova@mazel"

    need = Room.SelfReportMatch.parse(Keyword.get(opts, :need) || "need: series-a")
    has_kai = Room.SelfReportMatch.report(:has, "series-a", handle: "kai@mazel")
    has_nova = Room.SelfReportMatch.report(:has, "series-a", handle: "nova@mazel")
    found = Room.SelfReportMatch.pick_find([has_kai, has_nova], need, want)
    ghost = Room.SelfReportMatch.pick_find([has_kai, has_nova], need, "@ghost")

    with {:ok, session} <- keep_agent(prefix, found.picked) do
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

        is_nil(found.picked) or found.picked.handle != "nova@mazel" ->
          {:error, :pick_miss}

        found.picked.handle == found.first.handle ->
          {:error, :first_by_order}

        Enum.map(found.leftover, & &1.handle) != ["kai@mazel"] ->
          {:error, :leftover_miss}

        not is_nil(ghost.picked) ->
          {:error, :ghost_picked}

        session.status != :open or session.session_kind != :direct ->
          {:error, :session_miss}

        session.badge != nil or "morph.commit" in events or "talk" in events ->
          {:error, :morphed}

        humans_awake?(session) ->
          {:error, :human_woke}

        seated?(session, "kai@mazel") ->
          {:error, :kai_seated}

        not seated?(session, "nova@mazel") ->
          {:error, :nova_miss}

        true ->
          pack = %{
            need: need,
            has_kai: has_kai,
            has_nova: has_nova,
            hit: found.picked,
            first: found.first,
            hits: found.hits,
            candidates: found.candidates,
            leftover: found.leftover,
            miss: "kai@mazel",
            pick: want,
            session: session,
            complete: :agent
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp keep_agent(_id, nil), do: {:error, :pick_miss}

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

  defp local_of(handle) do
    handle
    |> to_string()
    |> String.trim_leading("@")
    |> String.split("@")
    |> hd()
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
