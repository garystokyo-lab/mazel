defmodule Room.Human do
  @moduledoc """
  One human, through their agent. Resolve a real-ish Agent Card, badge, morph-ready packet.

  Missing peer card is an error. No fake success.
  """

  def run(opts \\ []) do
    from_raw = Keyword.get(opts, :from) || System.get_env("MAZEL_FROM") || "ariel"
    peer_raw = Keyword.get(opts, :peer) || System.get_env("MAZEL_PEER") || "kai"
    text = Keyword.get(opts, :text) || System.get_env("MAZEL_TEXT") || default_text(opts)
    context_id = Keyword.get(opts, :context_id) || "human-" <> random_id()
    kind = session_kind(Keyword.get(opts, :kind) || System.get_env("MAZEL_KIND"))

    with {:ok, badge_kind} <-
           badge_kind(Keyword.get(opts, :badge) || System.get_env("MAZEL_BADGE")),
         {:ok, from} <- require_card(from_raw, :from),
         {:ok, peer} <- require_card(peer_raw, :peer),
         badge <- build_badge(badge_kind, from, peer, topic_for(kind), text),
         :ok <- Room.Types.validate_badge(badge, subject: peer) do
      play(context_id, kind, from, peer, text, badge)
    end
  end

  def session_kind(:intro), do: :intro
  def session_kind(:direct), do: :direct
  def session_kind("intro"), do: :intro
  def session_kind("direct"), do: :direct
  def session_kind(_), do: :direct

  def badge_kind(kind) when kind in [:vouch, "vouch"], do: {:ok, :vouch}

  def badge_kind(kind) when kind in [:pull_intent, "pull_intent", nil, ""],
    do: {:ok, :pull_intent}

  def badge_kind(other), do: {:error, {:unknown_badge, other}}

  def require_card(raw, role) do
    raw = normalize_raw(raw)

    case Room.Cards.lookup(raw) do
      {:ok, %{sink: true} = hit} ->
        {:error, {:not_a_person, role, hit.id, hit.sink_kind}}

      {:ok, hit} ->
        if blank?(hit.card_url) do
          {:error, {:missing_card, role, hit.id}}
        else
          {:ok, hit}
        end

      {:error, :unknown_handle} ->
        {:error, {:unknown_handle, role, raw}}

      {:error, {:invalid_card, path, reason}} ->
        {:error, {:invalid_card, role, raw, path, reason}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def explain_error({:unknown_handle, role, raw}) do
    key = "MAZEL_CARD_#{env_hint(raw)}"

    """
    err  #{role}=#{raw}  error=unknown_handle
         drop cards/#{local(raw)}.json  or  dotenvx set #{key} -- https://host/card.json
         dotenvx encrypt && dotenvx run -- mix human_demo
    """
    |> String.trim()
  end

  def explain_error({:missing_card, role, id}) do
    "err  #{role}=#{id}  error=missing_card  (no fake success — card url empty)"
  end

  def explain_error({:not_a_person, role, id, kind}) do
    "err  #{role}=#{id}  error=not_a_person  kind=#{kind}  (need/open sink, not a peer)"
  end

  def explain_error({:invalid_card, role, raw, path, reason}) do
    """
    err  #{role}=#{raw}  error=invalid_card  reason=#{reason}  file=#{path}
         need handle + url + protocol=haah  in cards/#{local(raw)}.json
         or dotenvx set MAZEL_CARD_#{env_hint(raw)} -- https://host/card.json
    """
    |> String.trim()
  end

  def explain_error(:self_vouch) do
    "err  error=self_vouch  (voucher cannot vouch for themselves)"
  end

  def explain_error({:unknown_badge, raw}) do
    "err  error=unknown_badge  kind=#{raw}  (ids: vouch pull_intent)"
  end

  def explain_error(reason), do: "err  #{inspect(reason)}"

  defp play(context_id, kind, from, peer, text, badge) do
    {:ok, _} =
      Room.open(context_id, kind, [
        %{handle: Map.take(from, [:id, :card_url]), role: :agent},
        %{handle: Map.take(peer, [:id, :card_url]), role: :agent}
      ])

    {:ok, _} = Room.submit_badge(context_id, badge)
    {:ok, _} = Room.propose_morph(context_id, from.id)
    {:ok, _} = Room.consent(context_id, from.id)
    {:ok, _} = Room.consent(context_id, peer.id)

    {:ok, state} =
      Room.commit_morph(
        context_id,
        summary(kind, from, peer, text),
        [
          %{speaker: Map.take(from, [:id, :card_url]), text: text},
          %{
            speaker: Map.take(peer, [:id, :card_url]),
            text: "Agent has the card. Morph when the human wants in."
          }
        ]
      )

    {:ok,
     %{
       from: from,
       peer: peer,
       kind: kind,
       state: state,
       opener: opener(kind, from, peer, state)
     }}
  end

  defp build_badge(:vouch, from, peer, _topic, _text) do
    %{
      kind: "vouch",
      voucher: Map.take(from, [:id, :card_url]),
      note: "#{from.id} vouches for #{peer.id}. Intro through their agent."
    }
  end

  defp build_badge(:pull_intent, from, peer, topic, _text) do
    %{
      kind: "pull_intent",
      actor: Map.take(from, [:id, :card_url]),
      intent: "Mazel #{peer.id}. Wake the human through their agent. (#{topic})",
      topic: topic
    }
  end

  defp topic_for(:intro), do: "intro-wing"
  defp topic_for(_), do: "direct-wing"

  defp default_text(opts) do
    case session_kind(Keyword.get(opts, :kind) || System.get_env("MAZEL_KIND")) do
      :intro -> "Ariel introducing a peer."
      _ -> "Ariel wants in."
    end
  end

  defp summary(:intro, from, peer, text) do
    "Intro is open. #{from.id} mazeled #{peer.id}. #{text} Humans inherit this packet."
  end

  defp summary(_, from, peer, _text) do
    "Direct is open. #{from.id} mazeled #{peer.id}. Humans inherit this packet."
  end

  defp opener(kind, from, peer, state) do
    """
    Mazel through #{peer.id}. kind=#{kind} is open. badge=#{state.badge["kind"]}. Morph when you want in.
    card    #{peer.card_url}
    from    #{from.id}
    packet  #{state.context_id}
    """
    |> String.trim()
  end

  defp normalize_raw(raw) do
    raw = String.trim(to_string(raw))

    cond do
      raw == "" -> raw
      String.starts_with?(raw, "@") -> raw
      String.contains?(raw, "@") -> raw
      true -> "@" <> raw
    end
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_), do: false

  defp local(raw) do
    raw
    |> String.trim()
    |> String.trim_leading("@")
    |> String.split("@")
    |> hd()
    |> String.downcase()
  end

  defp env_hint(raw), do: raw |> local() |> String.upcase() |> String.replace(~r/[^A-Z0-9]+/, "_")

  defp random_id do
    :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
  end
end
