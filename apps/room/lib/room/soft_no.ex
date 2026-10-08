defmodule Room.SoftNo do
  @moduledoc """
  Unstamped first contact: agent soft-no, human stays asleep.

  Agents may talk without a badge. Morph / wake needs a stamp.
  Not the buried badge_demo talk=free line alone.
  """

  def look_none(_pack \\ %{}) do
    "ok  stamp=none  agent=soft_no  human=asleep"
  end

  def look_talk(denied \\ :badge_required) do
    "ok  talk=free  morph=denied  denied=#{denied}"
  end

  def look_stamp(badge) when is_map(badge) do
    source = badge["source"] || badge[:source]
    kind = badge["kind"] || badge[:kind]
    "ok  stamp=#{source}  badge=#{kind}  human=wake_ok"
  end

  def look_stamp(_), do: "ok  stamp=pull_match  badge=pull_intent  human=wake_ok"

  def look(pack) when is_map(pack) do
    [look_none(pack), look_talk(pack[:denied] || :badge_required), look_stamp(pack.badge)]
  end

  def look(_), do: look(%{denied: :badge_required, badge: %{}})

  @doc "No stamp → agent soft-no. Stamp present → talk."
  def agent(state) when is_map(state) do
    if stamped?(state), do: {:ok, :talk}, else: {:ok, :soft_no}
  end

  def agent(_), do: {:ok, :soft_no}

  @doc "No stamp → human asleep. Stamp → wake_ok. Never wakes the human on none."
  def wake(state) when is_map(state) do
    if stamped?(state), do: {:ok, :wake_ok}, else: {:error, :human_asleep}
  end

  def wake(_), do: {:error, :human_asleep}

  def stamped?(%{badge: badge}) when not is_nil(badge), do: true
  def stamped?(%{"badge" => badge}) when not is_nil(badge), do: true
  def stamped?(_), do: false

  @doc "Peer may soft-no even after a stamp wake. Dual consent is talk."
  def peer(state) when is_map(state) do
    if state[:dual_consent] == true, do: {:ok, :talk}, else: {:ok, :soft_no}
  end

  def peer(_), do: {:ok, :soft_no}

  @doc "Peer soft-no puts the human back to sleep."
  def peer_wake(state) do
    case peer(state) do
      {:ok, :soft_no} -> {:error, :human_asleep}
      other -> other
    end
  end

  @doc "Peer soft-no denies morph. Dual may proceed."
  def refuse_morph(state) do
    case peer(state) do
      {:ok, :soft_no} -> {:error, :soft_no}
      {:ok, :talk} -> {:ok, :talk}
    end
  end

  @doc """
  Unstamped room: talk free, morph denied, human asleep.
  pull_match stamp → wake_ok. Isolated room ids.
  Does not rewrite badge_demo LOOK.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "soft-no-" <> random_id()

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
         {:ok, none} <-
           Room.open(prefix <> "-none", :direct, [
             %{handle: ariel, role: :agent},
             %{handle: kai, role: :agent}
           ]),
         {:ok, :soft_no} <- agent(none),
         {:error, :human_asleep} <- wake(none),
         {:error, :badge_required} <- Room.propose_morph(prefix <> "-none", ariel),
         {:ok, badge} <- pull_stamp(ariel),
         {:ok, stamped} <- stamp_room(prefix <> "-stamp", ariel, kai, badge),
         {:ok, :wake_ok} <- wake(stamped) do
      cond do
        none.badge != nil or none.status != :open ->
          {:error, :talk_had_badge}

        stamped.badge["source"] != "pull_match" or stamped.badge["kind"] != "pull_intent" ->
          {:error, :stamp_miss}

        humans_awake?(none) ->
          {:error, :human_woke}

        true ->
          pack = %{none: none, stamped: stamped, badge: badge, denied: :badge_required}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp stamp_room(id, ariel, kai, badge) do
    with {:ok, _} <-
           Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}]),
         {:ok, _} <- Room.submit_badge(id, badge) do
      Room.get(id)
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
