defmodule Room.AgentCompleteCheck do
  @moduledoc """
  Prompt-check on the in-agent complete path.

  check=pass stays complete=agent. Claim or contradict mid-path
  is curious unfit — no mazel'd. Distinct from prompt_check
  (no find / complete), open_need_check (open→need), and
  agent_complete_why (nova / shape / why / vibe).
  """

  def look_find, do: "ok  find=series-a→kai@mazel  mazel'd @kai"

  def look_pass(rec \\ %{}) do
    peer = rec[:handle] || rec[:peer] || "kai@mazel"
    "ok  need×has  peer=#{peer}  check=pass"
  end

  def look_complete, do: "ok  complete=agent  morph=none  session=agent"

  def look_claim, do: "error  claim→curious  unfit=true  mazel'd=none"

  def look_contradict, do: "error  contradict→curious  unfit=true  mazel'd=none"

  def look(pack) when is_map(pack) do
    [look_find(), look_pass(pack.match), look_complete(), look_claim(), look_contradict()]
  end

  def look(_), do: look(%{match: %{}})

  @doc """
  Find → Need×Has completes in-agent when check=pass.
  Claim / contradict never open a session.
  Isolated. Sibling complete / check LOOK stays.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-agent-check-#{System.unique_integer([:positive])}")
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
    deny = "transcript: we do not do series-a"

    with {:ok, found} <- Room.Find.query("series-a"),
         {:ok, need} <- Room.NeedCheck.cast(:founder_investors, transcript: agree),
         {:ok, match} <- Room.Need.match_has(need, root: root, transcript: agree),
         {:ok, claim} <- Room.NeedCheck.cast(:founder_investors, transcript: boast),
         {:ok, contradict} <- Room.NeedCheck.cast(:founder_investors, transcript: deny),
         {:ok, skipped} <- Room.Need.match_has(need, root: root, transcript: boast),
         {:ok, blocked} <- Room.Need.match_has(need, root: root, transcript: deny),
         {:ok, session} <- keep_agent(match, opts) do
      hit = List.first(found[:hits] || [])
      events = Enum.map(session.events || [], & &1.type)

      cond do
        is_nil(hit) or hit.handle != "kai@mazel" ->
          {:error, :find_miss}

        need.check != "pass" or need.unfit ->
          {:error, :check_miss}

        not match.ok or match.handle != "kai@mazel" or match[:unfit] ->
          {:error, :match_miss}

        not claim.unfit or claim.reason != "claim" ->
          {:error, :claim_fit}

        not contradict.unfit or contradict.reason != "contradict" ->
          {:error, :contradict_fit}

        skipped.ok or blocked.ok or skipped.matches != [] or blocked.matches != [] ->
          {:error, :curious_mazeld}

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
            match: match,
            claim: claim,
            contradict: contradict,
            skipped: skipped,
            blocked: blocked,
            session: session,
            complete: :agent
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp keep_agent(match, opts) do
    id = Keyword.get(opts, :context_id) || "agent-check-" <> random_id()
    peer = match[:handle] || "kai@mazel"

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
