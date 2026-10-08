defmodule Room.InstallUnpasteMissing do
  @moduledoc """
  Unpaste a brain that was never pasted is a noop.

  List unchanged. Tools stay unlocked. No crash.
  Distinct from install_unpaste_one / unpaste_last
  (unpaste a brain that exists), install_remove_without_add
  (Remove Mazel never-Add noop), and
  install_paste_same_twice (paste idempotent). Off PDF /
  badge / GH / score / wiki / morph / Consent / Session /
  Match.
  """

  def look_add, do: Room.InstallPasteBrains.look_add()
  def look_paste, do: Room.InstallPasteBrains.look_paste(:grok)
  def look_one, do: "ok  brains=grok"
  def look_need(rec \\ %{}), do: Room.SelfReportToolbelt.look_need(rec)
  def look_unlocked, do: Room.SelfReportToolbelt.look_unlocked()
  def look_unpaste, do: "ok  unpaste=hermes  noop=true"
  def look_crash, do: "ok  crash=none"

  def look(pack) when is_map(pack) do
    [
      look_add(),
      look_paste(),
      look_one(),
      look_need(pack.need),
      look_unlocked(),
      look_unpaste(),
      look_one(),
      look_unlocked(),
      look_crash()
    ]
  end

  def look(_), do: look(%{need: %{}})

  @doc """
  Add, paste grok, Need unlocks, unpaste hermes (never
  pasted). Noop. Grok stays. Tools stay unlocked. No
  crash. Isolated. Sibling unpaste_one / unpaste_last /
  remove_without_add / same_twice LOOK stays.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path =
            Path.join(
              System.tmp_dir!(),
              "mazel-install-unpaste-missing-#{System.unique_integer([:positive])}"
            )

          File.mkdir_p!(path)
          {path, true}
      end

    try do
      demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp demo_on(root) do
    File.mkdir_p!(root)
    need = Room.SelfReportMatch.parse("need: series-a")

    with {:ok, added} <- Room.Install.add(root),
         {:ok, grok} <- Room.Install.paste(root, :grok),
         {:ok, _} <- Room.SelfReportMatch.put(root, need),
         {:ok, _} <- find(root),
         {:ok, missing} <- safe_unpaste(root, :hermes),
         {:ok, _} <- find(root) do
      kept = Room.Install.pasted(root)

      cond do
        added.button != :ok or added.idempotent != false ->
          {:error, :add_miss}

        not Room.Install.added?(root) ->
          {:error, :add_gone}

        grok.brain != :grok or grok.snippet != :ok ->
          {:error, :grok_miss}

        grok.brains != [:grok] or grok.wipe != :none ->
          {:error, :brains_miss}

        missing.unpaste != :hermes or missing.noop != true ->
          {:error, :not_noop}

        missing.added != true or missing.brains != [:grok] ->
          {:error, :list_changed}

        kept != [:grok] ->
          {:error, :list_changed}

        :hermes in kept ->
          {:error, :hermes_wrote}

        need.source != "self_report" or need.tags != ["series-a"] ->
          {:error, :not_self_report}

        not Room.Toolbelt.ready?(root) ->
          {:error, :belt_miss}

        Room.Install.unlock(root) != :ok ->
          {:error, :locked}

        Room.Install.unlock_count(root) != 1 ->
          {:error, :unlock_count}

        Room.Toolbelt.proof_has_count(root) != 0 ->
          {:error, :proof_wrote}

        true ->
          pack = %{
            root: root,
            need: need,
            added: added,
            grok: grok,
            missing: missing,
            brains: kept,
            crash: :none
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp find(root) do
    Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root})
  end

  defp safe_unpaste(root, brain) do
    try do
      Room.Install.unpaste(root, brain)
    rescue
      e -> {:error, {:crash, e}}
    end
  end
end
