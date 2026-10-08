defmodule Room.SelfReportCheck do
  @moduledoc """
  Prompt-check on the self-report tag-match path.

  Pass opens mazel'd in-agent chat. Claim / contradiction
  stay curious — never mazel'd. Built into SelfReportMatch.match.
  Distinct from self_report_match / overlap / why (no
  prompt_check=). Off score. Off wiki. Off morph.
  """

  def look_has(rec \\ %{}), do: Room.SelfReportMatch.look_has(rec)
  def look_need(rec \\ %{}), do: Room.SelfReportMatch.look_need(rec)
  def look_find(rec \\ %{}), do: Room.SelfReportMatch.look_find(rec)
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look_pass, do: "ok  prompt_check=pass"

  def look_claim, do: "error  prompt_check=claim  class=curious  mazel'd=none"

  def look_contradiction,
    do: "error  prompt_check=contradiction  class=curious  mazel'd=none"

  def look(pack) when is_map(pack) do
    [
      look_has(pack.has),
      look_need(pack.need),
      look_pass(),
      look_find(pack.hit),
      look_claim(),
      look_contradiction(),
      look_complete()
    ]
  end

  def look(_), do: look(%{has: %{}, need: %{}, hit: %{}})

  @boast "claim: passionate visionary hunt for series-a"
  @deny "transcript: we do not do series-a"

  @doc """
  Self-report overlap, then prompt-check. Pass mazel'd.
  Claim / contradiction never open a session.
  Isolated. Sibling match / overlap / why LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-check-" <> random_id()

    has = Room.SelfReportMatch.parse(Keyword.get(opts, :has) || "has: series-a")
    need = Room.SelfReportMatch.parse(Keyword.get(opts, :need) || "need: series-a")
    hit = Room.SelfReportMatch.match(has, need)
    claim = Room.SelfReportMatch.match(has, need, transcript: @boast)
    contradiction = Room.SelfReportMatch.match(has, need, transcript: @deny)

    with {:ok, found} <- Room.Find.query(hit.query || "series-a"),
         {:ok, session} <- keep_if_pass(prefix, hit) do
      card = List.first(found[:hits] || [])
      events = Enum.map(session.events || [], & &1.type)

      cond do
        has.source != "self_report" or need.source != "self_report" ->
          {:error, :not_self_report}

        hit[:prompt_check] != "pass" or not hit.ok ->
          {:error, :check_miss}

        claim.ok or claim[:prompt_check] != "claim" ->
          {:error, :claim_hit}

        contradiction.ok or contradiction[:prompt_check] != "contradiction" ->
          {:error, :contradiction_hit}

        is_nil(card) or card.handle != "kai@mazel" ->
          {:error, :find_miss}

        session.status != :open or session.badge != nil or "morph.commit" in events ->
          {:error, :session_miss}

        humans_awake?(session) ->
          {:error, :human_woke}

        true ->
          pack = %{
            has: has,
            need: need,
            hit: hit,
            claim: claim,
            contradiction: contradiction,
            find: found,
            session: session,
            complete: :agent
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp keep_if_pass(_id, %{ok: false}), do: {:error, :curious_mazeld}

  defp keep_if_pass(id, hit) do
    peer = hit[:handle] || "kai@mazel"

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup(peer) do
      Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}])
    end
  end

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
