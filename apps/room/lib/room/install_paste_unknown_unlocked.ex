defmodule Room.InstallPasteUnknownUnlocked do
  @moduledoc """
  Unknown paste rejects. Tools stay unlocked after Add.

  Distinct from install_paste_brains (unknown reject;
  no unlocked-tools stay beat), install_swiss (not_swiss
  for claude/openai; no paste-unknown while unlocked),
  and install_paste_without_add (reject without Add;
  tools locked). Off PDF / badge / GH / score / wiki /
  morph / Consent / Session / Match.
  """

  def look_add, do: Room.InstallPasteBrains.look_add()
  def look_need(rec \\ %{}), do: Room.SelfReportToolbelt.look_need(rec)
  def look_unlocked, do: Room.SelfReportToolbelt.look_unlocked()
  def look_unknown, do: Room.InstallPasteBrains.look_unknown()

  def look(pack) when is_map(pack) do
    [look_add(), look_need(pack.need), look_unlocked(), look_unknown(), look_unlocked()]
  end

  def look(_), do: look(%{need: %{}})

  @doc """
  Add, Need unlocks, unknown paste rejects, tools stay.
  Isolated. Sibling paste_brains / swiss / without_add
  LOOK stays.
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
              "mazel-install-paste-unknown-unlocked-#{System.unique_integer([:positive])}"
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
         {:ok, _} <- Room.SelfReportMatch.put(root, need),
         {:ok, _} <- Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root}),
         {:error, :unsupported_brain} <- Room.Install.paste(root, "unknown"),
         {:ok, _} <- Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root}) do
      cond do
        added.button != :ok or added.idempotent != false ->
          {:error, :add_miss}

        not Room.Install.added?(root) ->
          {:error, :add_miss}

        need.source != "self_report" or need.tags != ["series-a"] ->
          {:error, :not_self_report}

        not Room.Toolbelt.ready?(root) ->
          {:error, :belt_miss}

        Room.Install.unlock(root) != :ok ->
          {:error, :locked}

        Room.Install.unlock_count(root) != 1 ->
          {:error, :unlock_count}

        Room.Install.paste(root, :ghost) != {:error, :unsupported_brain} ->
          {:error, :ghost_leaked}

        Room.Install.pasted(root) != [] ->
          {:error, :paste_wrote}

        Room.Toolbelt.proof_has_count(root) != 0 ->
          {:error, :proof_wrote}

        true ->
          pack = %{root: root, need: need, added: added, paste: :unsupported_brain}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end
end
