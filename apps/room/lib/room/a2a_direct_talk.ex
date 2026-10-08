defmodule Room.A2aDirectTalk do
  @moduledoc """
  Resolve kai, Direct-open, then one JSON-RPC talk turn.

  message/send on the Direct path. session=agent, morph=none.
  Distinct from a2a_two_handle_direct (resolve+open only),
  a2a_task (task=send; no Direct session), and
  match_chat / session talk (no A2A card resolve).
  Off Group / skills-shape / mint / wiki / Trust.
  """

  def look_resolve(rec \\ %{}), do: Room.A2aTask.look_resolve(rec)
  def look_direct, do: Room.A2aTwoHandleDirect.look_direct()
  def look_talk, do: "ok  talk=send  status=ok"

  def look(pack) when is_map(pack) do
    [look_resolve(pack.hit), look_direct(), look_talk()]
  end

  def look(_), do: look(%{hit: %{handle: "kai@mazel", card_url: Room.A2aCard.card_url("kai@mazel")}})

  @doc """
  Resolve kai card URL. Direct open. JSON-RPC talk ok.
  Isolated. Sibling two-handle / task / session talk stay.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-direct-a2a-talk-" <> random_id()
    demo_on(prefix)
  end

  defp demo_on(prefix) do
    with {:ok, hit} <- Room.A2aResolve.resolve("@kai"),
         {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, peer} <- Room.Cards.lookup(hit.handle),
         {:ok, opened} <-
           Room.open(prefix, :direct, [
             %{handle: ariel, role: :agent},
             %{handle: peer, role: :agent}
           ]),
         {:ok, sent} <- Room.A2aTask.send(hit) do
      events = Enum.map(opened.events || [], & &1.type)

      cond do
        hit.handle != "kai@mazel" or hit.card_url != Room.A2aCard.card_url("kai@mazel") ->
          {:error, :resolve_miss}

        opened.session_kind != :direct ->
          {:error, :not_direct}

        opened.badge != nil or "morph.commit" in events ->
          {:error, :morphed}

        opened.status != :open ->
          {:error, :session_miss}

        sent.status != :ok or sent.method != "message/send" ->
          {:error, :talk_miss}

        sent.card_url != hit.card_url ->
          {:error, :talk_miss}

        humans_awake?(opened) ->
          {:error, :human_woke}

        minted?(opened) ->
          {:error, :minted}

        true ->
          pack = %{
            hit: hit,
            peer: peer,
            session: opened,
            sent: sent,
            open_id: Room.SessionContext.id(opened)
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp minted?(session) do
    events = Enum.map(session.events || [], & &1.type)
    session.badge != nil or "morph.commit" in events or "morph.rejoin" in events
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
