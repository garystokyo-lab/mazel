defmodule Room.InstallSwiss do
  @moduledoc """
  Add Mazel is the same on cursor / grok / hermes / muse.

  Claude and OpenAI are not_swiss. Distinct from
  install_paste_brains (snippet=) and install_add_mazel
  (self-report unlock). Off PDF / badge / GH / score /
  wiki / morph.
  """

  @foreign [:claude, :openai]

  def foreign, do: @foreign

  def look_ready(brain) do
    "ok  brain=#{brain}  add=mazel  tools=ready"
  end

  def look_foreign(brain) do
    "error  brain=#{brain}  add=none  error=not_swiss"
  end

  def look(pack \\ %{}) do
    brains = pack[:brains] || Room.Install.brains()
    blocked = pack[:foreign] || @foreign
    Enum.map(brains, &look_ready/1) ++ Enum.map(blocked, &look_foreign/1)
  end

  @doc """
  Add Mazel on each Switzerland brain. Foreign brains
  stay add=none. Isolated. Sibling paste / add LOOK stays.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path =
            Path.join(System.tmp_dir!(), "mazel-install-swiss-#{System.unique_integer([:positive])}")

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

    seats =
      Enum.map(brains, fn brain ->
        seat = Path.join(root, to_string(brain))
        File.mkdir_p!(seat)
        {brain, seat, Room.Install.add_for(seat, brain)}
      end)

    with true <- Enum.all?(seats, &match?({_, _, {:ok, _}}, &1)),
         {:error, :not_swiss} <- Room.Install.add_for(root, :claude),
         {:error, :not_swiss} <- Room.Install.add_for(root, :openai) do
      added = Enum.map(seats, fn {brain, seat, {:ok, rec}} -> {brain, seat, rec} end)

      cond do
        Enum.any?(added, fn {_b, _s, rec} -> rec.tools != :ready or rec.button != :ok end) ->
          {:error, :tools_miss}

        Enum.any?(added, fn {_b, _s, rec} -> rec.command != "mix" or rec.args != ["mcp"] end) ->
          {:error, :stdio_miss}

        Enum.any?(added, fn {_b, seat, _rec} -> not Room.Install.added?(seat) end) ->
          {:error, :add_miss}

        Room.Install.swiss?(:claude) or Room.Install.swiss?(:openai) ->
          {:error, :swiss_leaked}

        Room.Install.add_for(root, :anthropic) != {:error, :not_swiss} ->
          {:error, :swiss_leaked}

        true ->
          pack = %{root: root, brains: brains, foreign: @foreign, seats: added}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    else
      false -> {:error, :brain_miss}
      {:error, reason} -> {:error, reason}
    end
  end
end
