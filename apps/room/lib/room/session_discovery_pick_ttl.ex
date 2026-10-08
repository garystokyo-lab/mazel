defmodule Room.SessionDiscoveryPickTtl do
  @moduledoc """
  Discovery-pick Direct, TTL expire mid-talk, fresh
  pick opens a new id.

  pick kai → Direct id-a + talk. Expire denies talk
  on that id. Fresh pick kai opens id-b (same=false).
  Distinct from session_discovery_pick_leave (leave /
  rejoin same id, no TTL) and session_ttl_mid (TTL mid
  on match/open, not discovery pick). Off mint / Match /
  wiki / Consent / A2A.
  """

  def look_discovery(handles \\ ["kai@mazel", "nova@mazel"]) do
    Room.SessionDiscoveryPick.look_discovery(handles)
  end

  def look_pick(id, handle \\ "kai@mazel") do
    Room.SessionDiscoveryPick.look_pick(id, handle)
  end

  def look_talk, do: Room.MatchChat.look_talk(%{local: "kai"}, 1)

  def look_ttl, do: Room.SessionTtlPresence.look_ttl()

  def look_denied(id), do: Room.SessionTtlTalkIds.look_denied(id)

  def look_fresh_pick(id, handle \\ "kai@mazel") do
    "ok  pick=#{handle}  direct=open  id=#{id}  same=false"
  end

  def look_fresh_talk(id), do: Room.SessionTtlTalkIds.look_talk(id)

  def look(pack) when is_map(pack) do
    [
      look_discovery(pack[:handles]),
      look_pick(pack[:open_id], pack[:picked]),
      look_talk(),
      look_ttl(),
      look_denied(pack[:open_id]),
      look_fresh_pick(pack[:fresh_id], pack[:picked]),
      look_fresh_talk(pack[:fresh_id])
    ]
  end

  def look(_),
    do:
      look(%{
        handles: ["kai@mazel", "nova@mazel"],
        picked: "kai@mazel",
        open_id: "session-direct-a",
        fresh_id: "session-direct-b"
      })

  @doc """
  Discovery pick kai → talk, expire, fresh pick new id.
  Isolated. Sibling pick_leave / ttl_mid LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-direct-" <> random_id()
    want = Keyword.get(opts, :pick) || "kai@mazel"
    now = Keyword.get(opts, :now) || DateTime.utc_now()
    open_id = prefix <> "-a"
    fresh_id = prefix <> "-b"

    need = Room.SelfReportMatch.parse(Keyword.get(opts, :need) || "need: series-a")
    has_kai = Room.SelfReportMatch.report(:has, "series-a", handle: "kai@mazel")
    has_nova = Room.SelfReportMatch.report(:has, "series-a", handle: "nova@mazel")
    hits = Room.SelfReportMatch.match_all([has_kai, has_nova], need)
    found = Room.SessionDiscovery.handles(hits)
    picked = Room.SessionDiscovery.pick(found, want)

    with picked when is_binary(picked) <- picked,
         {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, peer} <- Room.Cards.lookup(picked),
         {:ok, opened} <-
           Room.open(open_id, :direct, [
             %{handle: ariel, role: :agent},
             %{handle: peer, role: :agent}
           ]),
         {:ok, stamped} <- Room.SessionTtl.stamp(open_id, :fresh, now),
         {:ok, talked} <- Room.talk(open_id, peer, "hello"),
         {:ok, dead} <- Room.SessionTtl.expire(open_id, now),
         {:error, :ttl_expired} <- Room.talk(open_id, peer, "hello"),
         picked_again when is_binary(picked_again) <- Room.SessionDiscovery.pick(found, want),
         {:ok, _fresh_open} <-
           Room.open(fresh_id, :direct, [
             %{handle: ariel, role: :agent},
             %{handle: peer, role: :agent}
           ]),
         {:ok, fresh_stamped} <- Room.SessionTtl.stamp(fresh_id, :fresh, now),
         {:ok, fresh} <- Room.talk(fresh_id, peer, "hello") do
      cond do
        not Room.Need.discovery_sink?("need@mazel") ->
          {:error, :sink_miss}

        found != ["kai@mazel", "nova@mazel"] ->
          {:error, :handle_miss}

        picked != "kai@mazel" or picked_again != "kai@mazel" ->
          {:error, :pick_miss}

        opened.session_kind != :direct or fresh.session_kind != :direct ->
          {:error, :not_direct}

        Room.SessionContext.id(opened) != open_id or Room.SessionContext.id(talked) != open_id ->
          {:error, :open_id_miss}

        Room.SessionContext.id(fresh) != fresh_id ->
          {:error, :fresh_id_miss}

        Room.SessionContext.same?(opened, fresh) or open_id == fresh_id ->
          {:error, :id_reuse}

        Room.SessionTtl.turn(talked) != 1 or Room.SessionTtl.freshness(stamped, now) != :fresh ->
          {:error, :open_miss}

        Room.SessionTtl.freshness(dead, now) != :expired or Room.SessionTtl.turn(dead) != 1 ->
          {:error, :expire_miss}

        Room.SessionTtl.turn(fresh) != 1 or Room.SessionTtl.freshness(fresh_stamped, now) != :fresh ->
          {:error, :fresh_miss}

        look_fresh_pick(fresh_id, picked) == look_pick(open_id, picked) ->
          {:error, :look_same}

        look_ttl() == Room.SessionTtl.look_denied() ->
          {:error, :look_same}

        minted?(talked) or minted?(fresh) ->
          {:error, :minted}

        talked.status != :open or dead.status != :open or fresh.status != :open ->
          {:error, :closed}

        humans_awake?(talked) or humans_awake?(fresh) ->
          {:error, :human_woke}

        true ->
          pack = %{
            handles: found,
            picked: picked,
            hits: hits,
            open_id: open_id,
            fresh_id: fresh_id,
            opened: opened,
            talked: talked,
            dead: dead,
            fresh: fresh,
            same: false
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    else
      nil -> {:error, :pick_miss}
      other -> other
    end
  end

  defp minted?(session) do
    events = Enum.map(session.events || [], & &1.type)
    session.badge != nil or "morph.commit" in events or "morph.rejoin" in events
  end

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end