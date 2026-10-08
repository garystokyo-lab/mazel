defmodule Room.SelfReportHasNoNeed do
  @moduledoc """
  Has tags with no live Need. Find is not called.

  Distinct from self_report_empty (Need exists, Has
  vault empty), self_report_has_cast / match (Need +
  Has → mazel'd), and self_report_clear (Need cleared
  after match). Off PDF / badge / GH / score / wiki /
  morph / toolbelt.
  """

  def look_has(rec \\ %{}), do: Room.SelfReportMatch.look_has(rec)
  def look_need, do: "ok  need=none"
  def look_skip, do: "error  find=not_called  mazel'd=none"
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [look_has(pack.has), look_need(), look_skip(), look_complete()]
  end

  def look(_), do: look(%{has: %{}})

  @doc """
  Has in vault, no live Need. Find not called. Stay
  in-agent. Isolated. Sibling empty / has_cast / clear
  LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-has-no-need-" <> random_id()
    root = Keyword.get(opts, :root) || Path.join(System.tmp_dir!(), prefix)

    has = Room.SelfReportMatch.parse(Keyword.get(opts, :has) || "has: series-a")

    with {:ok, stored} <- Room.SelfReportMatch.put(root, has) do
      has_list = Room.SelfReportMatch.vault(root, :has)
      needs = Room.SelfReportMatch.vault(root, :need)
      found = Room.SelfReportMatch.find_need(has_list, needs)

      with {:ok, session} <- keep_agent(prefix) do
        events = Enum.map(session.events || [], & &1.type)

        cond do
          stored.source != "self_report" or stored.tags != ["series-a"] ->
            {:error, :not_self_report}

          has_list == [] or Room.SelfReportMatch.vault_has_count(root) != 1 ->
            {:error, :has_miss}

          needs != [] or Room.SelfReportMatch.vault_need_count(root) != 0 ->
            {:error, :need_live}

          found.ok or found.called != false or found.handle != nil ->
            {:error, :find_called}

          found.error != "no_need" ->
            {:error, :gate_miss}

          session.status != :open or session.badge != nil or "morph.commit" in events ->
            {:error, :session_miss}

          "talk" in events ->
            {:error, :talked}

          humans_awake?(session) ->
            {:error, :human_woke}

          true ->
            pack = %{
              has: stored,
              has_list: has_list,
              needs: needs,
              found: found,
              session: session,
              complete: :agent,
              root: root
            }

            {:ok, Map.put(pack, :lines, look(pack))}
        end
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
