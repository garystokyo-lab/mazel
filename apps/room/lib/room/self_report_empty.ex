defmodule Room.SelfReportEmpty do
  @moduledoc """
  No Has candidates for a Need. Find is none. No crash.

  Distinct from self_report_match / pick (candidates
  exist), self_report_curious (curious/claim class), and
  self_report_overlap (Has exists, tags miss).
  Off PDF / badge / GH / score / wiki / morph / toolbelt.
  """

  def look_need(rec \\ %{}), do: Room.SelfReportMatch.look_need(rec)

  def look_empty do
    "ok  has=none  candidates=[]"
  end

  def look_miss, do: Room.SelfReportCurious.look_miss()
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [look_need(pack.need), look_empty(), look_miss(), look_complete()]
  end

  def look(_), do: look(%{need: %{}})

  @doc """
  Need against an empty Has vault. Find none. Stay in-agent.
  Isolated. Sibling match / pick / curious LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-empty-" <> random_id()
    root = Keyword.get(opts, :root) || Path.join(System.tmp_dir!(), prefix)

    need = Room.SelfReportMatch.parse(Keyword.get(opts, :need) || "need: series-a")
    has_list = Room.SelfReportMatch.vault(root, :has)
    found = Room.SelfReportMatch.find_vault(has_list, need)

    with {:ok, session} <- keep_agent(prefix) do
      events = Enum.map(session.events || [], & &1.type)

      cond do
        need.source != "self_report" or need.tags != ["series-a"] ->
          {:error, :not_self_report}

        has_list != [] or Room.SelfReportMatch.vault_has_count(root) != 0 ->
          {:error, :vault_dirty}

        found.ok or found.candidates != [] or found.handle != nil ->
          {:error, :empty_hit}

        found.error != "empty" or found.query != "series-a" ->
          {:error, :empty_miss}

        session.status != :open or session.badge != nil or "morph.commit" in events ->
          {:error, :session_miss}

        "talk" in events ->
          {:error, :talked}

        humans_awake?(session) ->
          {:error, :human_woke}

        true ->
          pack = %{
            need: need,
            has_list: has_list,
            found: found,
            candidates: found.candidates,
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
