defmodule Room.A2aPeerTalk do
  @moduledoc """
  Durable A2A talk: POST message/send to a card
  JSON-RPC url, and accept that call on this
  Room origin (`POST /a2a`).

  Founder Pages origin is card-only
  (`rpc_none`). Does not POST to the card JSON
  itself. Does not invent RPC on a2a.mazel.ai.
  Real handles only — not a kai/buddy path.
  Off mix remint / LOOK catalog.
  """

  alias Room.A2aPeerCard, as: PeerCard

  @fixture_ids ["kai@mazel", "buddy@mazel"]
  @typed_errors [
    :empty_message,
    :empty_talk,
    :missing_peer,
    :fixture_handle,
    :malformed_handle,
    :rpc_method,
    :not_open,
    :unknown_participant,
    :talk_offline,
    :bad_json,
    :rpc_none
  ]

  def rpc_url(%{card: card}), do: PeerCard.rpc_endpoint(card)
  def rpc_url(%{peer: %{card: card}}), do: PeerCard.rpc_endpoint(card)
  def rpc_url(card) when is_map(card), do: PeerCard.rpc_endpoint(card)
  def rpc_url(_), do: {:error, :rpc_none}

  @doc "True when the JSON-RPC body names from+to peers."
  def accept?(params) when is_map(params) do
    usable?(peer_field(params, "from")) and usable?(peer_field(params, "to"))
  end

  def accept?(_), do: false

  @doc """
  Accept message/send for two real handles.
  Opens a Direct room and talks. Typed error
  on miss — never a silent hang.
  """
  def accept(params) when is_map(params) do
    id = rpc_id(params)

    case do_accept(params) do
      {:ok, result} ->
        {:ok, %{jsonrpc: "2.0", id: id, result: result}}

      {:error, reason} ->
        {:ok,
         %{
           jsonrpc: "2.0",
           id: id,
           error: %{
             code: -32_000,
             message: to_string(reason),
             data: to_string(reason)
           }
         }}
    end
  end

  def accept(_), do: {:error, :not_a_map}

  @doc """
  POST message/send when the card has a JSON-RPC
  endpoint. Else {:error, :rpc_none}.
  """
  def send(hit, text \\ "hello", opts \\ [])

  def send(hit, text, opts) when is_list(opts) do
    text = if is_nil(text), do: "hello", else: to_string(text)
    from = opts[:from]
    to = opts[:to] || hit_handle(hit)
    context_id = opts[:context_id]

    with {:ok, url} <- rpc_url(hit),
         :ok <- refuse_card_document(hit, url),
         {:ok, body} <- post_rpc(url, rpc_send(text, from, to, context_id)),
         {:ok, reply} <- decode_reply(body) do
      {:ok,
       %{
         status: :ok,
         to: url,
         from: from,
         handle: to,
         method: "message/send",
         jsonrpc: "2.0",
         reply: reply
       }}
    end
  end

  defp do_accept(params) do
    method = params["method"] || get_in(params, ["params", "method"]) || "message/send"
    from_raw = peer_field(params, "from")
    to_raw = peer_field(params, "to")
    text = extract_text(params)

    cond do
      method != "message/send" ->
        {:error, :rpc_method}

      not usable?(from_raw) or not usable?(to_raw) ->
        {:error, :missing_peer}

      true ->
        with {:ok, from} <- parse_peer(from_raw),
             {:ok, to} <- parse_peer(to_raw),
             :ok <- nonempty_text(text) do
          context_id =
            peer_field(params, "context_id") ||
              "a2a:" <> Enum.min([from.id, to.id]) <> ":" <> Enum.max([from.id, to.id])

          with {:ok, _} <- Room.open(context_id, :direct, [from, to]),
               {:ok, state} <- Room.talk(context_id, from, text) do
            {:ok,
             %{
               ok: true,
               talk: :ok,
               protocol: "haah",
               binding: "a2a",
               method: "message/send",
               context_id: context_id,
               from: from.id,
               to: to.id,
               session_kind: :direct,
               status: state.status
             }}
          end
        end
    end
  end

  defp parse_peer(raw) do
    case Room.Wings.parse_handle(raw) do
      {:ok, handle} ->
        if handle.id in @fixture_ids do
          {:error, :fixture_handle}
        else
          {:ok, handle}
        end

      error ->
        error
    end
  end

  defp nonempty_text(text) do
    if usable?(text), do: :ok, else: {:error, :empty_message}
  end

  defp rpc_send(text, from, to, context_id) do
    params = %{
      "message" => %{
        "role" => "user",
        "parts" => [%{"type" => "text", "text" => to_string(text)}]
      }
    }

    params =
      params
      |> maybe_put("from", from)
      |> maybe_put("to", to)
      |> maybe_put("context_id", context_id)

    %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "message/send",
      "params" => params
    }
  end

  defp refuse_card_document(hit, url) do
    card_url = card_document(hit)

    if usable?(card_url) and url == card_url do
      {:error, :rpc_none}
    else
      :ok
    end
  end

  defp card_document(%{card_url: url}) when is_binary(url), do: url
  defp card_document(%{url: url}) when is_binary(url), do: url
  defp card_document(%{card: card}) when is_map(card), do: card["url"] || card["card_url"]
  defp card_document(%{"url" => url}) when is_binary(url), do: url
  defp card_document(_), do: nil

  defp maybe_put(map, _key, value) when value in [nil, ""], do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp post_rpc(url, payload) do
    json = Jason.encode!(payload)

    args = [
      "-fsS",
      "-L",
      "--max-time",
      "8",
      "--connect-timeout",
      "5",
      "-H",
      "content-type: application/json",
      "-H",
      "accept: application/json",
      "-A",
      "mazel-a2a/0.1",
      "-d",
      json,
      url
    ]

    case System.cmd("curl", args, stderr_to_stdout: true) do
      {body, 0} when is_binary(body) ->
        {:ok, body}

      {_out, _} ->
        {:error, :talk_offline}
    end
  end

  defp decode_reply(body) do
    case Jason.decode(body) do
      {:ok, %{"error" => err}} ->
        {:error, typed_error(err)}

      {:ok, map} when is_map(map) ->
        {:ok, map}

      _ ->
        {:error, :bad_json}
    end
  end

  defp typed_error(%{"data" => data}) when is_binary(data) do
    Enum.find(@typed_errors, :talk_error, &(Atom.to_string(&1) == data))
  end

  defp typed_error(%{"message" => message}) when is_binary(message) do
    Enum.find(@typed_errors, :talk_error, &(Atom.to_string(&1) == message))
  end

  defp typed_error(_), do: :talk_error

  defp peer_field(params, key) do
    params[key] || get_in(params, ["params", key])
  end

  defp rpc_id(%{"jsonrpc" => _, "id" => id}), do: id
  defp rpc_id(_), do: nil

  defp hit_handle(%{handle: handle}) when is_binary(handle), do: handle
  defp hit_handle(%{"handle" => handle}) when is_binary(handle), do: handle
  defp hit_handle(_), do: nil

  defp extract_text(params) do
    params["text"] ||
      get_in(params, ["message", "text"]) ||
      part_text(get_in(params, ["message", "parts"])) ||
      get_in(params, ["params", "text"]) ||
      get_in(params, ["params", "message", "text"]) ||
      part_text(get_in(params, ["params", "message", "parts"]))
  end

  defp part_text(parts) when is_list(parts) do
    Enum.find_value(parts, fn
      %{"text" => text} -> text
      %{text: text} -> text
      _ -> nil
    end)
  end

  defp part_text(_), do: nil

  defp usable?(value) when is_binary(value), do: String.trim(value) != ""
  defp usable?(_), do: false
end
