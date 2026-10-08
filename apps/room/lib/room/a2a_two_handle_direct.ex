defmodule Room.A2aTwoHandleDirect do
  @moduledoc """
  Resolve two handles to card URLs, then Direct the mazel'd one.

  kai@mazel + nova@mazel via well-known card URLs. Find
  series-a → kai. Direct opens session=agent, morph=none.
  Distinct from a2a_resolve (one handle + ghost), a2a_task
  (single handle task send), session_direct_id (no dual
  card resolve), and session_direct_after_find (Add→paste;
  no A2A). Direct 1-on-1 only. Off Group / ghost farm /
  mint / wiki / Trust.
  """

  def look_resolve(rec \\ %{}), do: Room.A2aTask.look_resolve(rec)
  def look_mazel_d(rec \\ %{}) do
    peer = rec[:handle] || rec[:peer] || "kai@mazel"
    "ok  #{Room.Find.mazel_d(peer)}"
  end
  def look_direct, do: "ok  direct=@kai  session=agent  morph=none"

  def look(pack) when is_map(pack) do
    [look_resolve(pack.kai), look_resolve(pack.nova), look_mazel_d(pack.hit), look_direct()]
  end

  def look(_) do
    look(%{
      kai: %{handle: "kai@mazel", card_url: Room.A2aCard.card_url("kai@mazel")},
      nova: %{handle: "nova@mazel", card_url: Room.A2aCard.card_url("nova@mazel")},
      hit: %{}
    })
  end

  @doc """
  Resolve kai + nova card URLs. Find kai. Direct open.
  Morph none. Isolated. Sibling resolve / task / direct
  LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-direct-" <> random_id()
    demo_on(prefix)
  end

  defp demo_on(prefix) do
    with {:ok, kai} <- Room.A2aResolve.resolve("@kai"),
         {:ok, nova} <- Room.A2aResolve.resolve("@nova"),
         {:ok, find} <- Room.Find.query("series-a"),
         handle when is_binary(handle) <- find_handle(find),
         {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, peer} <- Room.Cards.lookup(handle),
         {:ok, opened} <-
           Room.open(prefix, :direct, [
             %{handle: ariel, role: :agent},
             %{handle: peer, role: :agent}
           ]) do
      events = Enum.map(opened.events || [], & &1.type)

      cond do
        kai.handle != "kai@mazel" or kai.card_url != Room.A2aCard.card_url("kai@mazel") ->
          {:error, :kai_miss}

        nova.handle != "nova@mazel" or nova.card_url != Room.A2aCard.card_url("nova@mazel") ->
          {:error, :nova_miss}

        handle != "kai@mazel" ->
          {:error, :find_miss}

        opened.session_kind != :direct ->
          {:error, :not_direct}

        opened.badge != nil or "morph.commit" in events ->
          {:error, :morphed}

        opened.status != :open ->
          {:error, :session_miss}

        humans_awake?(opened) ->
          {:error, :human_woke}

        minted?(opened) ->
          {:error, :minted}

        true ->
          hit = %{handle: handle, query: "series-a"}

          pack = %{
            kai: kai,
            nova: nova,
            find: find,
            hit: hit,
            peer: peer,
            session: opened,
            open_id: Room.SessionContext.id(opened),
            denied: :none
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp find_handle(%{ok: true, hits: [%{handle: handle} | _]}) when is_binary(handle), do: handle
  defp find_handle(_), do: nil

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
