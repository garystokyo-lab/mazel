defmodule Room.AgentComplete do
  @moduledoc """
  Find → Need×Has → mazel'd chat stays in-agent. No morph.

  Prompt-check + double-magic why on the complete path.
  Agents keep the thread (`session=agent`). Claim is unfit.
  Not badge. Not PDF. Not Has-import.
  """

  def look_find, do: "ok  find=series-a→kai@mazel  mazel'd @kai"

  def look_match(rec) when is_map(rec) do
    peer = rec[:handle] || rec[:peer] || "kai@mazel"
    score = rec[:score] || 0
    "ok  need×has  peer=#{peer}  check=pass  score=#{fmt(score)}"
  end

  def look_match(_), do: look_match(%{handle: "kai@mazel", score: 0})

  def look_why(rec) when is_map(rec) do
    [
      "why  need=#{rec[:why_need] || "series-a"}",
      "why  has=#{rec[:why_has] || "series-a"}"
    ]
  end

  def look_complete, do: "ok  complete=agent  morph=none  session=agent"

  def look_claim, do: Room.NeedCheck.look_claim()

  def look(pack) when is_map(pack) do
    [look_find(), look_match(pack.match)] ++ look_why(pack.match) ++ [look_complete(), look_claim()]
  end

  def look(_), do: look(%{match: %{handle: "kai@mazel", score: 0, why_need: "series-a", why_has: "series-a"}})

  @doc """
  Need×Has after find completes in-agent. Check + why + session.
  Isolated. Does not rewrite mvp_find / why / prompt_check / find LOOK.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-agent-complete-#{System.unique_integer([:positive])}")
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
         {:ok, skipped} <- Room.Need.match_has(claim, root: root),
         {:ok, session} <- keep_agent(match, opts) do
      hit = List.first(found[:hits] || [])
      why = Room.Score.why_fields(need, match)
      why = if why.why_need in [nil, ""] or why.why_has in [nil, ""], do: why_ids(need, match), else: why
      events = Enum.map(session.events || [], & &1.type)

      cond do
        is_nil(hit) or hit.handle != "kai@mazel" ->
          {:error, :find_miss}

        need.check != "pass" or need.unfit ->
          {:error, :check_miss}

        not match.ok or match.handle != "kai@mazel" or match[:unfit] ->
          {:error, :match_miss}

        not claim.unfit or skipped.ok or skipped.matches != [] ->
          {:error, :claim_fit}

        why.why_need != "series-a" or why.why_has != "series-a" ->
          {:error, :why_miss}

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
            match: Map.merge(match, why),
            claim: claim,
            session: session,
            complete: :agent,
            stay: :agent
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp keep_agent(match, opts) do
    id = Keyword.get(opts, :context_id) || "agent-complete-" <> random_id()
    peer = match[:handle] || "kai@mazel"

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup(peer) do
      Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}])
    end
  end

  defp why_ids(need, match) do
    overlap = List.wrap(match[:overlap])
    want = List.first(List.wrap(need[:wants])) || "series-a"
    id = List.first(overlap) || want
    id = if is_binary(id) and String.contains?(to_string(id), "@"), do: want, else: to_string(id)
    %{why_need: id, why_has: id}
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
