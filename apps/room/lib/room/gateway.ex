defmodule Room.Gateway do
  @moduledoc """
  Thin A2A/HAAH conduit. Serves an Agent Card and accepts a task stub.

  Not a messenger. Not a cloud agent fabric. Cards from `Room.Cards`.
  """

  @card_skills ~w(find chat direct)

  def default_handle do
    System.get_env("MAZEL_GATEWAY_HANDLE") || System.get_env("MAZEL_FROM") || "ariel"
  end

  def agent_card(raw \\ nil) do
    raw = blank_to_nil(raw) || default_handle()

    case Room.Human.require_card(raw, :handle) do
      {:ok, hit} -> {:ok, to_a2a(hit)}
      {:error, reason} -> {:error, reason}
    end
  end

  def task(params, opts \\ []) when is_map(params) do
    if Room.A2aPeerTalk.accept?(params) do
      Room.A2aPeerTalk.accept(params)
    else
      handle = params["handle"] || get_in(params, ["params", "handle"]) || opts[:handle]
      text = extract_text(params)

      with {:ok, card} <- agent_card(handle) do
        play(card, text, rpc_id(params))
      end
    end
  end

  defp play(card, text, rpc_id) do
    task_id = "task-" <> random_id()
    context_id = "a2a-" <> random_id()

    envelope = %{
      ok: true,
      kind: "envelope",
      protocol: "haah",
      binding: "a2a",
      method: "message/send",
      context_id: context_id,
      card: %{
        handle: card.handle,
        url: card.card_url,
        protocol: "haah",
        source: card.source
      },
      task: %{
        id: task_id,
        kind: "task",
        contextId: context_id,
        status: %{state: "submitted"}
      }
    }

    envelope =
      case dispatch_text(text) do
        nil ->
          envelope
          |> Map.put(:text, text)
          |> Map.put(:qualify, "no")

        {:ok, result} ->
          envelope
          |> Map.put(:text, text)
          |> Map.put(:qualify, "yes")
          |> Map.put(:session_kind, result[:session_kind] || result[:kind])
          |> Map.put(:result, result)
          |> put_in([:task, :status, :state], "completed")

        {:error, reason} ->
          {:error, reason}
      end

    case envelope do
      {:error, _} = err -> err
      map -> {:ok, maybe_rpc(map, rpc_id)}
    end
  end

  defp dispatch_text(nil), do: nil
  defp dispatch_text(""), do: {:error, :empty_message}

  defp dispatch_text(text) do
    trimmed = String.trim(text)

    cond do
      trimmed == "" ->
        {:error, :empty_message}

      String.starts_with?(trimmed, "🪽") or String.starts_with?(String.downcase(trimmed), "mazel") ->
        case Room.Tools.wing(trimmed) do
          {:ok, %{ok: false, error: err}} -> {:error, err}
          other -> other
        end

      true ->
        nil
    end
  end

  def with_public_base(card, base) do
    base = normalize_base(base)

    if is_nil(base) do
      card
    else
      url = base <> "/a2a"

      card
      |> Map.put(:url, url)
      |> Map.put(:edge, base)
      |> Map.update(:bindings, [], fn list ->
        Enum.map(list, fn binding -> Map.put(binding, :url, url) end)
      end)
    end
  end

  def public_base(conn) do
    env_public_base() || forwarded_base(conn)
  end

  @doc "Tunnel / public edge from `MAZEL_PUBLIC_URL`. Nil when unset."
  def env_public_base do
    System.get_env("MAZEL_PUBLIC_URL") |> normalize_base()
  end

  defp forwarded_base(conn) do
    case header(conn, "x-forwarded-host") do
      nil ->
        nil

      host ->
        proto = header(conn, "x-forwarded-proto") || to_string(conn.scheme)
        normalize_base("#{proto}://#{host}")
    end
  end

  defp header(conn, name) do
    case Plug.Conn.get_req_header(conn, name) do
      [value | _] ->
        value
        |> String.split(",", parts: 2)
        |> hd()
        |> String.trim()
        |> then(fn v -> if v == "", do: nil, else: v end)

      _ ->
        nil
    end
  end

  defp normalize_base(nil), do: nil
  defp normalize_base(""), do: nil

  defp normalize_base(url) when is_binary(url) do
    url = url |> String.trim() |> String.trim_trailing("/")
    if url == "", do: nil, else: url
  end

  defp to_a2a(hit) do
    file = hit.card || %{}

    %{
      name: file["name"] || hit.id,
      description: file["description"] || "Mazel agent. Talk through me. HAAH on A2A.",
      version: "0.1.0",
      protocol: "haah",
      protocolVersion: "0.1",
      url: "/a2a",
      handle: hit.id,
      card_url: hit.card_url,
      source: to_string(hit.source),
      product: file["product"] || "mazel",
      capabilities: %{streaming: false, pushNotifications: false},
      defaultInputModes: ["text/plain", "application/json"],
      defaultOutputModes: ["application/json"],
      skills: Enum.map(skill_ids(file), &skill/1),
      bindings: [%{protocolBinding: "JSONRPC", protocolVersion: "0.2", url: "/a2a"}]
    }
  end

  defp skill_ids(%{"skills" => skills}) when is_list(skills) and skills != [] do
    skills |> Enum.map(&to_string/1) |> Enum.reject(&(&1 == ""))
  end

  defp skill_ids(_), do: @card_skills

  defp skill(id) when is_binary(id), do: %{id: id, name: Room.Labels.get(id), tags: ["haah"]}
  defp skill(_), do: %{id: "chat", name: Room.Labels.get(:chat), tags: ["haah"]}

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

  defp rpc_id(%{"jsonrpc" => _, "id" => id}), do: id
  defp rpc_id(_), do: nil

  defp maybe_rpc(envelope, nil), do: envelope

  defp maybe_rpc(envelope, id) do
    %{jsonrpc: "2.0", id: id, result: envelope}
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value) when is_binary(value), do: String.trim(value)
  defp blank_to_nil(_), do: nil

  defp random_id do
    :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
  end
end
