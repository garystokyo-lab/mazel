defmodule Room.Install do
  @moduledoc """
  Portable Add-Mazel pastes. Same stdio MCP (`mix mcp`) for Cursor,
  Grok, Hermes, and Muse. No Anthropic. No OpenAI. No npx.
  """

  @brains [:cursor, :grok, :hermes, :muse]

  def brains, do: @brains

  def file(:cursor), do: Path.join(Room.Index.repo_root(), ".cursor/mcp.json.example")
  def file(:grok), do: Path.join(snippets_dir(), "grok.config.toml")
  def file(:hermes), do: Path.join(snippets_dir(), "hermes.config.yaml")
  def file(:muse), do: Path.join(snippets_dir(), "muse.settings.json")

  def snippets_dir, do: Path.join(Room.Index.repo_root(), "docs/install")

  def load(brain) when brain in @brains do
    text = File.read!(file(brain))
    down = String.downcase(text)

    cond do
      String.contains?(down, "anthropic") ->
        {:error, :anthropic_hard_dep}

      String.contains?(down, "openai") ->
        {:error, :openai_hard_dep}

      String.contains?(text, "npx") ->
        {:error, :npx_hero}

      true ->
        command = extract_command(text)
        args = extract_args(text)

        if command == "mix" and args == ["mcp"] do
          {:ok, %{brain: brain, command: command, args: args, text: text}}
        else
          {:error, :not_stdio_mcp}
        end
    end
  end

  def load(_), do: {:error, :unsupported_brain}

  @doc """
  Paste adapter after Add Mazel. Known brains yield a
  Switzerland snippet. Blank / empty / whitespace-only
  is blank_brain. Unknown is unsupported_brain and
  does not lock tools. Same brain twice is idempotent
  — one entry.
  """
  def paste(root, brain) when is_binary(root) do
    if added?(root) do
      case snippet(brain) do
        {:ok, rec} ->
          already = rec.brain in pasted(root)
          unless already, do: keep_brain(root, rec.brain)

          {:ok,
           Map.merge(rec, %{wipe: :none, brains: pasted(root), idempotent: already})}

        {:error, :blank_brain} = err ->
          err

        {:error, :unsupported_brain} = err ->
          err

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :not_added}
    end
  end

  def paste(_, _), do: {:error, :no_root}

  @doc """
  Drop one pasted brain. Add stays. Other brains stay.
  Does not lock tools. Unknown is unsupported_brain.
  Without Add is not_added. Missing or already-unpasted
  brain is a noop — list unchanged, no crash.
  """
  def unpaste(root, brain) when is_binary(root) do
    if added?(root) do
      case normalize_brain(brain) do
        {:ok, id} ->
          kept = pasted(root)

          if id in kept do
            next = drop_brain(root, id)
            {:ok, %{unpaste: id, brains: next, added: true}}
          else
            {:ok, %{unpaste: id, brains: kept, added: true, noop: true}}
          end

        :error ->
          {:error, :unsupported_brain}
      end
    else
      {:error, :not_added}
    end
  end

  def unpaste(_, _), do: {:error, :no_root}

  @doc """
  Brains pasted after Add. Second paste appends — no wipe.
  Empty before the first paste. Cleared on Remove.
  """
  def pasted(root) when is_binary(root) do
    path = pasted_marker(root)

    if File.exists?(path) do
      path
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.flat_map(fn line ->
        case normalize_brain(line) do
          {:ok, id} -> [id]
          :error -> []
        end
      end)
      |> Enum.uniq()
    else
      []
    end
  end

  def pasted(_), do: []

  def look_line(%{brain: brain, command: command, args: args}) do
    "ok  paste=#{brain}  stdio=#{command} #{Enum.join(args, " ")}"
  end

  def look do
    ["Mazel is ready."] ++
      Enum.map(@brains, fn brain ->
        {:ok, paste} = load(brain)
        look_line(paste)
      end)
  end

  def gate_dir(root), do: Path.join(root, "index/install")
  def marker(root), do: Path.join(gate_dir(root), "added")
  def pasted_marker(root), do: Path.join(gate_dir(root), "pasted")

  def required?(root) when is_binary(root), do: File.dir?(gate_dir(root))
  def required?(_), do: false

  def added?(root) when is_binary(root), do: File.exists?(marker(root))
  def added?(_), do: false

  @doc """
  Press Add Mazel. Writes the install marker. Pastes stay
  Switzerland. Already-added is idempotent — no second unlock.
  """
  def add(root) when is_binary(root) do
    if added?(root) do
      {:ok, %{added: true, button: :ok, idempotent: true, paste: @brains}}
    else
      File.mkdir_p!(gate_dir(root))
      File.write!(marker(root), "mazel\n")
      {:ok, %{added: true, button: :ok, idempotent: false, paste: @brains}}
    end
  end

  def add(_), do: {:error, :no_root}

  @doc "Unlocked once is 1. Locked or never-added is 0."
  def unlock_count(root) when is_binary(root) do
    case unlock(root) do
      :ok -> 1
      _ -> 0
    end
  end

  def unlock_count(_), do: 0

  def swiss?(brain), do: match?({:ok, _}, normalize_brain(brain))

  @doc """
  Same Add Mazel on a Switzerland brain. Claude / OpenAI
  are not_swiss. Tools ready means the paste is mix mcp.
  """
  def add_for(root, brain) when is_binary(root) do
    case normalize_brain(brain) do
      {:ok, id} ->
        with {:ok, paste} <- load(id),
             {:ok, added} <- add(root) do
          {:ok,
           Map.merge(added, %{
             brain: id,
             tools: :ready,
             swiss: true,
             command: paste.command,
             args: paste.args
           })}
        end

      :error ->
        {:error, :not_swiss}
    end
  end

  def add_for(_, _), do: {:error, :not_swiss}

  @doc """
  Take Add Mazel away. Gate stays; marker gone.
  Tools lock even when Need / Has remain.
  Never-added is a noop — no gate, no crash.
  Already-removed is a noop — gate stays, still
  locked, no crash.
  """
  def remove(root) when is_binary(root) do
    cond do
      added?(root) ->
        File.mkdir_p!(gate_dir(root))
        _ = File.rm(marker(root))
        _ = File.rm(pasted_marker(root))
        {:ok, %{added: false, button: :gone, noop: false}}

      required?(root) ->
        {:ok, %{added: false, button: :gone, noop: true}}

      true ->
        {:ok, %{added: false, button: :gone, noop: true}}
    end
  end

  def remove(_), do: {:error, :no_root}

  @doc """
  Tools open only after Add Mazel (when the gate exists) and
  Toolbelt.ready?. Vaults without index/install stay on ready?
  alone so sibling MCP unlocks stay.
  """
  def unlock(root) when is_binary(root) do
    if (not required?(root) or added?(root)) and Room.Toolbelt.ready?(root) do
      :ok
    else
      {:error, :not_ready}
    end
  end

  def unlock(_), do: {:error, :not_ready}

  defp keep_brain(root, brain) do
    next =
      root
      |> pasted()
      |> Kernel.++([brain])
      |> Enum.uniq()

    write_brains(root, next)
  end

  defp drop_brain(root, brain) do
    next =
      root
      |> pasted()
      |> Enum.reject(&(&1 == brain))

    write_brains(root, next)
  end

  defp write_brains(root, brains) do
    File.mkdir_p!(gate_dir(root))

    body =
      case brains do
        [] -> ""
        list -> Enum.map_join(list, "\n", &to_string/1) <> "\n"
      end

    File.write!(pasted_marker(root), body)
    brains
  end

  @doc """
  Empty vs whitespace-only blank. Both reject as
  blank_brain. Known brains and unknown ids are nil.
  """
  def blank_kind(brain) when is_binary(brain) do
    cond do
      brain == "" -> :empty
      String.trim(brain) == "" -> :whitespace
      true -> nil
    end
  end

  def blank_kind(_), do: nil

  defp snippet(brain) do
    cond do
      blank_kind(brain) != nil ->
        {:error, :blank_brain}

      true ->
        case normalize_brain(brain) do
          {:ok, id} ->
            with {:ok, rec} <- load(id) do
              {:ok, Map.put(rec, :snippet, :ok)}
            end

          :error ->
            {:error, :unsupported_brain}
        end
    end
  end

  defp normalize_brain(brain) when brain in @brains, do: {:ok, brain}

  defp normalize_brain(brain) when is_binary(brain) do
    id = brain |> String.trim() |> String.downcase()

    case Enum.find(@brains, &(to_string(&1) == id)) do
      nil -> :error
      found -> {:ok, found}
    end
  end

  defp normalize_brain(_), do: :error

  defp extract_command(text) do
    cond do
      m = Regex.run(~r/"command"\s*:\s*"([^"]+)"/, text) -> Enum.at(m, 1)
      m = Regex.run(~r/^command\s*=\s*"([^"]+)"/m, text) -> Enum.at(m, 1)
      m = Regex.run(~r/^\s*command:\s*"([^"]+)"/m, text) -> Enum.at(m, 1)
      true -> nil
    end
  end

  defp extract_args(text) do
    cond do
      m = Regex.run(~r/"args"\s*:\s*\[\s*"([^"]+)"\s*\]/, text) -> [Enum.at(m, 1)]
      m = Regex.run(~r/args\s*=\s*\[\s*"([^"]+)"\s*\]/, text) -> [Enum.at(m, 1)]
      m = Regex.run(~r/args:\s*\[\s*"([^"]+)"\s*\]/, text) -> [Enum.at(m, 1)]
      true -> []
    end
  end
end
