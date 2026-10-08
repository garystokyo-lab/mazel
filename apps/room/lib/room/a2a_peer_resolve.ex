defmodule Room.A2aPeerResolve do
  @moduledoc """
  Durable A2A resolve primitives.

  Compose well-known from a supplied host, or
  resolve from a peer card / DNS TXT. Founder
  origin `https://a2a.mazel.ai` is allowlisted.
  Theater mazel.ai / GitHub-raw / loopback stay
  refused. Does not default to @kai / @buddy.
  Off mix remint / LOOK catalog / Group /
  Trust / Install.
  """

  alias Room.A2aPeerCard, as: PeerCard
  alias Room.InstallAddMazelFriendPublicHostReady, as: HostReady

  def path, do: PeerCard.well_known_path()

  @doc "A2A founder origin probe. Install skill probe stays separate."
  def probe_host, do: HostReady.probe_host(:a2a)

  @doc """
  well-known URL from a real host. :none / blank
  is host_none. Invented hosts refused. Bare
  founder host `a2a.mazel.ai` composes https.
  """
  def compose(host) do
    cond do
      host in [nil, :none, ""] ->
        {:error, :host_none}

      host in [:founder, :a2a] ->
        compose(PeerCard.founder_origin())

      host == PeerCard.founder_host() ->
        compose(PeerCard.founder_origin())

      not is_binary(host) ->
        {:error, :host_none}

      PeerCard.invented_host?(host) ->
        {:error, :invented_host}

      true ->
        base = String.trim_trailing(host, "/")
        {:ok, base <> path()}
    end
  end

  @doc "GET well-known on the wire. Hostish first arg fetches that origin."
  def from_well_known(raw) when is_binary(raw) do
    if hostish?(raw) do
      fetch_well_known(raw)
    else
      from_well_known(raw, PeerCard.founder_origin())
    end
  end

  def from_well_known(_handle, host) when host in [nil, :none, ""] do
    {:error, :host_none}
  end

  def from_well_known(handle, host) do
    with {:ok, hit} <- fetch_well_known(host),
         {:ok, parsed} <- Room.Wings.parse_handle(handle) do
      if hit.handle == parsed.id do
        {:ok, hit}
      else
        {:error, :handle_miss}
      end
    end
  end

  @doc "Compose + GET + parse into A2aPeerCard. No in-process fixture."
  def fetch_well_known(host) do
    with {:ok, card_url} <- compose(host),
         {:ok, body} <- http_get(card_url),
         {:ok, map} <- decode_card(body),
         {:ok, peer} <- PeerCard.from_map(map) do
      {:ok,
       hit(peer.handle, peer.url, "well-known", %{
         source: :well_known,
         need: peer.need,
         have: peer.have,
         card: peer.card,
         peer: peer,
         rpc: peer.rpc
       })}
    end
  end

  @doc "Resolve from a pasted / file Agent Card. URL is the card's."
  def from_card(card) do
    with {:ok, peer} <- PeerCard.from_map(card) do
      {:ok,
       hit(peer.handle, peer.url, "card", %{
         source: :card,
         need: peer.need,
         have: peer.have,
         card: peer.card,
         rpc: peer.rpc
       })}
    end
  end

  @doc "TXT `mazel-card=` URL. Fixture zone optional. No live DNS."
  def from_txt(handle, opts \\ []) do
    with {:ok, zone} <- zone(Keyword.get(opts, :zone)),
         {:ok, txt} <- Room.ResolveHarden.gate(handle, zone) do
      url = txt[:card_url] || txt[:url]

      cond do
        not is_binary(url) or String.trim(url) == "" ->
          {:error, :no_card}

        PeerCard.invented_host?(url) ->
          {:error, :invented_host}

        true ->
          id = txt[:id] || txt[:handle] || handle

          {:ok,
           hit(id, url, "dns_txt", %{
             source: :txt,
             need: [],
             have: [],
             card: nil,
             qname: txt[:qname],
             haah: txt[:haah] == true
           })}
      end
    end
  end

  defp hit(handle, card_url, via, extra) do
    probed = probe_host()

    Map.merge(
      %{
        handle: handle,
        resolve: handle,
        card_url: card_url,
        via: via,
        path: path(),
        public_host: probed.public_host,
        live_host_ready: probed.live_host_ready
      },
      extra
    )
  end

  defp zone(nil), do: Room.Dns.load()
  defp zone(zone) when is_map(zone), do: {:ok, zone}
  defp zone(_), do: Room.Dns.load()

  defp hostish?(raw) do
    raw == PeerCard.founder_host() or
      raw == PeerCard.founder_origin() or
      String.starts_with?(raw, "https://")
  end

  defp decode_card(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, map} when is_map(map) -> {:ok, map}
      {:ok, _} -> {:error, :bad_json}
      {:error, _} -> {:error, :bad_json}
    end
  end

  defp decode_card(_), do: {:error, :bad_json}

  defp http_get(url) do
    args = [
      "-fsS",
      "-L",
      "--max-time",
      "8",
      "--connect-timeout",
      "5",
      "-H",
      "accept: application/json",
      "-A",
      "mazel-a2a/0.1",
      url
    ]

    case System.cmd("curl", args, stderr_to_stdout: true) do
      {body, 0} when is_binary(body) and body != "" ->
        {:ok, body}

      {_out, _} ->
        {:error, :card_offline}
    end
  end
end
