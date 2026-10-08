defmodule Room.Cards do
  @moduledoc """
  Agent Card lookup. Env (`MAZEL_CARD_<HANDLE>`), then `cards/*.json`,
  then zone TXT (`mazel-card=` / optional `mazel-haah=1`), then mock.

  One resolve path. Zone parse lives in `Room.Dns`; this module is the resolver.

  dotenvx injects env before mix. A plain `.env` at repo root is loaded if present
  and the key is not already set. No Mazel secrets service. Vault LOOK:
  `mix secrets_demo` (never prints values). See `docs/SECRETS.md`.
  """

  @mocks %{
    "kai@mazel" => "https://mazel.ai/cards/kai",
    "nova@mazel" => "https://mazel.ai/cards/nova",
    "ariel@mazel" => "https://mazel.ai/cards/ariel"
  }

  def lookup(raw) when is_binary(raw) do
    case Room.Wings.parse_handle(raw) do
      {:ok, handle} -> lookup(handle)
      error -> error
    end
  end

  def lookup(%{id: id} = handle) do
    ensure_dotenv()
    local = local_name(id)

    cond do
      Room.Open.sink_id?(id) ->
        {:ok,
         handle |> Map.put(:sink, true) |> Map.put(:sink_kind, "open") |> Map.put(:source, :sink)}

      Room.Need.discovery_id?(id) ->
        {:ok,
         handle |> Map.put(:sink, true) |> Map.put(:sink_kind, "need") |> Map.put(:source, :sink)}

      true ->
        resolve_card(handle, id, local)
    end
  end

  @doc """
  File-card schema. Wire id `haah`. Required: handle, url, protocol.
  need / have are first-class when present (tag or tag list).
  """
  def validate(card) when is_map(card) do
    handle = card["handle"]
    url = card["url"] || card["card_url"]
    protocol = card["protocol"]
    need = Room.A2aPeerCard.tags(card["need"] || card[:need])
    have = Room.A2aPeerCard.tags(card["have"] || card[:have])

    cond do
      not usable_string?(handle) -> {:error, :missing_handle}
      not usable_string?(url) -> {:error, :missing_url}
      protocol != "haah" -> {:error, :bad_protocol}
      need == :bad -> {:error, :bad_need}
      have == :bad -> {:error, :bad_have}
      true -> :ok
    end
  end

  def validate(_), do: {:error, :not_a_map}

  def mocks, do: @mocks

  def cards_dir do
    System.get_env("MAZEL_CARDS_DIR") || Path.join(repo_root(), "cards")
  end

  def repo_root, do: Room.Index.repo_root()

  def env_key(local) when is_binary(local) do
    "MAZEL_CARD_" <> (local |> String.upcase() |> String.replace(~r/[^A-Z0-9]+/, "_"))
  end

  defp resolve_card(handle, id, local) do
    case env_hit(local) || file_hit(local) || txt_hit(id) do
      {:error, _} = err ->
        err

      %{url: _} = hit ->
        {:ok, attach(handle, id, local, decorate_txt(hit, id))}

      nil ->
        case @mocks[id] || @mocks[local <> "@mazel"] do
          nil ->
            {:error, :unknown_handle}

          url ->
            {:ok,
             attach(handle, id, local, decorate_txt(%{url: url, source: :mock, card: nil}, id))}
        end
    end
  end

  defp txt_hit(id) do
    case Room.Dns.txt_for(id) do
      {:ok, record} ->
        attrs = Room.Dns.parse_txt(record.data)

        case attrs.card_urls do
          [url | _] ->
            %{
              url: url,
              source: :txt,
              card: nil,
              haah: attrs.haah,
              txt: record.data,
              qname: record.owner
            }

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  defp decorate_txt(%{txt: _} = hit, _id), do: hit

  defp decorate_txt(hit, id) do
    case Room.Dns.txt_for(id) do
      {:ok, record} ->
        attrs = Room.Dns.parse_txt(record.data)

        hit
        |> Map.put(:haah, attrs.haah)
        |> Map.put(:txt, record.data)
        |> Map.put(:qname, record.owner)

      _ ->
        Map.put(hit, :haah, false)
    end
  end

  defp attach(handle, id, local, hit) do
    canon = if Map.has_key?(@mocks, id), do: id, else: local <> "@mazel"

    handle
    |> Map.put(:id, canon)
    |> Map.put(:card_url, hit.url)
    |> Map.put(:source, hit.source)
    |> Map.put(:card, hit[:card])
    |> Map.put(:need, Room.A2aPeerCard.need(hit[:card]))
    |> Map.put(:have, Room.A2aPeerCard.have(hit[:card]))
    |> Map.put(:haah, hit[:haah] == true)
    |> Map.put(:txt, hit[:txt])
    |> Map.put(:qname, hit[:qname])
  end

  defp env_hit(local) do
    case System.get_env(env_key(local)) do
      nil ->
        nil

      "" ->
        nil

      value ->
        value = String.trim(value)
        path = resolve_path(value)

        cond do
          File.regular?(path) ->
            file_payload(path, :env)

          String.starts_with?(value, "http://") or String.starts_with?(value, "https://") ->
            %{url: value, source: :env, card: nil}

          true ->
            %{url: value, source: :env, card: nil}
        end
    end
  end

  defp file_hit(local) do
    path = Path.join(cards_dir(), local <> ".json")

    if File.regular?(path) do
      file_payload(path, :file)
    end
  end

  defp file_payload(path, source) do
    case File.read(path) do
      {:ok, raw} ->
        case Jason.decode(raw) do
          {:ok, map} when is_map(map) ->
            case validate(map) do
              :ok ->
                %{url: map["url"] || map["card_url"], source: source, card: map}

              {:error, reason} ->
                {:error, {:invalid_card, path, reason}}
            end

          {:ok, _} ->
            {:error, {:invalid_card, path, :not_a_map}}

          {:error, _} ->
            {:error, {:invalid_card, path, :invalid_json}}
        end

      _ ->
        nil
    end
  end

  defp usable_string?(value) when is_binary(value), do: String.trim(value) != ""
  defp usable_string?(_), do: false

  defp resolve_path(value) do
    value = String.trim_leading(value, "file:")

    if Path.type(value) == :relative do
      Path.expand(value, repo_root())
    else
      value
    end
  end

  defp local_name(id), do: id |> String.split("@") |> hd()

  defp ensure_dotenv do
    if Process.get({__MODULE__, :dotenv}) do
      :ok
    else
      Process.put({__MODULE__, :dotenv}, true)
      load_dotenv()
    end
  end

  defp load_dotenv do
    if function_exported?(Mix, :env, 0) and Mix.env() == :test do
      :ok
    else
      load_dotenv_files()
    end
  end

  defp load_dotenv_files do
    for path <- dotenv_paths(), File.regular?(path) do
      path
      |> File.read!()
      |> String.split("\n")
      |> Enum.each(&put_env_line/1)
    end

    :ok
  end

  defp dotenv_paths do
    [Path.join(File.cwd!(), ".env"), Path.join(repo_root(), ".env")]
    |> Enum.uniq()
  end

  defp put_env_line(line) do
    line = String.trim(line)

    cond do
      line == "" ->
        :ok

      String.starts_with?(line, "#") ->
        :ok

      true ->
        line = String.replace_leading(line, "export ", "")

        case String.split(line, "=", parts: 2) do
          [key, value] ->
            key = String.trim(key)
            value = value |> String.trim() |> String.trim("\"") |> String.trim("'")

            if key != "" and is_nil(System.get_env(key)) do
              System.put_env(key, value)
            end

          _ ->
            :ok
        end
    end
  end
end
