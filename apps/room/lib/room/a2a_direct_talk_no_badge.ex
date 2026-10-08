defmodule Room.A2aDirectTalkNoBadge do
  @moduledoc """
  Resolve kai, Direct talk, then morph denied without a badge.

  JSON-RPC talk stays ok. Join is blocked. Distinct from
  a2a_direct_talk (talk only; no morph attempt),
  match_chat_direct (no A2A resolve; denied=badge_required),
  and Consent stay morphs (no A2A card resolve).
  Off Group / mint / wiki / Trust.
  """

  def look_resolve(rec \\ %{}), do: Room.A2aDirectTalk.look_resolve(rec)
  def look_direct, do: Room.A2aDirectTalk.look_direct()
  def look_talk, do: Room.A2aDirectTalk.look_talk()
  def look_denied, do: "error  morph=denied  badge=none  human=asleep"

  def look(pack) when is_map(pack) do
    [look_resolve(pack.hit), look_direct(), look_talk(), look_denied()]
  end

  def look(_), do: look(%{hit: %{handle: "kai@mazel", card_url: Room.A2aCard.card_url("kai@mazel")}})

  @doc """
  Resolve + Direct JSON-RPC talk, then morph denied.
  Talk path unchanged. Isolated. Sibling talk / task stay.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-direct-a2a-talk-no-badge-" <> random_id()

    with {:ok, prior} <- Room.A2aDirectTalk.demo(context_id: prefix),
         {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:error, :badge_required} <- Room.propose_morph(prefix, ariel),
         {:error, :human_asleep} <- Room.SoftNo.wake(prior.session) do
      events = Enum.map(prior.session.events || [], & &1.type)

      cond do
        prior.hit.handle != "kai@mazel" ->
          {:error, :resolve_miss}

        prior.sent.status != :ok or prior.sent.method != "message/send" ->
          {:error, :talk_miss}

        prior.session.badge != nil or "morph.commit" in events ->
          {:error, :morphed}

        prior.session.session_kind != :direct ->
          {:error, :not_direct}

        humans_awake?(prior.session) ->
          {:error, :human_woke}

        true ->
          pack =
            Map.merge(prior, %{
              denied: :badge_required,
              wake: :human_asleep
            })

          {:ok, Map.put(pack, :lines, look(pack))}
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
