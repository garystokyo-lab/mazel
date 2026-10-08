defmodule Room.CardWellKnown do
  @moduledoc """
  HAAH Agent Card via `/.well-known/agent-card.json`.

  Fetch the card, then mazel'd in-agent. Ghost is unknown_handle.
  Distinct from resolve_live / resolve_harden (TXT). No morph.
  """

  @path "/.well-known/agent-card.json"

  def path, do: @path

  def look_card(rec \\ %{}) do
    proto = rec[:protocol] || rec["protocol"] || "haah"
    "ok  well-known=#{@path}  protocol=#{proto}"
  end

  def look_handle(rec \\ %{}) do
    handle = rec[:handle] || rec["handle"] || "kai@mazel"
    haah = if rec[:haah] == false or rec["haah"] == false, do: "0", else: "1"
    "ok  handle=#{handle}  haah=#{haah}"
  end

  def look_chat, do: "ok  #{Room.Find.mazel_d("kai@mazel")}"

  def look_ghost, do: "error  well-known=@ghost  error=unknown_handle"

  def look(pack) when is_map(pack) do
    [look_card(pack.card), look_handle(pack.card), look_chat(), look_ghost()]
  end

  def look(_), do: look(%{card: %{}})

  @doc "In-process GET of the well-known HAAH card. No live bind."
  def fetch(handle) do
    qs = if is_binary(handle) and handle != "", do: "?handle=#{handle}", else: ""
    conn = Plug.Test.conn(:get, @path <> qs) |> Room.Http.call(Room.Http.init([]))
    body = Jason.decode!(conn.resp_body)
    {conn.status, body}
  end

  @doc """
  Well-known kai card is HAAH, then mazel'd. Ghost 404.
  Isolated room. resolve_live / resolve_harden LOOK stays.
  """
  def demo(opts \\ []) do
    id = Keyword.get(opts, :context_id) || "card-wk-" <> random_id()

    with {200, body} <- fetch("@kai"),
         {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
         {:ok, session} <-
           Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}]),
         {404, ghost} <- fetch("@ghost") do
      events = Enum.map(session.events || [], & &1.type)

      cond do
        body["protocol"] != "haah" or body["handle"] != "kai@mazel" ->
          {:error, :card_miss}

        ghost["error"] != "unknown_handle" ->
          {:error, :ghost_leaked}

        session.status != :open or session.session_kind != :direct ->
          {:error, :session_miss}

        session.badge != nil or "morph.commit" in events ->
          {:error, :morphed}

        humans_awake?(session) ->
          {:error, :human_woke}

        true ->
          card = %{
            protocol: body["protocol"],
            handle: body["handle"],
            haah: true,
            path: @path
          }

          pack = %{card: card, ghost: ghost, session: session}
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
