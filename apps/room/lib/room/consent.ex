defmodule Room.Consent do
  @moduledoc """
  Dual consent before morph.commit.

  One-sided grant cannot commit. Both required agents must grant.
  Badge is already on the room. No messenger. No Trust.
  """

  def look_one, do: "error  consent=one  morph=dual_consent_required"

  def look_both, do: "ok  consent=both  morph=morph.commit"

  def look(_pack \\ %{}) do
    [look_one(), look_both()]
  end

  @doc """
  One consent fails morph. Both commit. Isolated room id.
  Does not rewrite badge_demo LOOK.
  """
  def demo(opts \\ []) do
    id = Keyword.get(opts, :context_id) || "consent-" <> random_id()

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
         {:ok, badge} <- Room.Invite.mint(issuer: ariel),
         {:ok, _} <-
           Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}]),
         {:ok, _} <- Room.submit_badge(id, badge),
         {:ok, _} <- Room.propose_morph(id, ariel),
         {:ok, one_state} <- Room.consent(id, ariel) do
      one =
        case Room.commit_morph(id, "one consent is not enough", []) do
          {:error, :dual_consent_required} -> :dual_consent_required
          other -> other
        end

      with {:ok, _} <- Room.consent(id, kai),
           {:ok, state} <- Room.commit_morph(id, "Both agents granted. Humans may join.", []) do
        last = state.events |> Enum.map(& &1.type) |> List.last()

        cond do
          one != :dual_consent_required ->
            {:error, :one_committed}

          one_state.dual_consent ->
            {:error, :one_was_dual}

          last != "morph.commit" or not state.dual_consent ->
            {:error, :no_commit}

          true ->
            pack = %{one: one, state: state, badge: badge}
            {:ok, Map.put(pack, :lines, look(pack))}
        end
      end
    end
  end

  defp random_id do
    :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
  end
end
