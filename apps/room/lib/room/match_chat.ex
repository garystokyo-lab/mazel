defmodule Room.MatchChat do
  @moduledoc """
  Self-report tag match, then one free talk turn each.

  Talk holds without a badge. Morph is denied. Distinct from
  self_report_match (no talk turns), talk_no_morph (no match
  lead-in), and find_demo (no chat turns). Not wiki / GH proof.
  """

  def look_has(rec \\ %{}), do: Room.SelfReportMatch.look_has(rec)
  def look_need(rec \\ %{}), do: Room.SelfReportMatch.look_need(rec)
  def look_find(rec \\ %{}), do: Room.SelfReportMatch.look_find(rec)

  def look_talk(rec \\ %{}, n \\ 1)

  def look_talk(rec, n) when is_map(rec) do
    who = rec[:local] || local_of(rec[:handle] || rec[:from] || "ariel@mazel")
    "ok  talk=@#{who}  turn=#{n}"
  end

  def look_talk(_, n), do: "ok  talk=@ariel  turn=#{n}"

  def look_denied, do: Room.TalkNoMorph.look_denied()

  def look(pack) when is_map(pack) do
    [
      look_has(pack.has),
      look_need(pack.need),
      look_find(pack.hit),
      look_talk(pack.turn_a, 1),
      look_talk(pack.turn_b, 1),
      look_denied()
    ]
  end

  def look(_), do: look(%{has: %{}, need: %{}, hit: %{}, turn_a: %{local: "ariel"}, turn_b: %{local: "kai"}})

  @doc """
  Self-report overlap → mazel'd → one talk each. Morph denied.
  Isolated. Sibling match / talk / find LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "match-chat-" <> random_id()

    with {:ok, matched} <- Room.SelfReportMatch.demo(context_id: prefix),
         {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup(matched.hit.handle || "@kai"),
         {:ok, after_a} <- Room.talk(matched.session.context_id, ariel, "series-a"),
         {:ok, after_b} <- Room.talk(matched.session.context_id, kai, "has"),
         {:error, :badge_required} <- Room.propose_morph(matched.session.context_id, ariel) do
      talks = Enum.filter(after_b.events || [], &(&1.type == "talk"))
      events = Enum.map(after_b.events || [], & &1.type)

      cond do
        matched.has.source != "self_report" or matched.need.source != "self_report" ->
          {:error, :not_self_report}

        not matched.hit.ok or matched.hit.handle != "kai@mazel" ->
          {:error, :overlap_miss}

        length(talks) != 2 ->
          {:error, :talk_miss}

        after_b.badge != nil or "morph.commit" in events ->
          {:error, :morphed}

        after_a.status != :open or after_b.status != :open ->
          {:error, :session_miss}

        humans_awake?(after_b) ->
          {:error, :human_woke}

        true ->
          pack = %{
            has: matched.has,
            need: matched.need,
            hit: matched.hit,
            turn_a: %{handle: ariel.id, local: "ariel", text: "series-a"},
            turn_b: %{handle: kai.id, local: "kai", text: "has"},
            session: after_b,
            denied: :badge_required,
            matched: matched
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp local_of(handle) do
    handle
    |> to_string()
    |> String.trim_leading("@")
    |> String.split("@")
    |> hd()
  end

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
