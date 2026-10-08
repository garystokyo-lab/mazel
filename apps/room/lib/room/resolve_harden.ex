defmodule Room.ResolveHarden do
  @moduledoc """
  Fail-closed TXT resolve. Missing TXT and TXT without
  `mazel-card=` never mint a handle.

  Distinct from resolve_live (happy-path card + mazel'd).
  No live DNS. No messenger.
  """

  def look_ok(rec \\ %{}) do
    qname = rec[:qname] || "kai.mazel.ai"
    haah = if rec[:haah] == false, do: "0", else: "1"
    "ok  resolve=#{qname}  haah=#{haah}"
  end

  def look_none, do: "error  resolve=ghost.mazel.ai  error=no_txt"

  def look_plain, do: "error  resolve=plain.mazel.ai  error=no_card"

  def look(pack) when is_map(pack) do
    [look_ok(pack.ok), look_none(), look_plain()]
  end

  def look(_), do: look(%{ok: %{}})

  @doc """
  Gate a handle against a zone. Distinguishes no TXT vs TXT
  with no `mazel-card=`. Does not rewrite Dns.lookup errors.
  """
  def gate(raw, zone) do
    case Room.Dns.txt_for(raw, zone) do
      {:error, :unknown_handle} ->
        {:error, :no_txt}

      {:error, _} = err ->
        err

      {:ok, record} ->
        attrs = Room.Dns.parse_txt(record.data)

        cond do
          attrs.card_urls == [] ->
            {:error, :no_card}

          true ->
            Room.Dns.lookup(raw, zone)
        end
    end
  end

  def zone_text do
    """
    $ORIGIN mazel.ai.
    $TTL 300
    kai     300  IN  TXT  "mazel-card=https://mazel.ai/cards/kai mazel-haah=1"
    plain   300  IN  TXT  "not-a-card"
    """
  end

  @doc """
  Good TXT holds. Ghost is no_txt. Plain TXT is no_card.
  Isolated zone text. resolve_live LOOK stays.
  """
  def demo(_opts \\ []) do
    with {:ok, zone} <- Room.Dns.parse(zone_text()),
         {:ok, ok} <- gate("@kai", zone),
         {:error, :no_txt} <- gate("@ghost", zone),
         {:error, :no_card} <- gate("@plain", zone) do
      cond do
        ok.source != :txt or ok.qname != "kai.mazel.ai" or ok.haah != true ->
          {:error, :kai_miss}

        ok.card_url == nil ->
          {:error, :card_miss}

        true ->
          pack = %{ok: ok, none: :no_txt, plain: :no_card, zone: zone}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end
end
