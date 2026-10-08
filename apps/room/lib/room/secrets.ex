defmodule Room.Secrets do
  @moduledoc """
  Thin dotenvx vault hook. Proves the load path. Never prints values.

  Card keys live in `.env.example` as names only. `dotenvx set` /
  `dotenvx run -- mix …` injects them. See `docs/SECRETS.md`.
  """

  @vault "dotenvx"
  @mask "***"
  @example_name ".env.example"

  def vault, do: @vault
  def mask, do: @mask

  def example_path do
    Path.join(Room.Index.repo_root(), @example_name)
  end

  @doc "Placeholder card-key names from `.env.example`. Never values."
  def keys do
    path = example_path()

    if File.regular?(path) do
      path
      |> File.read!()
      |> String.split("\n")
      |> Enum.flat_map(&key_name/1)
      |> Enum.uniq()
      |> Enum.sort()
    else
      []
    end
  end

  @doc "True when the example + hook path exist. Does not read secret files."
  def loaded? do
    File.regular?(example_path())
  end

  def look(pack \\ %{}) do
    loaded = Map.get(pack, :loaded, loaded?())
    listed = pack[:keys] || keys()

    [
      "ok  vault=#{@vault}  loaded=#{loaded}",
      "ok  keys=[#{Enum.join(listed, ",")}]  masked=true",
      "ok  example=#{@example_name}"
    ]
  end

  @doc """
  LOOK only. Does not read `.env` or echo env values.
  Fails if a known value leaked into the lines.
  """
  def demo(opts \\ []) do
    listed = keys()
    loaded = loaded?()
    lines = look(%{loaded: loaded, keys: listed})

    if leak?(lines, listed) do
      {:error, :secret_leaked}
    else
      pack = %{
        vault: @vault,
        loaded: loaded,
        keys: listed,
        masked: true,
        example: @example_name,
        lines: lines
      }

      if Keyword.get(opts, :require_loaded, true) and not loaded do
        {:error, :example_missing}
      else
        {:ok, pack}
      end
    end
  end

  defp key_name(line) do
    stripped = line |> String.trim() |> String.replace_leading("#", "") |> String.trim()

    case Regex.run(~r/^(MAZEL_CARD_[A-Z0-9_]+)=?/, stripped) do
      [_, "MAZEL_CARDS_DIR"] -> []
      [_, key] -> [key]
      _ -> []
    end
  end

  defp leak?(lines, keys) do
    blob = Enum.join(lines, "\n")

    Enum.any?(keys, fn key ->
      case System.get_env(key) do
        nil -> false
        "" -> false
        value -> String.contains?(blob, value)
      end
    end) or secret_env_leaked?(blob)
  end

  defp secret_env_leaked?(blob) do
    ["DOTENV_PRIVATE_KEY", "DOTENV_PUBLIC_KEY"]
    |> Enum.any?(fn key ->
      case System.get_env(key) do
        nil -> false
        "" -> false
        value -> String.contains?(blob, value)
      end
    end)
  end
end