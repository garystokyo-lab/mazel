defmodule Room.A2aResolveDns do
  @moduledoc """
  A2A resolve via DNS TXT, then Agent Card URL.

  Fixture zone. No live DNS. Distinct from a2a_resolve
  (well-known compose) and resolve_live (HAAH / mazel'd).
  Off Match / wiki / mint.
  """

  def look_resolve(rec \\ %{}) do
    handle = rec[:handle] || rec[:resolve] || "kai@mazel"
    via = rec[:via] || "dns_txt"
    "ok  a2a  resolve=#{handle}  via=#{via}"
  end

  def look_url(rec \\ %{}) do
    url = rec[:card_url] || Room.A2aCard.card_url("kai@mazel")
    "ok  card_url=#{url}"
  end

  def look_ghost, do: "error  resolve=@ghost  error=no_txt"

  def look(pack \\ %{}) do
    hit = pack[:hit] || %{}
    [look_resolve(hit), look_url(hit), look_ghost()]
  end

  @doc "TXT gate then A2A card URL. Ghost is no_txt."
  def resolve(handle, opts \\ []) do
    with {:ok, zone} <- zone(Keyword.get(opts, :zone)),
         {:ok, txt} <- Room.ResolveHarden.gate(handle, zone),
         {:ok, hit} <- Room.A2aCard.resolve(txt.handle) do
      {:ok,
       Map.merge(hit, %{
         via: "dns_txt",
         resolve: hit.handle,
         qname: txt.qname,
         source: :txt
       })}
    end
  end

  @doc """
  Fixture TXT for kai → A2A card URL. Ghost is no_txt.
  Isolated. Sibling well-known / HAAH LOOK stays.
  """
  def demo(opts \\ []) do
    with {:ok, hit} <- resolve("@kai", opts),
         {:error, :no_txt} <- resolve("@ghost", opts) do
      cond do
        hit.handle != "kai@mazel" or hit.resolve != "kai@mazel" ->
          {:error, :handle_miss}

        hit.via != "dns_txt" or hit.source != :txt ->
          {:error, :via_miss}

        hit.card_url != Room.A2aCard.card_url("kai@mazel") ->
          {:error, :url_miss}

        hit.path != Room.A2aCard.path() ->
          {:error, :path_miss}

        hit.card["ok"] != true ->
          {:error, :card_miss}

        true ->
          pack = %{hit: hit, ghost: :no_txt}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp zone(nil) do
    Room.Dns.load()
  end

  defp zone(zone) when is_map(zone), do: {:ok, zone}
  defp zone(_), do: Room.Dns.load()
end
