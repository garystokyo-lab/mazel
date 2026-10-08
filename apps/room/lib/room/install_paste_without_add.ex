defmodule Room.InstallPasteWithoutAdd do
  @moduledoc """
  Paste without Add Mazel is rejected. Tools stay locked.

  Distinct from install_paste_brains (paste after Add),
  install_swiss / install_second_brain_remove (paste with
  Add present), and install_gate (Need/Have without Add;
  no paste). Off PDF / badge / GH / score / wiki / morph /
  Consent / Session / Match.
  """

  @denied [:grok, :cursor]

  def denied, do: @denied

  def look_none, do: Room.InstallAddMazel.look_none()
  def look_locked, do: Room.InstallUnlockRemove.look_locked()

  def look_paste(brain) do
    "error  paste=#{brain}  error=add_required"
  end

  def look(_pack \\ %{}) do
    [look_none()] ++
      Enum.flat_map(@denied, fn brain ->
        [look_paste(brain), look_locked()]
      end)
  end

  @doc """
  No Add. Paste grok then cursor. Both rejected.
  Tools stay locked. Isolated. Sibling paste / swiss /
  second_brain / gate LOOK stays.
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
              "mazel-install-paste-without-add-#{System.unique_integer([:positive])}"
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

    with {:error, :not_ready} <- find(root),
         {:error, :not_added} <- Room.Install.paste(root, :grok),
         {:error, :not_ready} <- find(root),
         {:error, :not_added} <- Room.Install.paste(root, :cursor),
         {:error, :not_ready} <- find(root) do
      cond do
        Room.Install.added?(root) ->
          {:error, :still_added}

        Room.Install.required?(root) ->
          {:error, :gate_wrote}

        Room.Install.unlock(root) == :ok ->
          {:error, :still_open}

        Room.Install.unlock_count(root) != 0 ->
          {:error, :unlock_count}

        Room.Install.paste(root, :hermes) != {:error, :not_added} ->
          {:error, :paste_leaked}

        Room.Toolbelt.proof_has_count(root) != 0 ->
          {:error, :proof_wrote}

        true ->
          pack = %{root: root, denied: @denied, paste: :not_added}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp find(root) do
    Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => root})
  end
end
