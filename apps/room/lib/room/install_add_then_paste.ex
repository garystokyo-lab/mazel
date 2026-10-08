defmodule Room.InstallAddThenPaste do
  @moduledoc """
  Add Mazel, then paste, then tools unlock.

  Happy path after paste-without-add. Distinct from
  install_paste_without_add (paste rejected),
  install_paste_brains (snippets; no unlock beat), and
  install_add_mazel / install_gate (Need/Have unlock;
  no paste-then-unlock). Off PDF / badge / GH / score /
  wiki / morph / Consent / Session / Match.
  """

  def look_add, do: Room.InstallPasteBrains.look_add()
  def look_paste, do: Room.InstallPasteBrains.look_paste(:grok)
  def look_need(rec \\ %{}), do: Room.SelfReportToolbelt.look_need(rec)
  def look_unlocked, do: Room.SelfReportToolbelt.look_unlocked()

  def look(pack) when is_map(pack) do
    [look_add(), look_paste(), look_need(pack.need), look_unlocked()]
  end

  def look(_), do: look(%{need: %{}})

  @doc """
  Add, paste grok, Need unlocks mazel_find. Isolated.
  Sibling paste_without_add / paste_brains / gate stay.
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
              "mazel-install-add-then-paste-#{System.unique_integer([:positive])}"
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
         {:ok, pasted} <- Room.Install.paste(root, :grok),
         {:ok, _} <- Room.SelfReportMatch.put(root, need),
         {:ok, _} <- Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root}) do
      cond do
        added.button != :ok or added.idempotent != false ->
          {:error, :add_miss}

        not Room.Install.added?(root) ->
          {:error, :add_miss}

        pasted.brain != :grok or pasted.snippet != :ok ->
          {:error, :paste_miss}

        pasted.command != "mix" or pasted.args != ["mcp"] ->
          {:error, :stdio_miss}

        need.source != "self_report" or need.tags != ["series-a"] ->
          {:error, :not_self_report}

        not Room.Toolbelt.ready?(root) ->
          {:error, :belt_miss}

        Room.Install.unlock(root) != :ok ->
          {:error, :still_locked}

        Room.Install.unlock_count(root) != 1 ->
          {:error, :unlock_count}

        Room.Toolbelt.proof_has_count(root) != 0 ->
          {:error, :proof_wrote}

        true ->
          pack = %{root: root, need: need, pasted: pasted, added: added}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end
end
