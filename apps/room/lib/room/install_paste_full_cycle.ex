defmodule Room.InstallPasteFullCycle do
  @moduledoc """
  Add → paste → Remove → Add → paste unlocks again.

  Distinct from install_paste_after_remove (ends
  rejected after Remove), install_readd_after_remove
  (re-Add unlocks; no paste cycle), and
  install_add_then_paste (single Add→paste). Off PDF /
  badge / GH / score / wiki / morph / Consent /
  Session / Match.
  """

  def look_add, do: Room.InstallAddThenPaste.look_add()
  def look_paste, do: Room.InstallAddThenPaste.look_paste()
  def look_need(rec \\ %{}), do: Room.InstallAddThenPaste.look_need(rec)
  def look_unlocked, do: Room.InstallAddThenPaste.look_unlocked()
  def look_remove, do: Room.InstallUnlockRemove.look_remove()
  def look_locked, do: Room.InstallUnlockRemove.look_locked()
  def look_hermes, do: Room.InstallPasteBrains.look_paste(:hermes)

  def look(pack) when is_map(pack) do
    Room.InstallAddThenPaste.look(pack) ++
      [
        look_remove(),
        look_locked(),
        look_add(),
        look_hermes(),
        look_unlocked()
      ]
  end

  def look(_), do: look(%{need: %{}})

  @doc """
  Add, paste grok, unlock, remove, re-Add, paste hermes.
  Tools unlock again. Isolated. Sibling paste_after_remove
  / readd / add_then_paste LOOK stays.
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
              "mazel-install-paste-full-cycle-#{System.unique_integer([:positive])}"
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

    with {:ok, unlocked} <- Room.InstallAddThenPaste.demo(root: root),
         {:ok, removed} <- Room.Install.remove(root),
         {:error, :not_ready} <- find(root),
         {:error, :not_added} <- Room.Install.paste(root, :grok),
         {:ok, second} <- Room.Install.add(root),
         {:ok, hermes} <- Room.Install.paste(root, :hermes),
         {:ok, _} <- find(root) do
      cond do
        unlocked.pasted.brain != :grok or unlocked.pasted.snippet != :ok ->
          {:error, :paste_miss}

        removed[:noop] != false or removed.button != :gone ->
          {:error, :remove_miss}

        second[:idempotent] != false or second.button != :ok ->
          {:error, :readd_miss}

        hermes.brain != :hermes or hermes.snippet != :ok ->
          {:error, :hermes_miss}

        hermes.command != "mix" or hermes.args != ["mcp"] ->
          {:error, :stdio_miss}

        not Room.Install.added?(root) ->
          {:error, :add_miss}

        not Room.Install.required?(root) ->
          {:error, :gate_gone}

        Room.Install.unlock(root) != :ok ->
          {:error, :still_locked}

        Room.Install.unlock_count(root) != 1 ->
          {:error, :unlock_count}

        Room.Toolbelt.proof_has_count(root) != 0 ->
          {:error, :proof_wrote}

        true ->
          pack =
            Map.merge(unlocked, %{
              root: root,
              removed: removed,
              second: second,
              hermes: hermes
            })

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp find(root) do
    Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root})
  end
end
