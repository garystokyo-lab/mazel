defmodule Room.ResolveCard do
  @moduledoc """
  One strip: zone TXT then well-known HAAH card, then mazel'd.

  Ghost is no_txt. Distinct from resolve_live / resolve_harden /
  card_well_known standalones. No morph.
  """

  def look_txt(rec \\ %{}) do
    qname = rec[:qname] || "kai.mazel.ai"
    haah = if rec[:haah] == false, do: "0", else: "1"
    "ok  txt=#{qname}  haah=#{haah}"
  end

  def look_card(rec \\ %{}) do
    proto = rec[:protocol] || rec["protocol"] || "haah"
    "ok  well-known=/.well-known/agent-card.json  protocol=#{proto}"
  end

  def look_chat, do: "ok  #{Room.Find.mazel_d("kai@mazel")}"

  def look_ghost, do: "error  txt=ghost.mazel.ai  error=no_txt"

  def look(pack) when is_map(pack) do
    [look_txt(pack.txt), look_card(pack.card), look_chat(), look_ghost()]
  end

  def look(_), do: look(%{txt: %{}, card: %{}})

  @doc """
  TXT resolve then well-known card, then in-agent mazel'd.
  Isolated room. Sibling resolve / well-known LOOK stays.
  """
  def demo(opts \\ []) do
    id = Keyword.get(opts, :context_id) || "resolve-card-" <> random_id()

    with {:ok, zone} <- Room.Dns.load(),
         {:ok, txt} <- Room.ResolveHarden.gate("@kai", zone),
         {200, body} <- Room.CardWellKnown.fetch("@kai"),
         {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
         {:ok, session} <-
           Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}]),
         {:error, :no_txt} <- Room.ResolveHarden.gate("@ghost", zone) do
      events = Enum.map(session.events || [], & &1.type)

      cond do
        txt.source != :txt or txt.qname != "kai.mazel.ai" or txt.haah != true ->
          {:error, :txt_miss}

        body["protocol"] != "haah" or body["handle"] != "kai@mazel" ->
          {:error, :card_miss}

        session.status != :open or session.session_kind != :direct ->
          {:error, :session_miss}

        session.badge != nil or "morph.commit" in events ->
          {:error, :morphed}

        humans_awake?(session) ->
          {:error, :human_woke}

        true ->
          card = %{protocol: body["protocol"], handle: body["handle"]}
          pack = %{txt: txt, card: card, session: session}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end