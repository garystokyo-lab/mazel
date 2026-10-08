defmodule Room.InstallPasteBrains do
  @moduledoc """
  Paste path after Add Mazel. One snippet per brain.

  cursor | grok | hermes | muse. Unknown is
  unsupported_brain. Distinct from install (stdio=),
  install_add_mazel (joined paste=), install_remove
  (lock). Off PDF / badge / GH / score / wiki / morph.
  """

  def look_add, do: "ok  add=mazel  button=ok"

  def look_paste(brain) do
    "ok  paste=#{brain}  snippet=ok"
  end

  def look_unknown, do: "error  paste=unknown  error=unsupported_brain"

  def look(pack \\ %{}) do
    brains = pack[:brains] || Room.Install.brains()
    [look_add()] ++ Enum.map(brains, &look_paste/1) ++ [look_unknown()]
  end

  @doc """
  Add Mazel, then paste each Switzerland brain.
  Unknown brain fails clean. Isolated.
  Sibling install / add / remove LOOK stays.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path =
            Path.join(System.tmp_dir!(), "mazel-install-paste-#{System.unique_integer([:positive])}")

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
    brains = Room.Install.brains()

    with {:ok, added} <- Room.Install.add(root),
         {:ok, pastes} <- paste_all(root, brains),
         {:error, :unsupported_brain} <- Room.Install.paste(root, "unknown") do
      cond do
        added.button != :ok ->
          {:error, :add_miss}

        not Room.Install.added?(root) ->
          {:error, :add_miss}

        Enum.any?(pastes, &(&1.snippet != :ok)) ->
          {:error, :snippet_miss}

        Enum.map(pastes, & &1.brain) != brains ->
          {:error, :brains_miss}

        Enum.any?(pastes, fn p -> p.command != "mix" or p.args != ["mcp"] end) ->
          {:error, :stdio_miss}

        Room.Install.paste(root, :ghost) != {:error, :unsupported_brain} ->
          {:error, :ghost_leaked}

        true ->
          pack = %{root: root, brains: brains, pastes: pastes}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp paste_all(root, brains) do
    rows = Enum.map(brains, &Room.Install.paste(root, &1))

    case Enum.find(rows, &match?({:error, _}, &1)) do
      {:error, reason} -> {:error, reason}
      nil -> {:ok, Enum.map(rows, fn {:ok, rec} -> rec end)}
    end
  end
end
