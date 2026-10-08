defmodule Room.PowMint do
  @moduledoc """
  Optional proof-of-work badge mint.

  Alternate to invite / pull_match / vouch-from-other.
  Fixture challenge/response only — not a mining farm.
  Dual consent still required for morph. Self cannot mint.
  """

  @challenge "pow-v0"
  @response "c0ffee00"
  @difficulty 8

  def challenge, do: %{id: @challenge, difficulty: @difficulty}
  def response, do: @response
  def difficulty, do: @difficulty

  def solve(%{id: @challenge}), do: {:ok, @response}
  def solve(@challenge), do: {:ok, @response}
  def solve(_), do: {:error, :invalid_pow}

  def look_pow(badge) when is_map(badge) do
    "ok  mint=#{badge["source"] || badge[:source]}  badge=#{badge["kind"] || badge[:kind]}"
  end

  def look_morph, do: "ok  morph=morph.commit  badge=proof_of_work  consent=dual"

  def look_self, do: "error  mint=self  error=self_vouch"

  def look(pack) when is_map(pack) do
    [look_pow(pack.pow), look_morph(), look_self()]
  end

  def look(_), do: look(%{pow: %{}})

  @doc """
  Fixture PoW mints `proof_of_work`. Dual consent commits morph.
  Self still fails. Isolated room. Does not rewrite badge_demo LOOK.
  """
  def demo(opts \\ []) do
    id = Keyword.get(opts, :context_id) || "pow-" <> random_id()

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
         {:ok, answer} <- solve(challenge()),
         {:ok, pow} <-
           Room.Badge.mint(:pow,
             challenge: @challenge,
             response: answer,
             nonce: answer,
             difficulty: @difficulty,
             actor: ariel
           ),
         {:error, :self_vouch} <- Room.Badge.mint(:self, actor: ariel),
         {:error, :dual_consent_required} <- commit_one(id <> "-one", ariel, kai, pow),
         {:ok, state} <- commit_both(id, ariel, kai, pow) do
      last = state.events |> Enum.map(& &1.type) |> List.last()
      kind = state.badge["kind"] || state.badge[:kind]

      cond do
        "pow" in Room.Badge.mint_sources() ->
          {:error, :pow_is_source}

        Room.Badge.mint_sources() != ~w(pull_match vouch invite) ->
          {:error, :mint_sources}

        pow["source"] != "pow" or pow["kind"] != "proof_of_work" ->
          {:error, :pow_miss}

        last != "morph.commit" or not state.dual_consent ->
          {:error, :no_commit}

        kind != "proof_of_work" ->
          {:error, :badge_miss}

        true ->
          pack = %{pow: pow, state: state, self: :self_vouch}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp commit_one(id, ariel, kai, badge) do
    with {:ok, _} <-
           Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}]),
         {:ok, _} <- Room.submit_badge(id, badge),
         {:ok, _} <- Room.propose_morph(id, ariel),
         {:ok, _} <- Room.consent(id, ariel) do
      Room.commit_morph(id, "one consent is not enough", [])
    end
  end

  defp commit_both(id, ariel, kai, badge) do
    with {:ok, _} <-
           Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}]),
         {:ok, _} <- Room.submit_badge(id, badge),
         {:ok, _} <- Room.propose_morph(id, ariel),
         {:ok, _} <- Room.consent(id, ariel),
         {:ok, _} <- Room.consent(id, kai) do
      Room.commit_morph(id, "PoW badge minted. Humans may join.", [])
    end
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
