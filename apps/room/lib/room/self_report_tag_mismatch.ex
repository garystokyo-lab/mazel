defmodule Room.SelfReportTagMismatch do
  @moduledoc """
  Need series-a × Has cto only. Find is none.

  Dedicated mismatch path. Distinct from
  self_report_overlap (partial overlap hits; zero-overlap
  is secondary), self_report_empty (no Has), and
  self_report_match (exact match). Off PDF / badge / GH /
  score / wiki / morph / toolbelt / talk-turns.
  """

  def look_need(rec \\ %{}), do: Room.SelfReportMatch.look_need(rec)
  def look_has(rec \\ %{}), do: Room.SelfReportMatch.look_has(rec)
  def look_miss, do: "error  overlap=[]  find=none  mazel'd=none"
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [look_need(pack.need), look_has(pack.has), look_miss(), look_complete()]
  end

  def look(_), do: look(%{need: %{tags: ["series-a"]}, has: %{tags: ["cto"]}})

  @doc """
  Need series-a, Has cto. Mismatch. Stay in-agent.
  Isolated. Sibling overlap / empty / match LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-tag-mismatch-" <> random_id()
    root = Keyword.get(opts, :root) || Path.join(System.tmp_dir!(), prefix)

    File.mkdir_p!(root)

    need = Room.SelfReportMatch.parse(Keyword.get(opts, :need) || "need: series-a")
    has = Room.SelfReportMatch.parse(Keyword.get(opts, :has) || "has: cto")
    missed = Room.SelfReportMatch.mismatch(has, need)
    found = Room.SelfReportMatch.find_vault([has], need)

    with {:ok, _} <- Room.SelfReportMatch.put(root, has),
         {:ok, _} <- Room.SelfReportMatch.put(root, need),
         {:ok, session} <- keep_agent(prefix) do
      vaulted = Room.SelfReportMatch.find_vault(Room.SelfReportMatch.vault(root, :has), need)
      events = Enum.map(session.events || [], & &1.type)

      cond do
        need.source != "self_report" or need.tags != ["series-a"] ->
          {:error, :need_miss}

        has.source != "self_report" or has.tags != ["cto"] ->
          {:error, :has_miss}

        Room.SelfReportMatch.overlap(has, need) != [] ->
          {:error, :overlap_hit}

        missed.ok or missed.find != :none or missed.mazel_d != :none ->
          {:error, :mismatch_hit}

        missed.error != "no_overlap" or missed.overlap != [] ->
          {:error, :mismatch_miss}

        found.error != "no_overlap" or found.ok ->
          {:error, :vault_hit}

        found.error == "empty" or vaulted.error == "empty" ->
          {:error, :empty_path}

        vaulted.error != "no_overlap" or vaulted.ok ->
          {:error, :vault_hit}

        Room.SelfReportMatch.vault_has_count(root) != 1 ->
          {:error, :has_gone}

        session.status != :open or session.badge != nil or "morph.commit" in events ->
          {:error, :session_miss}

        "talk" in events ->
          {:error, :talked}

        humans_awake?(session) ->
          {:error, :human_woke}

        true ->
          pack = %{
            need: need,
            has: has,
            missed: missed,
            found: found,
            vaulted: vaulted,
            session: session,
            complete: :agent,
            root: root
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
