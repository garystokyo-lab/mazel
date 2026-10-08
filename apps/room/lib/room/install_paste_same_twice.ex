defmodule Room.InstallPasteSameTwice do
  @moduledoc """
  Paste the same brain twice is idempotent. One entry.

  Distinct from install_paste_both_stay (two different
  brains both stay), install_paste_brains /
  install_add_then_paste (single paste), and
  install_add_twice (Add idempotent; no paste). Off PDF /
  badge / GH / score / wiki / morph / Consent / Session /
  Match.
  """

  def look_add, do: Room.InstallPasteBrains.look_add()
  def look_paste, do: Room.InstallPasteBrains.look_paste(:grok)
  def look_again, do: "ok  paste=grok  idempotent=true"
  def look_brains, do: "ok  brains=grok  count=1"
  def look_need(rec \\ %{}), do: Room.SelfReportToolbelt.look_need(rec)
  def look_unlocked, do: Room.SelfReportToolbelt.look_unlocked()

  def look(pack) when is_map(pack) do
    [look_add(), look_paste(), look_again(), look_brains(), look_need(pack.need), look_unlocked()]
  end

  def look(_), do: look(%{need: %{}})

  @doc """
  Add, paste grok twice. Still one brain. Need unlocks.
  Isolated. Sibling both_stay / paste_brains /
  add_then_paste / add_twice LOOK stays.
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
              "mazel-install-paste-same-twice-#{System.unique_integer([:positive])}"
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
         {:ok, first} <- Room.Install.paste(root, :grok),
         {:ok, second} <- Room.Install.paste(root, :grok),
         {:ok, _} <- Room.SelfReportMatch.put(root, need),
         {:ok, _} <- Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root}) do
      kept = Room.Install.pasted(root)

      cond do
        added.button != :ok or added.idempotent != false ->
          {:error, :add_miss}

        not Room.Install.added?(root) ->
          {:error, :add_miss}

        first.brain != :grok or first.snippet != :ok or first.idempotent != false ->
          {:error, :first_miss}

        second.brain != :grok or second.snippet != :ok or second.idempotent != true ->
          {:error, :not_idempotent}

        first.wipe != :none or second.wipe != :none ->
          {:error, :wiped}

        kept != [:grok] or length(kept) != 1 or second.brains != [:grok] ->
          {:error, :brains_miss}

        :hermes in kept or :cursor in kept or :muse in kept ->
          {:error, :extra_brain}

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
          pack = %{
            root: root,
            need: need,
            added: added,
            first: first,
            second: second,
            brains: kept
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end
end
