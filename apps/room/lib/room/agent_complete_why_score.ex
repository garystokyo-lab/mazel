defmodule Room.AgentCompleteWhyScore do
  @moduledoc """
  Double-magic why + named Factor inputs on complete=agent.

  why_fields + Score.gather on one in-agent strip.
  Distinct from agent_complete_why (no inputs=) and
  agent_complete_score (no why). Not badge. Not PDF. No morph.
  """

  def look_why(rec) when is_map(rec) do
    [
      "why  need=#{rec[:why_need] || "series-a"}",
      "why  has=#{rec[:why_has] || "series-a"}"
    ]
  end

  def look_why(_), do: look_why(%{})

  def look(pack) when is_map(pack) do
    [
      Room.AgentCompleteScore.look_find(),
      Room.AgentCompleteScore.look_match(pack.match)
    ] ++ look_why(pack.match) ++
      [Room.AgentCompleteScore.look_complete(), Room.AgentCompleteScore.look_claim()]
  end

  def look(_), do: look(%{match: %{}})

  @doc """
  Find → Need×Has completes in-agent with inputs + why.
  Claim is curious. Isolated. Sibling LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "agent-why-score-" <> random_id()

    with {:ok, scored} <-
           Room.AgentCompleteScore.demo(Keyword.put(opts, :context_id, prefix)) do
      why = Room.Score.why_fields(scored.need, scored.match)
      why_need = scored.match[:why_need] || why.why_need
      why_has = scored.match[:why_has] || why.why_has

      cond do
        why_need in [nil, ""] or why_has in [nil, ""] ->
          {:error, :why_miss}

        is_nil(scored.match[:inputs]) ->
          {:error, :inputs_miss}

        not Map.has_key?(scored.match.inputs, :trail) or not Map.has_key?(scored.match.inputs, :check) ->
          {:error, :trail_miss}

        Enum.any?(scored.lines, &String.starts_with?(&1, "why  ")) ->
          {:error, :score_already_why}

        true ->
          match = Map.merge(scored.match, %{why_need: why_need, why_has: why_has})
          pack = %{scored | match: match}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
