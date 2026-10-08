defmodule Room.Open do
  @moduledoc """
  Live TTL openness. 🪽 `@open` — "ping me for X".

  Proof Has advertises an Open. Needs pull live Opens (and Has).
  Expired Opens match nothing. Curious never matches.
  Not a Direct. Not a Need. JIT-matches live needs (and needs JIT-match live opens).
  """

  @default_ttl_hours 72
  @wing "🪽"

  def sink?(%{id: id}), do: sink_id?(id)

  def sink?(raw) when is_binary(raw) do
    case Room.Wings.parse_handle(raw) do
      {:ok, handle} -> sink_id?(handle.id)
      _ -> false
    end
  end

  def sink_id?(id) when is_binary(id) do
    id in ~w(open@mazel open@mazel.ai open@mazal.ai)
  end

  def dispatch(body, opts \\ []) when is_binary(body) do
    body = String.trim(body)

    if body == "" do
      {:error, :empty_text}
    else
      ttl = Room.Index.ttl_hours(Keyword.get(opts, :ttl_hours), @default_ttl_hours)
      now = Keyword.get(opts, :now) || DateTime.utc_now() |> DateTime.truncate(:second)
      as_of = DateTime.to_date(now) |> Date.to_iso8601()
      expires_at = DateTime.add(now, ttl * 3600, :second) |> DateTime.to_iso8601()
      topic = Keyword.get(opts, :topic) || Room.Index.topic_from(body)
      suffix = Keyword.get(opts, :id_suffix) || random_id()
      open_id = Keyword.get(opts, :open_id) || "open-#{topic}-#{suffix}"
      handle = Keyword.get(opts, :handle, "kai@mazel")
      sink = Keyword.get(opts, :sink, "open@mazel")
      root = Keyword.get(opts, :root) || Room.Index.repo_root()

      open = %{
        id: open_id,
        kind: "open",
        topic: topic,
        title: "Open: #{topic}",
        body: body,
        as_of: as_of,
        ttl_hours: ttl,
        expires_at: expires_at,
        handle: handle,
        sink: sink
      }

      path = Room.Index.write(root, open)
      matches = match(open, root, now)
      badge = mint_badge(open, matches)

      {:ok,
       Map.merge(open, %{
         ok: true,
         open_id: open_id,
         path: path,
         matches: matches,
         badge: badge,
         expired: false
       })}
    end
  end

  def match(open, root \\ nil, now \\ nil) do
    root = root || Room.Index.repo_root()
    now = now || DateTime.utc_now()

    if Room.Index.expired?(open, now) do
      []
    else
      root
      |> Room.Index.load("need")
      |> Room.Index.live(now)
      |> then(&Room.Index.rank(open, &1))
    end
  end

  def expired?(open, now), do: Room.Index.expired?(open, now)

  def wing_mark, do: @wing

  @doc """
  Proof Has advertises a live TTL Open. Card skills are not Has.
  """
  def from_has(raw, opts \\ []) do
    root = Keyword.get(opts, :root) || Room.Index.repo_root()
    handle = handle_of(raw)

    case Room.Has.skills_for(handle, root: root) do
      [] ->
        {:error, :no_has}

      skills ->
        advertised = Keyword.get(opts, :skills) || skills
        topic = Keyword.get(opts, :topic) || List.first(advertised)
        ping = Keyword.get(opts, :body) || "ping me for #{Enum.join(advertised, ", ")}"
        body = ping <> "\n\nwants: #{Enum.join(advertised, ", ")}"

        dispatch_opts =
          opts
          |> Keyword.put(:handle, handle)
          |> Keyword.put(:topic, topic)
          |> Keyword.put(:root, root)
          |> Keyword.delete(:skills)
          |> Keyword.delete(:body)

        dispatch(body, dispatch_opts)
    end
  end

  @doc """
  Skills this Open advertises. Proof Has is the match inventory,
  not the open's boast text.
  """
  def advertised(open) when is_map(open) do
    body = to_string(open[:body] || open["body"] || "")
    topic = to_string(open[:topic] || open["topic"] || "")
    listed = List.wrap(open[:wants] || open["wants"] || open[:skills] || [])

    (listed ++ wants_from_body(body) ++ ids_in(topic) ++ ids_in(body))
    |> Enum.map(&to_string/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  @doc """
  Live Opens that overlap a Need. Overlap is
  need.wants ∩ advertised ∩ proof Has. Curious and expired skip.
  """
  def for_need(need, opts \\ []) do
    now = Keyword.get(opts, :now) || DateTime.utc_now()
    root = Keyword.get(opts, :root) || Room.Index.repo_root()
    wants = need_wants(need)

    cond do
      Room.Need.curious?(need) ->
        []

      Room.Need.expired?(need, now) ->
        []

      wants == [] ->
        []

      true ->
        root
        |> Room.Index.load("open")
        |> Room.Index.live(now)
        |> Enum.filter(&open_matches_need?(&1, wants, root))
    end
  end

  def match_need(need, opts \\ []) do
    root = Keyword.get(opts, :root) || Room.Index.repo_root()

    if Room.Need.curious?(need) do
      %{
        ok: false,
        error: "curious",
        skipped: true,
        handle: nil,
        matches: [],
        overlap: [],
        wants: need_wants(need),
        need_id: need[:id] || need["id"]
      }
    else
      opens = for_need(need, opts)
      handles = opens |> Enum.map(& &1.handle) |> Enum.reject(&is_nil/1) |> Enum.uniq()
      handle = List.first(handles)
      overlap = pair_overlap(need, handle, root)

      %{
        ok: handles != [],
        error: if(handles == [], do: "no_open", else: nil),
        handle: handle,
        matches: handles,
        opens: opens,
        overlap: overlap,
        wants: need_wants(need),
        need_id: need[:id] || need["id"]
      }
    end
  end

  def look_from_has(handle, rec) when is_map(rec) do
    ttl = rec[:expires_at] || rec["expires_at"] || "#{rec[:ttl_hours] || @default_ttl_hours}h"
    "ok  has→open  #{handle}  ttl=#{ttl}"
  end

  def look_need(match) when is_map(match) do
    "ok  need×open  match=#{match[:handle]}"
  end

  def look_expired(matches) when is_list(matches) do
    ids =
      Enum.map(matches, fn
        %{id: id} -> id
        %{handle: handle} -> handle
        other -> other
      end)

    "ok  expired open  matches=#{inspect(ids)}"
  end

  @doc """
  ADHD LOOK. Proof Has casts an Open; Need matches it; expired is empty.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} -> {given, false}
        :error -> {demo_root(), true}
      end

    try do
      demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp demo_on(root) do
    with {:ok, open} <- from_has("kai@mazel", root: root),
         {:ok, need} <- Room.Need.seed("founders-investors", root: root, now: DateTime.utc_now()) do
      match = match_need(need, root: root)

      cond do
        not match.ok or match.handle != "kai@mazel" ->
          {:error, :no_open_match}

        true ->
          {:ok, dead_open} =
            dispatch("ping me for ttl-dead",
              topic: "ttl-dead",
              handle: "kai@mazel",
              root: root,
              now: ~U[2020-01-01 00:00:00Z],
              ttl_hours: 1
            )

          dead = match(dead_open, root, DateTime.utc_now())

          curious = %{
            kind: "curious",
            status: "curious",
            wants: ["series-a", "cto"],
            id: "vibe"
          }

          curios_hit = match_need(curious, root: root)

          cond do
            dead != [] ->
              {:error, :expired_matched}

            curios_hit.ok ->
              {:error, :curious_matched}

            true ->
              {:ok, %{open: open, need: need, match: match, expired: dead, lines: look(open, need, match, dead)}}
          end
      end
    end
  end

  defp demo_root do
    root = Path.join(System.tmp_dir!(), "mazel-open-demo-#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, "index/opens"))
    File.mkdir_p!(Path.join(root, "index/needs"))
    File.mkdir_p!(Path.join(root, "index/has"))

    Enum.each(["kai.md", "nova.md"], fn name ->
      File.cp!(
        Path.join(Room.Index.repo_root(), Path.join("index/has", name)),
        Path.join(root, Path.join("index/has", name))
      )
    end)

    root
  end

  def look(open, need, match, expired_matches) do
    reasons =
      need
      |> Room.Need.pair_look(match)
      |> Enum.reject(&String.starts_with?(&1, "match  "))

    [look_from_has(open.handle, open), look_need(match)] ++ reasons ++ [look_expired(expired_matches)]
  end

  defp open_matches_need?(open, wants, root) do
    handle = open[:handle] || open["handle"]
    has = Room.Has.skills_for(handle, root: root)
    offered = advertised(open)
    Enum.any?(wants, &(&1 in offered and &1 in has))
  end

  defp pair_overlap(_need, nil, _root), do: []

  defp pair_overlap(need, handle, root) do
    has = Room.Has.skills_for(handle, root: root)
    Enum.filter(need_wants(need), &(&1 in has))
  end

  defp need_wants(need) do
    need
    |> then(&List.wrap(&1[:wants] || &1["wants"]))
    |> Enum.map(&to_string/1)
  end

  defp wants_from_body(body) do
    body
    |> String.split(~r/\r?\n/)
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&String.starts_with?(String.downcase(&1), "wants:"))
    |> Enum.flat_map(fn line ->
      line
      |> String.replace(~r/^wants:\s*/i, "")
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
    end)
  end

  defp ids_in(text) do
    hay = String.downcase(to_string(text))

    Enum.filter(Room.Has.skill_ids(), fn id ->
      String.contains?(hay, id) or String.contains?(hay, String.replace(id, "-", " "))
    end)
  end

  defp handle_of(raw) do
    case Room.Cards.lookup(to_string(raw)) do
      {:ok, found} ->
        found.id

      _ ->
        trimmed = raw |> to_string() |> String.trim() |> String.trim_leading("@")
        if String.contains?(trimmed, "@"), do: trimmed, else: trimmed <> "@mazel"
    end
  end

  defp mint_badge(open, matches) do
    case Room.Badge.from_open_matches(open, matches) do
      {:ok, badge} -> badge
      _ -> nil
    end
  end

  defp random_id do
    :crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)
  end
end
