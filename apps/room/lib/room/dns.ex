defmodule Room.Dns do
  @moduledoc """
  BIND-lite zone fixture. TXT `mazel-card=<url>` optional `mazel-haah=1`.
  No live DNS. Same records as `fixtures/dns/mazel.ai.zone`.
  """

  def zone_path do
    case System.get_env("MAZEL_ZONE") do
      path when is_binary(path) and path != "" -> path
      _ -> Path.join(Room.Index.repo_root(), "fixtures/dns/mazel.ai.zone")
    end
  end

  def load(path \\ zone_path()) do
    case File.read(path) do
      {:ok, text} -> parse(text)
      {:error, reason} -> {:error, {:zone_io, path, reason}}
    end
  end

  def load!(path \\ zone_path()) do
    case load(path) do
      {:ok, zone} -> zone
      {:error, reason} -> raise "zone load failed: #{inspect(reason)}"
    end
  end

  def parse(text) when is_binary(text) do
    {origin, ttl, records} =
      text
      |> String.split("\n")
      |> Enum.with_index(1)
      |> Enum.reduce({"mazel.ai", 300, []}, fn {raw, line_no}, {origin, ttl, records} ->
        case tokenize(raw) do
          [] ->
            {origin, ttl, records}

          ["$ORIGIN", name | _] ->
            {fqdn(name, "mazel.ai"), ttl, records}

          ["$TTL", value | _] ->
            {origin, parse_ttl(value, ttl), records}

          ["$" <> _ | _] ->
            {origin, ttl, records}

          tokens ->
            case parse_record(tokens, origin, ttl) do
              {:ok, record} -> {origin, ttl, records ++ [record]}
              :skip -> {origin, ttl, records}
              {:error, reason} -> throw({:zone_parse, line_no, reason})
            end
        end
      end)

    {:ok, %{origin: origin, ttl: ttl, records: records}}
  catch
    {:zone_parse, line_no, reason} -> {:error, {:zone_parse, line_no, reason}}
  end

  def lookup(raw, zone \\ nil)

  def lookup(raw, nil) when is_binary(raw) do
    case load() do
      {:ok, zone} -> lookup(raw, zone)
      error -> error
    end
  end

  def lookup(raw, zone) when is_binary(raw) and is_map(zone) do
    case Room.Wings.parse_handle(raw) do
      {:ok, handle} -> lookup_handle(handle, zone)
      {:error, :malformed_handle} -> {:error, :malformed_handle}
      error -> error
    end
  end

  def reset do
    Process.get_keys()
    |> Enum.filter(&match?({__MODULE__, :zone, _}, &1))
    |> Enum.each(&Process.delete/1)

    :ok
  end

  @doc """
  Zone TXT reader. Not a second resolver — `Room.Cards.lookup` is the path.
  """
  def txt_for(raw, zone \\ nil)

  def txt_for(raw, nil) when is_binary(raw) do
    case cached_zone() do
      {:ok, zone} -> txt_for(raw, zone)
      error -> error
    end
  end

  def txt_for(raw, zone) when is_binary(raw) and is_map(zone) do
    txt_record(raw, zone)
  end

  def mock_dig(raw, zone \\ nil)

  def mock_dig(raw, nil) when is_binary(raw) do
    case load() do
      {:ok, zone} -> mock_dig(raw, zone)
      {:error, reason} -> ";; mock dig failed  #{inspect(reason)}\n"
    end
  end

  def mock_dig(raw, zone) when is_binary(raw) and is_map(zone) do
    qname = primary_qname(raw)

    case txt_record(raw, zone) do
      {:ok, record} ->
        """
        ;; mock dig TXT #{qname}.  (fixture, no network)
        ;; ANSWER
        #{record.owner}.  #{record.ttl}  IN  TXT  "#{record.data}"
        """

      {:error, _} ->
        """
        ;; mock dig TXT #{qname}.  (fixture, no network)
        ;; ANSWER
        ;; (no TXT)
        """
    end
  end

  def parse_txt(record) when is_binary(record) do
    record
    |> String.split(~r/\s+/, trim: true)
    |> Enum.reduce(%{card_urls: [], haah: false}, fn part, acc ->
      part = part |> String.trim() |> String.trim("\"") |> String.trim(";")

      cond do
        String.starts_with?(String.downcase(part), "mazel-card=") ->
          url = part |> String.split("=", parts: 2) |> List.last() |> String.trim("\"")

          if String.starts_with?(url, "http://") or String.starts_with?(url, "https://") do
            urls = acc.card_urls ++ if(url in acc.card_urls, do: [], else: [url])
            %{acc | card_urls: urls}
          else
            acc
          end

        String.starts_with?(String.downcase(part), "mazel-haah=") ->
          flag = part |> String.split("=", parts: 2) |> List.last() |> String.downcase()
          %{acc | haah: flag in ~w(1 true yes)}

        true ->
          acc
      end
    end)
  end

  defp cached_zone do
    key = {__MODULE__, :zone, zone_path()}

    case Process.get(key) do
      nil ->
        case load() do
          {:ok, zone} ->
            Process.put(key, zone)
            {:ok, zone}

          error ->
            error
        end

      zone ->
        {:ok, zone}
    end
  end

  defp lookup_handle(handle, zone) do
    case txt_record(handle.id, zone) do
      {:ok, record} ->
        attrs = parse_txt(record.data)

        case attrs.card_urls do
          [url | _] ->
            {:ok,
             %{
               handle: handle.id,
               card_url: url,
               card_urls: attrs.card_urls,
               haah: attrs.haah,
               source: :txt,
               qname: record.owner,
               ttl: record.ttl,
               txt: record.data
             }}

          [] ->
            {:error, :unknown_handle}
        end

      {:error, _} ->
        {:error, :unknown_handle}
    end
  end

  defp txt_record(raw, zone) do
    case Room.Wings.parse_handle(raw) do
      {:ok, handle} ->
        names = qnames(handle)

        case Enum.find(zone.records, fn rec ->
               rec.rtype == "TXT" and
                 Enum.any?(names, fn name ->
                   name == rec.owner or name == first_label(rec.owner)
                 end)
             end) do
          nil -> {:error, :unknown_handle}
          record -> {:ok, record}
        end

      error ->
        error
    end
  end

  defp parse_record(tokens, origin, default_ttl) do
    [name | rest] = tokens

    {ttl, rest} =
      case rest do
        [maybe_ttl | tail] ->
          case Integer.parse(maybe_ttl) do
            {n, ""} -> {n, tail}
            _ -> {default_ttl, rest}
          end

        _ ->
          {default_ttl, rest}
      end

    rest =
      case rest do
        [class | tail] ->
          if String.upcase(class) == "IN", do: tail, else: rest

        _ ->
          rest
      end

    case rest do
      [rtype | data_parts] ->
        rtype = String.upcase(rtype)

        if rtype != "TXT" do
          :skip
        else
          data = Enum.join(data_parts, " ")

          if data == "" do
            {:error, :empty_txt}
          else
            {:ok, %{owner: fqdn(name, origin), ttl: ttl, rtype: rtype, data: data}}
          end
        end

      _ ->
        {:error, :short_record}
    end
  end

  defp tokenize(line) do
    line
    |> String.to_charlist()
    |> Enum.reduce({:out, [], []}, fn
      ?", {:out, cur, acc} ->
        {:in, cur, acc}

      ?", {:in, cur, acc} ->
        {:out, cur, acc}

      ?;, {:out, cur, acc} ->
        {:done, cur, acc}

      c, {:out, cur, acc} ->
        if c in ~c" \t" do
          {:out, [], flush(cur, acc)}
        else
          {:out, [c | cur], acc}
        end

      _c, {:done, cur, acc} ->
        {:done, cur, acc}

      c, {:in, cur, acc} ->
        {:in, [c | cur], acc}
    end)
    |> then(fn {_, cur, acc} -> flush(cur, acc) end)
    |> Enum.reverse()
  end

  defp flush([], acc), do: acc
  defp flush(cur, acc), do: [cur |> Enum.reverse() |> List.to_string() | acc]

  defp fqdn(name, origin) do
    name = name |> String.trim() |> String.trim_trailing(".") |> String.downcase()
    origin = origin |> String.trim() |> String.trim_trailing(".") |> String.downcase()

    cond do
      name in ["", "@"] -> origin
      name == origin or String.ends_with?(name, "." <> origin) -> name
      true -> name <> "." <> origin
    end
  end

  defp qnames(handle) do
    local = local_name(handle.id)
    zone = zone_name(handle.id)

    [local, local <> "." <> zone, primary_qname(handle.id)]
    |> Enum.uniq()
  end

  defp primary_qname(raw) do
    case Room.Wings.parse_handle(raw) do
      {:ok, handle} ->
        local = local_name(handle.id)
        zone = zone_name(handle.id)

        if zone in ~w(mazel mazal) do
          local <> "." <> zone <> ".ai"
        else
          local <> "." <> zone
        end

      _ ->
        raw
    end
  end

  defp first_label(name), do: name |> String.split(".") |> hd()
  defp local_name(id), do: id |> String.split("@") |> hd()
  defp zone_name(id), do: id |> String.split("@") |> List.last()

  defp parse_ttl(value, default) do
    case Integer.parse(value) do
      {n, _} -> n
      :error -> default
    end
  end
end
