defmodule Room.Types do
  @moduledoc """
  Elixir mirrors of mazel-core types. Rust is the type authority; this is the BEAM stub.
  """

  @badge_kinds ~w(vouch pull_intent invite_token proof_of_work)

  def handle(id, card_url \\ nil) when is_binary(id) do
    id = String.trim(id)

    if id == "" do
      {:error, :empty_handle}
    else
      {:ok, %{id: id, card_url: empty_to_nil(card_url)}}
    end
  end

  def handle!(id, card_url \\ nil) do
    {:ok, h} = handle(id, card_url)
    h
  end

  def session_kind(kind) when kind in [:direct, :intro, :group], do: kind
  def session_kind("direct"), do: :direct
  def session_kind("intro"), do: :intro
  def session_kind("group"), do: :group

  # Literal 🪽 only. No alternate wing art. mazelai avatar is the other mark.
  def wing_mark(:direct), do: "🪽"
  def wing_mark(:intro), do: "🪽🪽"
  def wing_mark(:group), do: "🪽🪽🪽"
  def wing_mark(nil), do: "🪽"

  def validate_badge(badge, opts \\ [])

  def validate_badge(badge, opts) when is_map(badge) and is_list(opts) do
    badge = stringify_keys(badge)

    case badge do
      %{"kind" => "vouch", "note" => note} = badge ->
        with :ok <- nonempty(note, :empty_claim),
             :ok <- require_handle(badge["voucher"], :missing_voucher) do
          reject_self_vouch(badge["voucher"], opts[:subject])
        end

      %{"kind" => "pull_intent", "intent" => intent} = badge ->
        topic = badge["topic"]

        with :ok <- nonempty(intent, :empty_claim),
             :ok <- require_handle(badge["actor"], :missing_actor) do
          cond do
            is_binary(topic) and topic != "" and
                not String.contains?(String.downcase(intent), String.downcase(topic)) ->
              {:error, :topic_mismatch}

            true ->
              :ok
          end
        end

      %{"kind" => "invite_token", "token" => token} = badge ->
        with :ok <- require_handle(badge["issuer"], :missing_issuer) do
          if String.length(String.trim(to_string(token))) >= 12,
            do: :ok,
            else: {:error, :weak_token}
        end

      %{"kind" => "proof_of_work", "nonce" => nonce, "difficulty" => difficulty} ->
        cond do
          difficulty not in 1..32 -> {:error, :weak_proof}
          not hex_nonce?(nonce) -> {:error, :weak_nonce}
          true -> :ok
        end

      %{"kind" => kind} when kind in @badge_kinds ->
        {:error, :malformed_badge}

      _ ->
        {:error, :malformed_badge}
    end
  end

  def validate_badge(_, _), do: {:error, :malformed_badge}
  def validate_postage(badge), do: validate_badge(badge)

  def participant(handle, role) when role in [:agent, :human] do
    %{handle: handle, role: role, online: true}
  end

  def now_iso do
    DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
  end

  def stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), stringify_value(v)}
      {k, v} -> {k, stringify_value(v)}
    end)
  end

  defp stringify_value(%{id: _} = handle), do: handle
  defp stringify_value(v), do: v

  defp nonempty(value, error) do
    if String.trim(to_string(value)) == "", do: {:error, error}, else: :ok
  end

  defp require_handle(%{id: id}, error), do: nonempty(id, error)
  defp require_handle(%{"id" => id}, error), do: nonempty(id, error)
  defp require_handle(_, error), do: {:error, error}

  defp reject_self_vouch(_voucher, nil), do: :ok

  defp reject_self_vouch(voucher, subject) do
    if handle_id(voucher) == handle_id(subject) and handle_id(voucher) != nil do
      {:error, :self_vouch}
    else
      :ok
    end
  end

  defp handle_id(%{id: id}) when is_binary(id), do: id
  defp handle_id(%{"id" => id}) when is_binary(id), do: id
  defp handle_id(id) when is_binary(id), do: id
  defp handle_id(_), do: nil

  defp hex_nonce?(nonce) do
    s = String.trim(to_string(nonce))
    String.length(s) >= 8 and Regex.match?(~r/^[0-9a-fA-F]+$/, s)
  end

  defp empty_to_nil(nil), do: nil

  defp empty_to_nil(url) do
    url = String.trim(to_string(url))
    if url == "", do: nil, else: url
  end
end
