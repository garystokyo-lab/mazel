defmodule Room.A2aPeerCard do
  @moduledoc """
  Durable Agent Card for any real handle.

  First-class Need×Have. Protocol haah. URL is
  the card's own url — not `{local}.mazel.ai`.
  Founder origin `https://a2a.mazel.ai` is
  allowlisted. Theater hosts (mazel.ai/cards,
  GitHub-raw, loopback) stay refused. Not a
  kai/buddy product path. Off mix remint /
  LOOK catalog / Group / Trust / Install.
  """

  @well_known "/.well-known/agent-card.json"
  @founder_host "a2a.mazel.ai"
  @founder_origin "https://a2a.mazel.ai"

  def well_known_path, do: @well_known
  def path, do: @well_known
  def founder_host, do: @founder_host
  def founder_origin, do: @founder_origin
  def founder_well_known, do: @founder_origin <> @well_known

  @doc "Normalize need/have to a tag list."
  def tags(nil), do: []
  def tags(""), do: []

  def tags(value) when is_binary(value) do
    value |> String.trim() |> List.wrap() |> Enum.reject(&(&1 == ""))
  end

  def tags(values) when is_list(values) do
    values
    |> Enum.flat_map(&tags/1)
  end

  def tags(_), do: :bad

  def need(card) when is_map(card), do: tags(card["need"] || card[:need])
  def need(_), do: []

  def have(card) when is_map(card), do: tags(card["have"] || card[:have])
  def have(_), do: []

  def invented_host?(url) when is_binary(url) do
    down = url |> String.trim() |> String.downcase()
    uri = URI.parse(down)
    host = uri.host || ""

    cond do
      founder?(uri) ->
        false

      String.contains?(down, "raw.githubusercontent") ->
        true

      loopback?(down, host) ->
        true

      host == "mazel.ai" ->
        true

      String.ends_with?(host, ".mazel.ai") ->
        true

      String.contains?(host, "mazel.ai") or String.contains?(down, "mazel.ai") ->
        true

      true ->
        false
    end
  end

  def invented_host?(_), do: true

  defp founder?(%URI{scheme: "https", host: @founder_host}), do: true
  defp founder?(_), do: false

  defp loopback?(down, host) do
    host in ["127.0.0.1", "localhost"] or
      String.contains?(down, "127.0.0.1") or
      String.contains?(down, "localhost")
  end

  @doc """
  Product card shape. handle + url + protocol=haah.
  need / have optional, first-class when present.
  """
  def validate(card) when is_map(card) do
    handle = card["handle"] || card[:handle]
    url = card["url"] || card[:url] || card["card_url"] || card[:card_url]
    protocol = card["protocol"] || card[:protocol]
    need = tags(card["need"] || card[:need])
    have = tags(card["have"] || card[:have])

    cond do
      not usable?(handle) ->
        {:error, :missing_handle}

      not usable?(url) ->
        {:error, :missing_url}

      protocol != "haah" ->
        {:error, :bad_protocol}

      need == :bad ->
        {:error, :bad_need}

      have == :bad ->
        {:error, :bad_have}

      invented_host?(url) ->
        {:error, :invented_host}

      true ->
        :ok
    end
  end

  def validate(_), do: {:error, :not_a_map}

  @doc "Normalize a pasted or file card. Does not fetch."
  def from_map(card) when is_map(card) do
    case validate(card) do
      :ok ->
        handle = card["handle"] || card[:handle]
        url = card["url"] || card[:url] || card["card_url"] || card[:card_url]
        string_card = stringify(card)

        {:ok,
         %{
           handle: handle,
           url: url,
           rpc: rpc_or_nil(string_card),
           protocol: "haah",
           need: need(string_card),
           have: have(string_card),
           path: @well_known,
           card: string_card
         }}

      error ->
        error
    end
  end

  def from_map(_), do: {:error, :not_a_map}

  @doc """
  This process's JSON-RPC talk origin.

  `MAZEL_A2A_RPC` — this Room `/a2a`, not the
  Pages card host and not another agent's rpc.
  Used to resolve a relative `/a2a` on a card.
  Not public_host.
  """
  def agent_rpc do
    case System.get_env("MAZEL_A2A_RPC") do
      nil ->
        :none

      raw ->
        raw = String.trim(raw)
        if raw == "", do: :none, else: normalize_rpc(raw)
    end
  end

  @doc """
  Real-handle card whose JSON-RPC interface
  points at agent-origin `/a2a`, not the card
  document and not Pages.
  """
  def talk_card(handle, opts \\ []) when is_binary(handle) do
    rpc =
      case Keyword.get(opts, :rpc, :default) do
        :default ->
          case agent_rpc() do
            :none -> nil
            url -> url
          end

        url ->
          url
      end

    local =
      handle
      |> String.trim()
      |> String.trim_leading("@")
      |> String.split("@")
      |> hd()

    card_url = Keyword.get(opts, :url) || "https://peer.example/cards/#{local}"

    card = %{
      "handle" => handle,
      "url" => card_url,
      "protocol" => "haah",
      "need" => tags(Keyword.get(opts, :need, [])),
      "have" => tags(Keyword.get(opts, :have, ["direct", "chat"]))
    }

    if usable?(rpc) do
      Map.merge(card, %{
        "rpc" => rpc,
        "supportedInterfaces" => [%{"protocolBinding" => "JSONRPC", "url" => rpc}]
      })
    else
      Map.put(card, "supportedInterfaces", [])
    end
  end

  @doc """
  This agent's runtime JSON-RPC url, or :rpc_none.

  Reads `rpc` / `rpc_url`, then JSON-RPC
  interface rows. The card document url is
  never an endpoint. Pages `a2a.mazel.ai` is
  card CDN only — no Mazel-middle RPC.
  Theater mazel.ai / GitHub-raw refused.
  A declared loopback url is that agent's
  own runtime, not public_host.
  """
  def rpc_endpoint(card) when is_map(card) do
    card = stringify(card)
    card_url = card["url"] || card["card_url"]

    (explicit_rpc_urls(card) ++ interface_rpc_urls(card))
    |> Enum.find_value({:error, :rpc_none}, &pick_rpc(&1, card_url))
  end

  def rpc_endpoint(_), do: {:error, :rpc_none}

  defp rpc_or_nil(card) do
    case rpc_endpoint(card) do
      {:ok, url} -> url
      _ -> nil
    end
  end

  defp explicit_rpc_urls(card) do
    [card["rpc"], card["rpc_url"]]
  end

  defp interface_rpc_urls(card) do
    rows =
      List.wrap(card["bindings"]) ++
        List.wrap(card["additionalInterfaces"]) ++
        List.wrap(card["supportedInterfaces"])

    Enum.flat_map(rows, fn row ->
      row = if is_map(row), do: stringify(row), else: %{}
      binding = row["protocolBinding"] || row["transport"]
      url = row["url"]
      if jsonrpc?(binding) and usable?(url), do: [url], else: []
    end)
  end

  defp pick_rpc(url, card_url) do
    cond do
      not usable?(url) ->
        nil

      true ->
        url = absolute_rpc(url)

        cond do
          founder_rpc?(url) ->
            nil

          url == card_url ->
            nil

          not absolute_http?(url) ->
            nil

          invented_rpc?(url) ->
            nil

          true ->
            {:ok, url}
        end
    end
  end

  defp invented_rpc?(url) when is_binary(url) do
    down = url |> String.trim() |> String.downcase()
    uri = URI.parse(down)
    host = uri.host || ""

    cond do
      founder?(uri) ->
        true

      String.contains?(down, "raw.githubusercontent") ->
        true

      host == "mazel.ai" ->
        true

      String.ends_with?(host, ".mazel.ai") ->
        true

      String.contains?(host, "mazel.ai") ->
        true

      true ->
        false
    end
  end

  defp invented_rpc?(_), do: true

  defp jsonrpc?(binding) when is_binary(binding) do
    binding in ["JSONRPC", "JSON-RPC", "jsonrpc"]
  end

  defp jsonrpc?(_), do: false

  defp founder_rpc?(url) when is_binary(url) do
    uri = url |> String.trim() |> String.downcase() |> URI.parse()
    uri.host == @founder_host
  end

  defp founder_rpc?(_), do: false

  defp absolute_rpc(url) when is_binary(url) do
    trimmed = String.trim(url)

    cond do
      absolute_http?(trimmed) ->
        trimmed

      String.starts_with?(trimmed, "/") ->
        case agent_rpc() do
          :none ->
            trimmed

          configured ->
            if trimmed == "/a2a", do: configured, else: rpc_origin(configured) <> trimmed
        end

      true ->
        trimmed
    end
  end

  defp absolute_http?(url) when is_binary(url) do
    String.starts_with?(url, "http://") or String.starts_with?(url, "https://")
  end

  defp absolute_http?(_), do: false

  defp normalize_rpc(url) when is_binary(url) do
    url = url |> String.trim() |> String.trim_trailing("/")
    if String.ends_with?(url, "/a2a"), do: url, else: url <> "/a2a"
  end

  defp rpc_origin(url) do
    url = normalize_rpc(url)

    if String.ends_with?(url, "/a2a") do
      String.trim_trailing(String.replace_suffix(url, "/a2a", ""), "/")
    else
      String.trim_trailing(url, "/")
    end
  end

  defp stringify(card) do
    card
    |> Enum.map(fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
    |> Map.new()
  end

  defp usable?(value) when is_binary(value), do: String.trim(value) != ""
  defp usable?(_), do: false
end
