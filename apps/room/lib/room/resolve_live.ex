defmodule Room.ResolveLive do
  @moduledoc """
  Live resolver path: registrar TXT → card → mazel'd.

  Zone fixture is the live answer until iwantmyname (or any
  registrar) publishes the same TXT. No network.
  """

  @handle "@kai"

  def handle, do: @handle

  @doc "TXT from the zone, as if the registrar already answered."
  def from_txt(raw \\ @handle) do
    Room.Dns.lookup(raw)
  end

  def look(%{handle: handle, card_url: url, qname: qname, haah: haah} = rec) do
    haah_flag = if haah, do: "1", else: "0"
    chat = rec[:mazel_d] || Room.Find.mazel_d(handle)

    [
      "ok  txt=#{qname}  mazel-card=#{url}  haah=#{haah_flag}",
      "ok  card=#{url}",
      "ok  #{chat}"
    ]
  end

  def look(_), do: ["ok  txt=  mazel-card=  haah=0"]

  @doc """
  iwantmyname-style paste. Host = handle local, type = TXT.
  Same bytes as `fixtures/dns/mazel.ai.zone`.
  """
  def registrar_paste(local \\ "kai") do
    url = "https://mazel.ai/cards/#{local}"
    "host=#{local}  type=TXT  value=mazel-card=#{url} mazel-haah=1"
  end

  def demo(opts \\ []) do
    raw = Keyword.get(opts, :handle, @handle)

    with {:ok, txt} <- from_txt(raw),
         {:ok, chat} <- Room.Tools.wing(Room.Find.wing_at(txt.handle)) do
      cond do
        txt.source != :txt ->
          {:error, :not_txt}

        txt.card_url == nil or txt.haah != true ->
          {:error, :bad_txt}

        not (chat.ok and chat.handle == txt.handle and chat.kind == :direct) ->
          {:error, :not_mazel_d}

        true ->
          rec = Map.merge(txt, %{mazel_d: Room.Find.mazel_d(txt.handle), chat: chat})
          {:ok, %{txt: rec, chat: chat, lines: look(rec), paste: registrar_paste()}}
      end
    end
  end
end
