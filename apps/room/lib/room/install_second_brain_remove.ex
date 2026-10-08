defmodule Room.InstallSecondBrainRemove do
  @moduledoc """
  After unlock, a second-brain paste still works.
  Remove Mazel then locks again.

  Distinct from install_unlock_remove (no paste),
  install_paste_brains / install_swiss (no remove lock),
  and install_remove_mazel (Has/Need labels; no second
  paste). Off PDF / badge / GH / score / wiki / morph /
  Consent / Session / Match.
  """

  @second [:grok, :hermes]

  def second, do: @second

  def look_add, do: Room.InstallUnlockRemove.look_add()
  def look_need(rec \\ %{}), do: Room.InstallUnlockRemove.look_need(rec)
  def look_unlocked, do: Room.InstallUnlockRemove.look_unlocked()
  def look_paste(brain), do: Room.InstallPasteBrains.look_paste(brain)
  def look_remove, do: Room.InstallUnlockRemove.look_remove()
  def look_locked, do: Room.InstallUnlockRemove.look_locked()

  def look(pack) when is_map(pack) do
    brains = pack[:brains] || @second

    [look_add(), look_need(pack.need), look_unlocked()] ++
      Enum.map(brains, &look_paste/1) ++
      [look_remove(), look_locked()]
  end

  def look(_), do: look(%{need: %{}})

  @doc """
  Add Mazel, Need unlocks, paste grok+hermes, remove locks.
  Isolated. Sibling unlock_remove / paste / swiss stay.
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
              "mazel-install-second-brain-remove-#{System.unique_integer([:positive])}"
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

    with {:ok, _} <- Room.Install.add(root),
         {:ok, _} <- Room.SelfReportMatch.put(root, need),
         {:ok, _} <- Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root}),
         {:ok, pastes} <- paste_second(root),
         {:ok, _} <- Room.Install.remove(root),
         {:error, :not_ready} <-
           Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root}) do
      cond do
        need.source != "self_report" or need.tags != ["series-a"] ->
          {:error, :not_self_report}

        not Room.Toolbelt.ready?(root) ->
          {:error, :belt_dropped}

        Room.SelfReportMatch.vault_need_count(root) < 1 ->
          {:error, :need_gone}

        Enum.map(pastes, & &1.brain) != @second ->
          {:error, :brains_miss}

        Enum.any?(pastes, &(&1.snippet != :ok)) ->
          {:error, :snippet_miss}

        Room.Install.added?(root) ->
          {:error, :still_added}

        not Room.Install.required?(root) ->
          {:error, :gate_gone}

        Room.Install.unlock(root) == :ok ->
          {:error, :still_open}

        Room.Install.paste(root, :grok) != {:error, :not_added} ->
          {:error, :paste_after_remove}

        Room.Toolbelt.proof_has_count(root) != 0 ->
          {:error, :proof_wrote}

        true ->
          pack = %{need: need, root: root, brains: @second, pastes: pastes}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp paste_second(root) do
    rows = Enum.map(@second, &Room.Install.paste(root, &1))

    case Enum.find(rows, &match?({:error, _}, &1)) do
      {:error, reason} -> {:error, reason}
      nil -> {:ok, Enum.map(rows, fn {:ok, rec} -> rec end)}
    end
  end
end
