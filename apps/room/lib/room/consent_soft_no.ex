defmodule Room.ConsentSoftNo do
  @moduledoc """
  Stamped but consent-pending: agent soft-no, human stays asleep.

  Dual consent not both yet → no wake. Both → wake_ok.
  Extends soft_no without rewriting that LOOK.
  """

  def look_one, do: "ok  stamp=pull_match  consent=one  agent=soft_no  human=asleep"
  def look_denied, do: "ok  morph=denied  denied=dual_consent_required"
  def look_both, do: "ok  consent=both  human=wake_ok"

  def look(_pack \\ %{}) do
    [look_one(), look_denied(), look_both()]
  end

  def agent(state) when is_map(state) do
    cond do
      not Room.SoftNo.stamped?(state) -> {:ok, :soft_no}
      dual?(state) -> {:ok, :talk}
      true -> {:ok, :soft_no}
    end
  end

  def agent(_), do: {:ok, :soft_no}

  def wake(state) when is_map(state) do
    cond do
      not Room.SoftNo.stamped?(state) -> {:error, :human_asleep}
      dual?(state) -> {:ok, :wake_ok}
      true -> {:error, :human_asleep}
    end
  end

  def wake(_), do: {:error, :human_asleep}

  @doc """
  Badge on, one consent: soft-no + asleep. Both: wake_ok.
  Isolated. Does not rewrite soft_no / consent / badge LOOK.
  """
  def demo(opts \\ []) do
    id = Keyword.get(opts, :context_id) || "consent-soft-" <> random_id()

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
         {:ok, badge} <- pull_stamp(ariel),
         {:ok, _} <-
           Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}]),
         {:ok, _} <- Room.submit_badge(id, badge),
         {:ok, _} <- Room.propose_morph(id, ariel),
         {:ok, one} <- Room.consent(id, ariel),
         {:ok, :soft_no} <- agent(one),
         {:error, :human_asleep} <- wake(one) do
      denied =
        case Room.commit_morph(id, "one consent is not enough", []) do
          {:error, :dual_consent_required} -> :dual_consent_required
          other -> other
        end

      with {:ok, both} <- Room.consent(id, kai),
           {:ok, :wake_ok} <- wake(both) do
        cond do
          denied != :dual_consent_required ->
            {:error, :one_committed}

          one.dual_consent ->
            {:error, :one_was_dual}

          not both.dual_consent ->
            {:error, :no_dual}

          humans_awake?(one) ->
            {:error, :human_woke}

          true ->
            pack = %{one: one, both: both, badge: badge, denied: denied}
            {:ok, Map.put(pack, :lines, look(pack))}
        end
      end
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

  defp dual?(state), do: state[:dual_consent] == true

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
