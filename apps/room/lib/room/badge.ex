defmodule Room.Badge do
  @moduledoc """
  Mint a badge. Anti-spam join gate — not postage.

  v0 sources: `pull_match` (need↔open fit), `vouch`, `invite`.
  Optional `pow` mint is an alternate (kind `proof_of_work`) and
  is not a day-one `mint_sources()` entry. Kind stays
  `pull_intent` / `vouch` / `invite_token` for those sources.
  Tests assert ids.
  """

  @mint_sources ~w(pull_match vouch invite)
  @min_score 0.0

  def mint_sources, do: @mint_sources

  @doc """
  Spam-gate LOOK. One proof per line. Agents talk free; morph needs
  badge + dual consent. Pull-match mints. Self-vouch fails.
  """
  def look(pack) when is_map(pack) do
    denied = pack[:denied] || pack["denied"] || "badge_required"
    mint = pack[:mint] || pack[:source] || pack["source"] || "pull_match"
    kind = pack[:badge] || pack[:kind] || pack["kind"] || "pull_intent"
    topic = pack[:topic] || pack["topic"]
    self = pack[:self] || pack[:self_vouch] || "self_vouch"
    one = pack[:one] || pack[:consent_one] || "dual_consent_required"
    morph = pack[:morph] || "morph.commit"

    [
      "ok  talk=free  morph=denied  denied=#{denied}",
      "ok  mint=#{mint}  badge=#{kind}  topic=#{topic}",
      "error  vouch=self  error=#{self}",
      "ok  consent=one  morph=#{one}",
      "ok  consent=both  morph=#{morph}  badge=#{kind}"
    ]
  end

  def mint(:pull_match, opts) when is_list(opts) or is_map(opts),
    do: mint_pull_match(opts)

  def mint("pull_match", opts), do: mint(:pull_match, opts)

  def mint(:vouch, opts) when is_list(opts) or is_map(opts), do: mint_vouch(opts)
  def mint("vouch", opts), do: mint(:vouch, opts)

  def mint(:invite, opts) when is_list(opts) or is_map(opts), do: mint_invite(opts)
  def mint("invite", opts), do: mint(:invite, opts)

  def mint(:pow, opts) when is_list(opts) or is_map(opts), do: mint_pow(opts)
  def mint("pow", opts), do: mint(:pow, opts)

  def mint(:self, _), do: {:error, :self_vouch}
  def mint("self", opts), do: mint(:self, opts)

  def mint(_, _), do: {:error, :unknown_mint_source}

  @doc """
  Mint from a Need×Has match (find→mazel path). Overlap is the
  pull. Curious / unfit never mint. Score is the match itself
  (1.0), not the Factor compose — morph gate, not quant.
  """
  def from_need_has(need, match, actor) when is_map(match) do
    handle = match[:handle]
    overlap = List.wrap(match[:overlap])
    topic = List.first(overlap) || pick(need, :topic)

    cond do
      match[:unfit] == true or match[:error] == "curious" or match[:curious] == true ->
        {:error, :no_pull_match}

      match[:ok] != true or is_nil(handle) or overlap == [] or blank?(topic) ->
        {:error, :no_pull_match}

      true ->
        need_id = pick(need, :id) || pick(need, :need_id) || "need-#{topic}"

        mint(:pull_match,
          need: %{id: need_id, topic: topic},
          open: %{id: handle, handle: handle, topic: topic},
          match: %{id: handle, topic: topic, score: 1.0, handle: handle},
          actor: actor
        )
    end
  end

  def from_need_has(_, _, _), do: {:error, :no_pull_match}

  @doc "Mint from a ranked need's open hits (same JIT as `Room.Need.match`)."
  def from_need_matches(need, matches, actor) do
    hit = Enum.find(matches || [], &(&1.kind == "open" && usable_score?(&1)))

    cond do
      is_nil(hit) ->
        {:error, :no_pull_match}

      true ->
        mint(:pull_match,
          need: need,
          open: %{id: hit.id, kind: "open", topic: hit.topic, handle: hit[:handle]},
          match: hit,
          actor: actor
        )
    end
  end

  @doc "Mint from a ranked open's need hits (same JIT as `Room.Open.match`)."
  def from_open_matches(open, matches) do
    hit = Enum.find(matches || [], &(&1.kind == "need" && usable_score?(&1)))

    if is_nil(hit) do
      {:error, :no_pull_match}
    else
      mint(:pull_match,
        need: %{id: hit.id, kind: "need", topic: hit.topic},
        open: open,
        match: hit,
        actor: open[:handle]
      )
    end
  end

  defp mint_pull_match(opts) do
    opts = atomize(opts)
    need = opts[:need] || %{}
    open = opts[:open] || %{}
    hit = opts[:match] || %{}
    topic = pick(hit, :topic) || pick(need, :topic) || pick(open, :topic)
    score = score(hit[:score] || hit["score"] || opts[:score])
    need_id = pick(need, :id) || pick(hit, :id)
    open_id = pick(open, :id) || pick(hit, :open_id)
    actor = opts[:actor]

    cond do
      score <= @min_score ->
        {:error, :no_pull_match}

      blank?(topic) or blank?(need_id) or blank?(open_id) ->
        {:error, :no_pull_match}

      true ->
        case require_actor(actor) do
          {:ok, actor} ->
            badge = %{
              kind: "pull_intent",
              source: "pull_match",
              actor: actor,
              topic: topic,
              intent: "pull-match #{topic} need=#{need_id} open=#{open_id}",
              need_id: need_id,
              open_id: open_id,
              score: score
            }

            with :ok <- Room.Types.validate_badge(badge) do
              {:ok, Room.Types.stringify_keys(badge)}
            end

          error ->
            error
        end
    end
  end

  defp mint_vouch(opts) do
    opts = atomize(opts)
    voucher = opts[:voucher]
    subject = opts[:subject]
    note = opts[:note] || "vouch"

    with {:ok, voucher} <- require_actor(voucher),
         {:ok, subject} <- require_actor(subject),
         :ok <-
           Room.Types.validate_badge(%{kind: "vouch", voucher: voucher, note: note},
             subject: subject
           ) do
      {:ok,
       Room.Types.stringify_keys(%{kind: "vouch", source: "vouch", voucher: voucher, note: note})}
    end
  end

  defp mint_invite(opts) do
    opts = atomize(opts)
    issuer = opts[:issuer]
    token = opts[:token]

    badge = %{kind: "invite_token", source: "invite", issuer: issuer, token: token}

    with :ok <- Room.Types.validate_badge(badge) do
      {:ok, Room.Types.stringify_keys(badge)}
    end
  end

  defp mint_pow(opts) do
    opts = atomize(opts)
    nonce = opts[:nonce] || opts[:response]
    difficulty = opts[:difficulty]
    actor = opts[:actor] || "kai@mazel"

    cond do
      not valid_pow_nonce?(nonce) or not valid_pow_difficulty?(difficulty) ->
        {:error, :invalid_pow}

      true ->
        badge = %{
          kind: "proof_of_work",
          source: "pow",
          actor: actor,
          nonce: nonce,
          difficulty: difficulty
        }

        with :ok <- Room.Types.validate_badge(badge) do
          {:ok, Room.Types.stringify_keys(badge)}
        end
    end
  end

  defp valid_pow_nonce?(nonce) when is_binary(nonce) do
    s = String.trim(nonce)
    String.length(s) >= 8 and Regex.match?(~r/^[0-9a-fA-F]+$/, s)
  end

  defp valid_pow_nonce?(_), do: false

  defp valid_pow_difficulty?(n) when is_integer(n), do: n in 1..32
  defp valid_pow_difficulty?(_), do: false

  defp require_actor(%{id: id} = handle) when is_binary(id) and id != "", do: {:ok, handle}
  defp require_actor(%{"id" => id} = handle) when is_binary(id) and id != "", do: {:ok, handle}

  defp require_actor(raw) when is_binary(raw) do
    case Room.Wings.parse_handle(raw) do
      {:ok, handle} -> {:ok, handle}
      {:error, :malformed_handle} -> {:error, :missing_actor}
      error -> error
    end
  end

  defp require_actor(_), do: {:error, :missing_actor}

  defp usable_score?(hit), do: score(hit[:score] || hit["score"]) > @min_score

  defp score(n) when is_number(n), do: n / 1
  defp score(_), do: 0.0

  defp pick(map, key) when is_map(map) do
    map[key] || map[Atom.to_string(key)]
  end

  defp pick(_, _), do: nil

  defp blank?(nil), do: true
  defp blank?(value), do: String.trim(to_string(value)) == ""

  defp atomize(opts) when is_list(opts), do: Map.new(opts)
  defp atomize(opts) when is_map(opts), do: opts
end
