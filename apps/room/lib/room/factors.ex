defmodule Room.Factors do
  @moduledoc """
  Deterministic Factor registry.

  Score is a **pure** function of structured **proof** inputs and a
  weights table. Same inputs → same score. No I/O. No LLM. The model
  may emit factor inputs only; it never ranks.

  Plugins (`fit`, `heat`, `fresh`, `trail`, `check`) are
  proof-shaped. GitHub connector fields (`trail`, `check`) are
  named Factor inputs — not vibes, not LLM ranking. Trail/check
  feed **heat** (same band as vouch). Product compose stays
  `fit × heat × fresh` so a missing trail does not zero a vouched
  match. Resume-alone stays curious (`trail=0`, `check=0`) and
  does not lift. Later proof signals (gmail / icp / …) register
  as new plugins — not a black box, not hop-count, **never**
  chat-BM25 / message-text similarity / embedding-wildcard ranking.

  Curious, claim, or wildcard → forced unfit (never matches).
  High-turn chat may be mined for structured proof inputs
  (`provenance=chat_depth` on Has). Quant ranks those inputs.
  Chat text itself is never a factor. Self-report alone stays
  curious unless a trail backs it.
  """

  @weights %{fit: 1, heat: 2, fresh: 1}

  @plugins %{
    fit: __MODULE__.Fit,
    heat: __MODULE__.Heat,
    fresh: __MODULE__.Fresh,
    trail: __MODULE__.Trail,
    check: __MODULE__.Check
  }

  # Extension seam: later proof plugins (icp / package-x) register
  # here. Gmail edge-heat is an optional prior that fills `heat` —
  # not a plugin, not hop-count, never chat-BM25 / message similarity.
  @future []

  # Product compose. trail/check are named inputs that feed heat;
  # they do not join the product (missing GH must not zero a vouch).
  @input_ids [:fit, :heat, :fresh]
  @proof_ids [:trail, :check]
  @named_ids @input_ids ++ @proof_ids

  def weights, do: @weights
  def plugins, do: @plugins
  def future, do: @future
  def ids, do: @plugins |> Map.keys() |> Enum.sort()
  def input_ids, do: @input_ids
  def proof_ids, do: @proof_ids
  def named_ids, do: @named_ids

  @doc """
  Pure score. `inputs` are named factor values (`fit` / `heat` /
  `fresh` / `trail` / `check`, plus `claim` / `curious` gates).
  LLM never ranks. Curious or claim is forced unfit and never matches.
  """
  def score(inputs, weights \\ @weights) when is_map(inputs) do
    weights = normalize_weights(weights)
    named = named_inputs(inputs)

    if unfit?(inputs) do
      %{
        factors: named,
        inputs: named,
        score: 0,
        unfit: true
      }
    else
      product =
        Enum.reduce(@input_ids, 1, fn id, acc ->
          acc * Map.get(named, id, 0) * Map.get(weights, id, 1)
        end)

      %{
        factors: named,
        inputs: named,
        score: whole(product),
        unfit: false
      }
    end
  end

  def unfit?(inputs) when is_map(inputs) do
    ttl = get(inputs, :need_ttl)

    truthy?(get(inputs, :unfit)) or
      truthy?(get(inputs, :curious)) or
      truthy?(get(inputs, :claim)) or
      truthy?(get(inputs, :wildcard)) or
      ttl in [:expired, "expired"] or
      kind_of(inputs) in [:curious, :claim, :wildcard, "curious", "claim", "wildcard"]
  end

  def unfit?(_), do: false

  def format_inputs(named) when is_map(named) do
    format_ids(named, @input_ids)
  end

  def format_inputs(_), do: "{fit:0,heat:0,fresh:0}"

  @doc "Product + GH proof fields. Used by trail/check LOOK."
  def format_inputs(named, :all) when is_map(named) do
    format_ids(named, @named_ids)
  end

  def format_inputs(_, :all), do: "{fit:0,heat:0,fresh:0,trail:0,check:0}"

  defp format_ids(named, ids) do
    inner =
      Enum.map_join(ids, ",", fn id ->
        "#{id}:#{whole(Map.get(named, id, 0))}"
      end)

    "{#{inner}}"
  end

  defp named_inputs(inputs) do
    Map.new(@named_ids, fn id ->
      plugin = Map.fetch!(@plugins, id)
      {id, plugin.input(inputs)}
    end)
  end

  defp normalize_weights(weights) when is_map(weights) do
    Map.new(@input_ids, fn id ->
      {id, get(weights, id) || Map.get(@weights, id)}
    end)
  end

  defp kind_of(inputs), do: get(inputs, :kind) || get(inputs, :status)

  defp get(map, key) when is_atom(key) do
    Map.get(map, key, Map.get(map, Atom.to_string(key)))
  end

  defp truthy?(true), do: true
  defp truthy?(1), do: true
  defp truthy?(1.0), do: true
  defp truthy?("true"), do: true
  defp truthy?("1"), do: true
  defp truthy?(_), do: false

  defp whole(n) when is_float(n) do
    if n == Float.floor(n), do: trunc(n), else: n
  end

  defp whole(n) when is_integer(n), do: n
  defp whole(_), do: 0

  defmodule Fit do
    @moduledoc false
    def id, do: :fit

    def input(inputs) do
      case Room.Factors.get_raw(inputs, :fit) do
        n when is_number(n) and n > 0 -> 1
        true -> 1
        "1" -> 1
        _ -> 0
      end
    end
  end

  defmodule Heat do
    @moduledoc false
    def id, do: :heat

    def input(inputs) do
      case Room.Factors.get_raw(inputs, :heat) do
        "has" -> 1
        n when is_number(n) and n > 0 -> 1
        true -> 1
        "1" -> 1
        n when is_number(n) -> 0
        false -> 0
        "0" -> 0
        _ ->
          # Structured GH trail/check feeds heat (same band as vouch).
          if Room.Factors.Trail.input(inputs) == 1 or Room.Factors.Check.input(inputs) == 1 do
            1
          else
            0
          end
      end
    end
  end

  defmodule Fresh do
    @moduledoc false
    def id, do: :fresh

    def input(inputs) do
      case Room.Factors.get_raw(inputs, :fresh) do
        n when is_number(n) and n > 0 -> 1
        true -> 1
        "1" -> 1
        "fresh" -> 1
        _ -> 0
      end
    end
  end

  defmodule Trail do
    @moduledoc false
    def id, do: :trail

    def input(inputs) do
      Room.Factors.proof_flag(Room.Factors.get_raw(inputs, :trail))
    end
  end

  defmodule Check do
    @moduledoc false
    def id, do: :check

    def input(inputs) do
      Room.Factors.proof_flag(Room.Factors.get_raw(inputs, :check))
    end
  end

  @doc false
  def proof_flag(value) do
    case value do
      n when is_number(n) and n > 0 -> 1
      true -> 1
      "1" -> 1
      "has" -> 1
      "true" -> 1
      _ -> 0
    end
  end

  @doc false
  def get_raw(map, key), do: get(map, key)
end
