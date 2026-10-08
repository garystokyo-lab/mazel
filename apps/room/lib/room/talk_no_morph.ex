defmodule Room.TalkNoMorph do
  @moduledoc """
  Agents talk free. Morph needs a badge.

  Unstamped: talk holds, morph denied. Stamped pull_match +
  dual consent commits. Distinct from soft_no (human asleep /
  wake_ok) and badge_demo (mint / self / consent strip).
  """

  def look_none, do: "ok  talk=free  stamp=none"

  def look_denied, do: "error  morph=denied  denied=badge_required"

  def look_stamp(badge) when is_map(badge) do
    source = badge["source"] || badge[:source] || "pull_match"
    kind = badge["kind"] || badge[:kind] || "pull_intent"
    "ok  talk=free  stamp=#{source}  badge=#{kind}"
  end

  def look_stamp(_), do: "ok  talk=free  stamp=pull_match  badge=pull_intent"

  def look_morph, do: "ok  morph=morph.commit  consent=dual"

  def look(pack) when is_map(pack) do
    [look_none(), look_denied(), look_stamp(pack.badge), look_morph()]
  end

  def look(_), do: look(%{badge: %{}})

  @doc """
  Unstamped talk, morph denied. Stamp + dual consent commits.
  Isolated rooms. soft_no / badge LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "talk-no-" <> random_id()

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
         {:ok, none} <-
           Room.open(prefix <> "-none", :direct, [
             %{handle: ariel, role: :agent},
             %{handle: kai, role: :agent}
           ]),
         {:error, :badge_required} <- Room.propose_morph(prefix <> "-none", ariel),
         {:ok, badge} <- pull_stamp(ariel),
         {:ok, state} <-
           commit_both(prefix <> "-stamp", ariel, kai, badge, Keyword.get(opts, :excerpt, [])) do
      last = state.events |> Enum.map(& &1.type) |> List.last()

      cond do
        none.badge != nil or none.status != :open ->
          {:error, :talk_had_badge}

        badge["source"] != "pull_match" or badge["kind"] != "pull_intent" ->
          {:error, :stamp_miss}

        last != "morph.commit" or not state.dual_consent ->
          {:error, :no_commit}

        humans_awake?(none) ->
          {:error, :human_woke}

        true ->
          pack = %{none: none, state: state, badge: badge, denied: :badge_required}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp commit_both(id, ariel, kai, badge, excerpt) do
    with {:ok, _} <-
           Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}]),
         {:ok, _} <- Room.submit_badge(id, badge),
         {:ok, _} <- Room.propose_morph(id, ariel),
         {:ok, _} <- Room.consent(id, ariel),
         {:ok, _} <- Room.consent(id, kai) do
      Room.commit_morph(id, "Talk was free. Morph needed the stamp.", excerpt)
    end
  end

  defp pull_stamp(actor) do
    Room.Badge.mint(:pull_match,
      need: %{id: "need-enterprise-ai", topic: "enterprise-ai"},
      open: %{id: "open-enterprise-ai", handle: "kai@mazel", topic: "enterprise-ai"},
      match: %{id: "open-enterprise-ai", topic: "enterprise-ai", score: 1.0, handle: "kai@mazel"},
      actor: actor
    )
  end

  defp humans_awake?(state) when is_map(state) do
    Enum.any?(state.participants || [], fn p ->
      (p[:role] || p.role) == :human
    end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
