defmodule Mix.Tasks.Mazel do
  @shortdoc "Verb: mazel @kai hello / wing text → session or sink"
  @moduledoc """
  The product verb. Parses `mazel @kai hello` or wing text. No messenger.

      mix mazel @kai hello
      mix mazel intro @kai series-A CTO
      mix mazel need series-A CTO
      mix mazel find chat
      mix mazel has @kai
      mix mazel has --gh priv/fixtures/kai.github.txt @kai
      mix mazel has --resume priv/fixtures/kai.resume.conflict.txt @kai
      mix mazel resolve @kai
      ./mazel intro @kai series-A CTO
  """
  use Mix.Task

  @impl true
  def run(["find" | queries]) do
    System.put_env("MAZEL_HTTP", "0")
    Mix.Task.run("app.start")
    find_cmd(queries)
  end

  @impl true
  def run(["has", "--resume", path | rest]) do
    System.put_env("MAZEL_HTTP", "0")
    Mix.Task.run("app.start")
    resume_cmd(path, rest)
  end

  @impl true
  def run(["has", "--gh", path | rest]) do
    System.put_env("MAZEL_HTTP", "0")
    Mix.Task.run("app.start")
    github_cmd(path, rest)
  end

  @impl true
  def run(["has" | rest]) do
    System.put_env("MAZEL_HTTP", "0")
    Mix.Task.run("app.start")
    has_cmd(rest)
  end

  @impl true
  def run(["resolve" | handles]) do
    System.put_env("MAZEL_HTTP", "0")
    Mix.Task.run("app.start")
    resolve_cmd(handles)
  end

  @impl true
  def run(args) do
    System.put_env("MAZEL_HTTP", "0")
    Mix.Task.run("app.start")

    text = normalize_input(Enum.join(args, " "))

    IO.puts("""

    ── Mazel ────────────────────────────────────────────
    Verb first. HAAH on A2A. No messenger.
    ─────────────────────────────────────────────────────
    """)

    case Room.Wings.run(text, context_id: "mazel-" <> random_id()) do
      {:ok, %{open_id: _} = open} ->
        IO.puts(
          "ok  verb=mazel  kind=open  open=#{open.open_id}  topic=#{open.topic}  handle=#{open.handle}"
        )

      {:ok, %{need_id: _} = need} ->
        IO.puts("ok  verb=mazel  kind=need  need=#{need.need_id}  topic=#{need.topic}")

      {:ok, %{command: _cmd, target: target, state: _state}} ->
        IO.puts("ok  #{Room.Find.mazel_d(target.id)}")

      {:error, reason} ->
        IO.puts("err  #{format_error(reason)}")
        Mix.raise("mazel failed (no fake success)")
    end
  end

  defp resume_cmd(path, rest) do
    handle = rest |> Enum.join(" ") |> String.trim()
    handle = if handle == "", do: "@kai", else: handle

    case Room.Has.seed_resume(path, handle: handle) do
      {:ok, rec} ->
        IO.puts(Room.Has.candidate_line(rec))
        Enum.each(Room.Has.look(rec), &IO.puts/1)
        :ok

      {:error, reason} ->
        IO.puts("ok=false  has=#{path}  error=#{error_id(reason)}")
        Mix.raise("mazel has --resume failed (#{error_id(reason)})")
    end
  end

  defp github_cmd(path, rest) do
    handle = rest |> Enum.join(" ") |> String.trim()
    handle = if handle == "", do: "@kai", else: handle

    case Room.Has.seed_github(path, handle: handle) do
      {:ok, rec} ->
        IO.puts(Room.Has.candidate_line(rec))
        Enum.each(Room.Has.look(rec), &IO.puts/1)
        :ok

      {:error, reason} ->
        IO.puts("ok=false  has=#{path}  error=#{error_id(reason)}")
        Mix.raise("mazel has --gh failed (#{error_id(reason)})")
    end
  end

  defp has_cmd(rest) do
    target = rest |> Enum.join(" ") |> String.trim()
    target = if target == "", do: "@kai", else: target

    result =
      if String.starts_with?(target, "http://") or String.starts_with?(target, "https://") or
           String.starts_with?(target, "file:") or File.regular?(target) do
        Room.Has.seed(target)
      else
        Room.Has.seed_card(target)
      end

    case result do
      {:ok, has} ->
        Enum.each(Room.Has.look(has), &IO.puts/1)
        :ok

      {:error, reason} ->
        IO.puts("ok=false  has=#{target}  error=#{error_id(reason)}")
        Mix.raise("mazel has failed (#{error_id(reason)})")
    end
  end

  defp error_id(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp error_id({:http_status, status}), do: "http_#{status}"
  defp error_id(_), do: "error"

  defp find_cmd(queries) do
    query = queries |> Enum.join(" ") |> String.trim()
    query = if query == "", do: "chat", else: query

    {:ok, found} = Room.Find.query(query)

    if found.ok do
      Enum.each(found.hits, fn hit ->
        IO.puts(
          "#{String.pad_trailing(hit.handle, 16)}  skills=#{Enum.join(hit.skills, ",")}  card=#{hit.card_url}"
        )
      end)

      first = hd(found.hits)
      IO.puts("")

      IO.puts(find_look(found, first))
    else
      IO.puts("ok=false  find=#{found.query}  error=#{found.error}")
      if found.error != "no_skill", do: Mix.raise("mazel find failed (#{found.error})")
    end

    :ok
  end

  defp find_look(found, first) do
    if length(found.hits) == 1 do
      "ok  find=#{found.query}→#{first.handle}"
    else
      "ok  find=#{found.query}  kind=#{found.kind}  hits=#{length(found.hits)}  handle=#{first.handle}  skills=#{Enum.join(first.skills, ",")}"
    end
  end

  defp resolve_cmd(handles) do
    handles = if handles == [], do: ["@kai", "@ariel"], else: handles

    IO.puts("""

    ── Mazel resolve ────────────────────────────────────
    Same path as mix dns_demo. Zone TXT + file cards.
    ─────────────────────────────────────────────────────
    """)

    hits =
      Enum.map(handles, fn raw ->
        case Room.Cards.lookup(raw) do
          {:ok, found} ->
            IO.puts(
              "#{String.pad_trailing(raw, 14)}  → #{found.id}  card=#{found.card_url}  haah=#{haah_flag(found)}  source=#{source_line(found)}"
            )

            found

          {:error, :unknown_handle} ->
            IO.puts("#{String.pad_trailing(raw, 14)}  error=unknown_handle")
            nil

          {:error, reason} ->
            Mix.raise("mazel resolve failed (#{raw} #{inspect(reason)})")
        end
      end)

    ok = Enum.filter(hits, & &1)

    if ok == [] do
      Mix.raise("mazel resolve failed (no handle)")
    end

    [first | _] = ok
    extras = Enum.map(ok, fn h -> "#{local(h.id)}=#{h.id}" end) |> Enum.join("  ")

    IO.puts("")

    IO.puts(
      "ok  #{extras}  card=#{first.card_url}  haah=#{haah_flag(first)}  source=#{source_line(first)}"
    )

    :ok
  end

  defp haah_flag(found), do: if(found[:haah], do: "1", else: "0")

  defp source_line(found) do
    primary = found.source |> to_string()

    if is_binary(found[:txt]) and found.source != :txt do
      primary <> "+txt"
    else
      primary
    end
  end

  defp local(id), do: id |> String.split("@") |> hd()

  defp normalize_input(text) do
    t = String.trim(text)

    cond do
      t == "" ->
        "mazel @kai hello"

      String.starts_with?(String.downcase(t), "mazel") ->
        t

      String.starts_with?(t, "🪽") ->
        t

      true ->
        "mazel " <> t
    end
  end

  defp format_error(reason) when is_atom(reason), do: "error=#{reason}"
  defp format_error({:invalid_card, _path, reason}), do: "error=invalid_card  reason=#{reason}"
  defp format_error(reason), do: "error=#{inspect(reason)}"

  defp random_id do
    :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
  end
end
