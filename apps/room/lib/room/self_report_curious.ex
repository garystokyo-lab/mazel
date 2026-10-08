defmodule Room.SelfReportCurious do
  @moduledoc """
  Curious / claim never find or mazel'd.

  Distinct from self_report_check / match (those show
  pass→mazel'd). This strip is curious/claim only → none.
  Off PDF / badge / GH / score / wiki / morph / toolbelt.
  """

  @curious "curious: series-a"
  @claim "claim: passionate visionary hunt for series-a"

  def curious_chat, do: @curious
  def claim_chat, do: @claim

  def look_cast(rec, kind) do
    tags = rec[:mentioned] || List.wrap(rec[:tags])
    tags = if(tags == [], do: ["series-a"], else: tags)
    "error  cast=#{kind}  tags=[#{Enum.join(tags, ",")}]  class=curious"
  end

  def look_miss, do: "error  find=series-a  match=none  mazel'd=none"
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [
      look_cast(pack.curious, "curious"),
      look_miss(),
      look_cast(pack.claim, "claim"),
      look_miss(),
      look_complete()
    ]
  end

  def look(_) do
    look(%{curious: %{mentioned: ["series-a"]}, claim: %{mentioned: ["series-a"]}})
  end

  @doc """
  Cast curious and claim. Neither overlaps Has. Stay in-agent.
  Isolated. Sibling check / match LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-curious-" <> random_id()

    has = Room.SelfReportMatch.parse(Keyword.get(opts, :has) || "has: series-a")
    curious = Room.SelfReportMatch.cast(:curious, Keyword.get(opts, :curious) || @curious)
    claim = Room.SelfReportMatch.cast(:claim, Keyword.get(opts, :claim) || @claim)
    miss_curious = Room.SelfReportMatch.match(has, curious)
    miss_claim = Room.SelfReportMatch.match(has, claim)

    with {:ok, session} <- keep_agent(prefix) do
      events = Enum.map(session.events || [], & &1.type)

      cond do
        has.source != "self_report" or has.tags != ["series-a"] ->
          {:error, :has_miss}

        curious[:cast] != "curious" or curious[:class] != "curious" or curious[:curious] != true ->
          {:error, :curious_miss}

        curious.tags != [] or curious[:mentioned] != ["series-a"] ->
          {:error, :curious_tags}

        claim[:cast] != "claim" or claim[:class] != "curious" or claim[:curious] != true ->
          {:error, :claim_miss}

        claim.tags != [] or claim[:mentioned] != ["series-a"] ->
          {:error, :claim_tags}

        miss_curious.ok or miss_curious.tags != [] or miss_curious.handle != nil ->
          {:error, :curious_hit}

        miss_claim.ok or miss_claim.tags != [] or miss_claim.handle != nil ->
          {:error, :claim_hit}

        session.status != :open or session.badge != nil or "morph.commit" in events ->
          {:error, :session_miss}

        humans_awake?(session) ->
          {:error, :human_woke}

        true ->
          pack = %{
            has: has,
            curious: curious,
            claim: claim,
            miss_curious: miss_curious,
            miss_claim: miss_claim,
            session: session,
            complete: :agent
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp keep_agent(id) do
    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai") do
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
