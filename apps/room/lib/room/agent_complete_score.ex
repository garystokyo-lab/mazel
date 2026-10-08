defmodule Room.AgentCompleteScore do
  @moduledoc """
  Named Factor inputs + score on the in-agent complete path.

  Score.gather / Factors. Same registry. LLM never ranks.
  Distinct from agent_complete (score=0, no inputs=),
  agent_complete_check (no score strip), and score_demo
  (no complete=agent). Not badge. Not PDF. No morph.
  """

  def look_find, do: "ok  find=series-a→kai@mazel  mazel'd @kai"

  def look_match(rec) when is_map(rec) do
    peer = rec[:handle] || rec[:peer] || "kai@mazel"
    named = rec[:inputs] || rec[:factors] || %{}
    score = rec[:score] || 0
    "ok  need×has  peer=#{peer}  inputs=#{Room.Factors.format_inputs(named, :all)}  score=#{fmt(score)}"
  end

  def look_match(_), do: look_match(%{handle: "kai@mazel", score: 0, inputs: %{}})

  def look_complete, do: "ok  complete=agent  morph=none  session=agent"

  def look_claim, do: Room.NeedCheck.look_claim()

  def look(pack) when is_map(pack) do
    [look_find(), look_match(pack.match), look_complete(), look_claim()]
  end

  def look(_), do: look(%{match: %{}})

  @doc """
  Find → Need×Has completes in-agent with named inputs + score.
  Claim is curious. Isolated. Sibling LOOK stays.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-agent-score-#{System.unique_integer([:positive])}")
          File.mkdir_p!(Path.join(path, "index/has"))
          {path, true}
      end

    try do
      demo_on(root, opts)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp demo_on(root, opts) do
    File.cp!(
      Path.join(Room.Index.repo_root(), "index/has/kai.md"),
      Path.join(root, "index/has/kai.md")
    )

    agree = "need: founders seeking series-a"
    boast = "claim: passionate visionary hunt for series-a"

    with {:ok, found} <- Room.Find.query("series-a"),
         {:ok, need} <- Room.NeedCheck.cast(:founder_investors, transcript: agree),
         {:ok, match} <- Room.Need.match_has(need, root: root, transcript: agree),
         {:ok, claim} <- Room.NeedCheck.cast(:founder_investors, transcript: boast),
         {:ok, skipped} <- Room.Need.match_has(need, root: root, transcript: boast),
         {:ok, session} <- keep_agent(match, opts) do
      hit = List.first(found[:hits] || [])
      scored = Room.Score.decorate(match, need: need, root: root)
      events = Enum.map(session.events || [], & &1.type)

      cond do
        is_nil(hit) or hit.handle != "kai@mazel" ->
          {:error, :find_miss}

        need.check != "pass" or need.unfit ->
          {:error, :check_miss}

        not match.ok or match.handle != "kai@mazel" or match[:unfit] ->
          {:error, :match_miss}

        scored.unfit or is_nil(scored.inputs) ->
          {:error, :score_miss}

        not Map.has_key?(scored.inputs, :trail) or not Map.has_key?(scored.inputs, :check) ->
          {:error, :inputs_miss}

        not claim.unfit or skipped.ok or skipped.matches != [] ->
          {:error, :claim_fit}

        session.status != :open or session.session_kind != :direct ->
          {:error, :session_miss}

        session.badge != nil or "morph.commit" in events ->
          {:error, :morphed}

        humans_awake?(session) ->
          {:error, :human_woke}

        true ->
          pack = %{
            find: found,
            need: need,
            match: Map.merge(match, scored),
            claim: claim,
            session: session,
            complete: :agent
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp keep_agent(match, opts) do
    id = Keyword.get(opts, :context_id) || "agent-score-" <> random_id()
    peer = match[:handle] || "kai@mazel"

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup(peer) do
      Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}])
    end
  end

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp fmt(n) when is_float(n) do
    if n == Float.floor(n), do: trunc(n), else: :erlang.float_to_binary(n, decimals: 2)
  end

  defp fmt(n) when is_integer(n), do: n
  defp fmt(_), do: 0

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
