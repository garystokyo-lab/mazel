defmodule Room.Wings do
  @moduledoc """
  Parses 🪽 / mazel commands, resolves handles, opens a session.

  Demo auto-consents and commits so Ariel can see the timeline + warm packet.
  """

  @speaker_raw "@ariel"

  def parse(message) when is_binary(message) do
    trimmed = String.trim(message)
    {stripped, had_verb} = strip_mazel_verb(trimmed)
    {stripped, kind_word} = if had_verb, do: take_kind_word(stripped), else: {stripped, nil}
    {count, rest} = take_wings(stripped, 0)
    {count, rest} = apply_kind_word(kind_word, count, had_verb, rest)
    rest = String.trim_leading(rest)

    with {:ok, kind} <- kind_from_count(count),
         {:ok, raws, text} <- split_targets(rest, kind) do
      parsed = Enum.map(raws, &parse_handle/1)

      case Enum.find(parsed, &match?({:error, _}, &1)) do
        {:error, reason} ->
          {:error, reason}

        nil ->
          targets = Enum.map(parsed, fn {:ok, handle} -> handle end)

          {:ok,
           %{
             session_kind: kind,
             target: hd(targets),
             targets: targets,
             text: text,
             raw: trimmed,
             verb: had_verb
           }}
      end
    end
  end

  def parse_handle(raw), do: do_parse_handle(raw)

  def resolve(handle), do: Room.Cards.lookup(handle)

  def run(message, opts \\ []) do
    speaker_raw = Keyword.get(opts, :from, @speaker_raw)
    context_id = Keyword.get(opts, :context_id) || "wing-" <> random_id()

    with {:ok, cmd} <- parse(message) do
      cond do
        Room.Open.sink?(cmd.target) ->
          Room.Open.dispatch(cmd.text,
            sink: cmd.target.id,
            handle: speaker_handle(speaker_raw),
            ttl_hours: Keyword.get(opts, :ttl_hours, 72),
            root: Keyword.get(opts, :root)
          )

        Room.Need.discovery_sink?(cmd.target) ->
          Room.Need.dispatch(cmd.text,
            sink: cmd.target.id,
            ttl_hours: Keyword.get(opts, :ttl_hours, 72),
            root: Keyword.get(opts, :root),
            actor: Keyword.get(opts, :actor) || Keyword.get(opts, :from) || speaker_handle(speaker_raw)
          )

        true ->
          with {:ok, speaker} <- resolve(speaker_raw),
               {:ok, peers} <- resolve_targets(cmd) do
            play(context_id, cmd, speaker, peers)
          end
      end
    end
  end

  def print(messages) when is_list(messages) do
    IO.puts("""

    ── Mazel wings ──────────────────────────────────────
    🪽 @kai hello. Then mazel'd @kai.
    ─────────────────────────────────────────────────────
    """)

    Enum.each(messages, fn message ->
      case run(message) do
        {:ok, %{open_id: _} = open} -> print_open(message, open)
        {:ok, %{need_id: _} = need} -> print_need(message, need)
        {:ok, result} -> print_one(message, result)
        {:error, reason} -> IO.puts("in   #{message}\nerr  #{inspect(reason)}\n")
      end
    end)
  end

  defp play(context_id, cmd, speaker, peers) do
    kind = cmd.session_kind
    topic = topic_stub(kind)
    target = hd(peers)

    people =
      [speaker | peers]
      |> Enum.uniq_by(& &1.id)
      |> Enum.map(&%{handle: &1, role: :agent})

    {:ok, _} = Room.open(context_id, kind, people)

    badge = group_or_pull_badge(kind, speaker, target, cmd.text, topic)

    {:ok, _} = Room.submit_badge(context_id, badge)
    {:ok, _} = Room.propose_morph(context_id, speaker)

    Enum.each(people, fn %{handle: handle} ->
      {:ok, _} = Room.consent(context_id, handle)
    end)

    summary =
      case kind do
        :direct -> "Direct wing. #{speaker.id} said hello through the agent."
        :intro -> "Intro wing. #{speaker.id} opened #{target.id} with: #{cmd.text}"
        :group -> "Group wing. #{speaker.id} invited #{Enum.map_join(peers, ", ", & &1.id)}."
      end

    {:ok, state} = Room.commit_morph(context_id, summary, transcript(speaker, target, cmd.text))

    {:ok,
     %{
       command: cmd,
       speaker: speaker,
       target: target,
       peers: peers,
       state: state
     }}
  end

  defp resolve_targets(%{targets: targets}) when is_list(targets) and targets != [] do
    Enum.reduce_while(targets, {:ok, []}, fn raw, {:ok, acc} ->
      id = if is_map(raw), do: raw.id, else: raw

      case resolve(id) do
        {:ok, found} -> {:cont, {:ok, acc ++ [found]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp resolve_targets(%{target: target}), do: resolve_targets(%{targets: [target]})

  defp group_or_pull_badge(:group, speaker, _target, text, _topic) do
    %{
      kind: "invite_token",
      issuer: speaker,
      token: "group-invite-v0",
      note: text
    }
  end

  defp group_or_pull_badge(kind, speaker, target, text, topic) do
    %{
      kind: "pull_intent",
      actor: speaker,
      intent: "#{Room.Types.wing_mark(kind)} #{target.id} #{text} (#{topic})",
      topic: topic
    }
  end

  defp print_one(message, %{command: cmd, speaker: speaker, target: target, state: state}) do
    IO.puts("in       #{message}")

    IO.puts(
      "parse    #{Room.Labels.format(cmd.session_kind)} #{Room.Types.wing_mark(cmd.session_kind)}  #{target.id}"
    )

    IO.puts("resolve  #{target.id}  →  #{target.card_url}")
    IO.puts("from     #{speaker.id}  →  #{speaker.card_url}")
    IO.puts("context  #{state.context_id}")
    IO.puts("status   #{state.status}  dual=#{state.dual_consent}")
    IO.puts("events")

    Enum.each(state.events, fn event ->
      IO.puts("  • #{Room.Labels.format(event.type)}")
    end)

    IO.puts(Room.Labels.format(:warm_packet))
    IO.puts(Jason.encode!(state.warm_packet, pretty: true))
    IO.puts("")
  end

  defp print_open(message, open) do
    IO.puts("in       #{message}")
    IO.puts("parse    #{Room.Labels.format(:open)}  →  #{open.sink}  (not a person)")
    IO.puts("#{Room.Labels.format(:open)}     #{open.open_id}")
    IO.puts("handle   #{open.handle}")
    IO.puts("ttl      #{open.ttl_hours}h  expires #{open.expires_at}")
    IO.puts("topic    #{open.topic}")
    IO.puts("wrote    #{open.path}")
    print_matches(open.matches)
    IO.puts("")
  end

  defp print_need(message, need) do
    IO.puts("in       #{message}")
    IO.puts("parse    #{Room.Labels.format(:discovery)}  →  #{need.sink}  (not a person)")
    IO.puts("#{Room.Labels.format(:need)}     #{need.need_id}")
    IO.puts("ttl      #{need.ttl_hours}h  expires #{need.expires_at}")
    IO.puts("topic    #{need.topic}")
    IO.puts("wrote    #{need.path}")
    print_matches(need.matches)
    IO.puts("")
  end

  defp print_matches([]), do: IO.puts("matches\n  (none)")

  defp print_matches(rows) do
    IO.puts("matches")

    Enum.each(rows, fn row ->
      kind = row[:kind] || row["kind"] || "know"
      handle = row[:handle] || row["handle"]
      who = if handle, do: "  #{handle}", else: ""

      IO.puts(
        "  • #{kind}  #{row.id}  score=#{:erlang.float_to_binary(row.score / 1, decimals: 2)}  topic=#{row.topic}#{who}"
      )
    end)
  end

  defp speaker_handle(raw) do
    case parse_handle(raw) do
      {:ok, handle} -> handle.id
      _ -> "ariel@mazel"
    end
  end

  defp transcript(speaker, target, text) do
    [
      %{speaker: speaker, text: text},
      %{speaker: target, text: "Agent got it. Morph when the humans need to step in."}
    ]
  end

  # Wing is literal 🪽. Wire ids stay direct / intro. Verb is mazel.
  defp strip_mazel_verb(text) do
    down = String.downcase(text)

    if String.starts_with?(down, "mazel") do
      rest = binary_part(text, 5, byte_size(text) - 5)

      cond do
        rest == "" ->
          {"", true}

        String.starts_with?(rest, " ") or String.starts_with?(rest, "\t") ->
          {String.trim_leading(rest), true}

        String.starts_with?(rest, "🪽") ->
          {rest, true}

        true ->
          {text, false}
      end
    else
      {text, false}
    end
  end

  defp take_kind_word(text) do
    case String.split(String.trim_leading(text), ~r/\s+/, parts: 2) do
      [word, rest] ->
        case String.downcase(word) do
          "intro" -> {rest, :intro}
          "group" -> {rest, :group}
          "need" -> {rest, :need}
          "direct" -> {rest, :direct}
          _ -> {text, nil}
        end

      _ ->
        {text, nil}
    end
  end

  defp apply_kind_word(:intro, _count, _had_verb, rest), do: {2, rest}
  defp apply_kind_word(:group, _count, _had_verb, rest), do: {3, rest}
  defp apply_kind_word(:direct, _count, _had_verb, rest), do: {1, rest}

  defp apply_kind_word(:need, _count, _had_verb, rest) do
    rest = String.trim_leading(to_string(rest))
    rest = if looks_like_handle?(rest), do: rest, else: "@mazel " <> rest
    {1, rest}
  end

  defp apply_kind_word(nil, 0, true, rest), do: {1, rest}
  defp apply_kind_word(nil, count, _had_verb, rest), do: {count, rest}

  defp looks_like_handle?(rest) do
    first = rest |> String.split(~r/\s+/, parts: 2) |> hd()
    String.starts_with?(first, "@") or String.contains?(first, "@")
  end

  defp take_wings(<<"🪽", rest::binary>>, n), do: take_wings(rest, n + 1)
  defp take_wings(rest, n), do: {n, rest}

  defp kind_from_count(1), do: {:ok, :direct}
  defp kind_from_count(2), do: {:ok, :intro}
  defp kind_from_count(3), do: {:ok, :group}
  defp kind_from_count(_), do: {:error, :not_a_wing}

  defp split_targets(rest, :group) do
    tokens = String.split(String.trim_leading(rest))
    {raws, text_parts} = Enum.split_while(tokens, &handle_token?/1)

    cond do
      length(raws) < 2 ->
        {:error, :need_invitees}

      text_parts == [] ->
        {:error, :incomplete}

      true ->
        {:ok, raws, Enum.join(text_parts, " ")}
    end
  end

  defp split_targets(rest, _kind) do
    case String.split(rest, ~r/\s+/, parts: 2) do
      [handle, text] ->
        text = String.trim(text)
        if text == "", do: {:error, :incomplete}, else: {:ok, [handle], text}

      _ ->
        {:error, :incomplete}
    end
  end

  defp handle_token?(token) do
    String.starts_with?(token, "@") or String.contains?(token, "@")
  end

  defp do_parse_handle(raw) do
    raw = String.trim(raw)

    cond do
      raw == "" ->
        {:error, :malformed_handle}

      String.starts_with?(raw, "@") ->
        Room.Types.handle(String.downcase(String.trim_leading(raw, "@")) <> "@mazel")

      String.contains?(raw, "@") ->
        Room.Types.handle(String.downcase(raw))

      true ->
        {:error, :malformed_handle}
    end
  end

  defp topic_stub(:direct), do: "direct-wing"
  defp topic_stub(:intro), do: "intro-wing"
  defp topic_stub(:group), do: "group"

  defp random_id do
    :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
  end
end
