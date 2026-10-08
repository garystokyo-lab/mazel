defmodule Room.SelfReportMatch do
  @moduledoc """
  MVP tag overlap from self-report. Not proof.

  Self-reported Has tags + self-reported Need tags. Exact
  overlap opens mazel'd agent chat. No PDF / GH / trail gate.
  Proof-path self-report stays curious. Off badge. Off wiki.
  """

  def look_has(rec \\ %{}) do
    tags = rec[:tags] || ["series-a"]
    "ok  has=self_report  tags=[#{Enum.join(List.wrap(tags), ",")}]"
  end

  def look_need(rec \\ %{}) do
    tags = rec[:tags] || ["series-a"]
    "ok  need=self_report  tags=[#{Enum.join(List.wrap(tags), ",")}]"
  end

  def look_find(rec \\ %{}) do
    peer = rec[:handle] || rec[:peer] || "kai@mazel"
    tag = rec[:query] || List.first(List.wrap(rec[:tags])) || "series-a"
    "ok  find=#{tag}→#{peer}  #{Room.Find.mazel_d(peer)}"
  end

  def look_complete, do: "ok  complete=agent  morph=none  session=agent"

  def look(pack) when is_map(pack) do
    [look_has(pack.has), look_need(pack.need), look_find(pack.hit), look_complete()]
  end

  def look(_), do: look(%{has: %{}, need: %{}, hit: %{}})

  @doc "In-memory self-report. Tags only. Never writes proof Has."
  def report(kind, tags, opts \\ [])

  def report(kind, tags, opts) when kind in [:has, :need, "has", "need"] and is_list(opts) do
    kind = to_string(kind)
    raw = List.wrap(tags)
    ids = normalize_tags(tags)
    default = if(kind == "has", do: "kai@mazel", else: nil)

    if ids == [] and Enum.any?(raw, &ws_only_tag?/1) do
      shown = Enum.map(raw, &to_string/1)
      reject_empty_tags(kind, Enum.join(shown, ","), shown)
    else
      %{
        ok: ids != [],
        kind: kind,
        source: "self_report",
        tags: ids,
        handle: Keyword.get(opts, :handle) || default,
        curious: false,
        unfit: false
      }
      |> attach_padded_trim(raw, ids)
    end
  end

  def report(_, _, _), do: curious()

  @doc "Parse an explicit tag line. Claim / vibe never yields tags."
  def parse(raw) when is_binary(raw) do
    text = String.trim(raw)
    down = String.downcase(text)

    cond do
      claim?(down) ->
        curious()

      String.starts_with?(down, "has:") ->
        report(:has, strip_prefix(text, "has:"))

      String.starts_with?(down, "need:") ->
        report(:need, strip_prefix(text, "need:"))

      true ->
        curious()
    end
  end

  def parse(_), do: curious()

  @doc """
  Cast a self-report Need or Has from free chat tags.
  Not parse(\"need: …\"). Claim / vibe → curious.
  No domain tags → reject empty_tags (Need or Has).
  """
  def cast(kind, chat, opts \\ [])

  def cast(kind, chat, _opts) when kind in [:curious, :claim, "curious", "claim"] and is_binary(chat) do
    kind = to_string(kind)
    mentioned = tags_from_chat(chat)

    curious()
    |> Map.merge(%{
      from: "chat",
      cast: kind,
      class: "curious",
      mentioned: mentioned,
      text: chat
    })
  end

  def cast(kind, chat, opts) when kind in [:need, :has, "need", "has"] and is_binary(chat) do
    kind = to_string(kind)
    down = String.downcase(chat)

    cond do
      claim?(down) ->
        curious() |> Map.merge(%{from: "chat", cast: kind})

      true ->
        tags = tags_from_chat(chat)
        padded = padded_skill_raw(chat)
        cased = cased_skill_raw(chat)

        cond do
          tags == [] ->
            shown = if(ws_only_tag?(chat), do: [chat], else: [])
            reject_empty_tags(kind, chat, shown)

          is_binary(padded) ->
            report(kind, [padded], opts)
            |> Map.merge(%{from: "chat", cast: kind, text: chat})
            |> attach_shape(opts)

          is_binary(cased) ->
            report(kind, [cased], opts)
            |> Map.merge(%{from: "chat", cast: kind, text: chat})
            |> attach_shape(opts)

          true ->
            report(kind, tags, opts)
            |> Map.merge(%{from: "chat", cast: kind, text: chat})
            |> attach_shape(opts)
        end
    end
  end

  def cast(_, _, _), do: curious() |> Map.put(:from, "chat")

  @doc """
  Recast replaces the prior Need tags. Fresh chat wins.
  Claim / empty tags never replace.
  """
  def recast(kind, chat, previous, opts \\ [])

  def recast(kind, chat, previous, opts) when is_map(previous) do
    fresh = cast(kind, chat, opts)
    replaced = List.wrap(previous[:tags])

    cond do
      fresh[:curious] == true or fresh[:ok] != true or fresh[:tags] == [] ->
        fresh

      replaced == [] ->
        Map.merge(fresh, %{recast: to_string(kind)})

      true ->
        Map.merge(fresh, %{
          recast: to_string(kind),
          replaces: replaced,
          replaced: hd(replaced)
        })
    end
  end

  def recast(_, _, _, _), do: curious() |> Map.put(:from, "chat")

  @doc """
  Replace live Has tags. Need stays. Claim / empty
  tags never replace. A Need rec is left alone.
  """
  def update_has(has, chat) when is_map(has) and is_binary(chat) do
    kind = to_string(has[:kind] || "has")

    cond do
      kind != "has" ->
        has

      true ->
        fresh = recast(:has, chat, has)

        if fresh[:curious] == true or fresh[:ok] != true or fresh[:tags] == [] do
          fresh
        else
          Map.merge(fresh, %{kind: "has", update: "has"})
        end
    end
  end

  def update_has(has, _) when is_map(has), do: has
  def update_has(_, _), do: curious()

  @doc """
  Replace live Need tags. Has stays. Claim / empty
  tags never replace. A Has rec is left alone.
  """
  def update_need(need, chat) when is_map(need) and is_binary(chat) do
    kind = to_string(need[:kind] || "need")

    cond do
      kind != "need" ->
        need

      true ->
        fresh = recast(:need, chat, need)

        if fresh[:curious] == true or fresh[:ok] != true or fresh[:tags] == [] do
          fresh
        else
          Map.merge(fresh, %{kind: "need", update: "need"})
        end
    end
  end

  def update_need(need, _) when is_map(need), do: need
  def update_need(_, _), do: curious()

  @doc """
  Drop Need tags. Find is none until a later recast.
  Curious stays curious. Never writes proof Has.
  """
  def clear(need) when is_map(need) do
    cond do
      need[:curious] == true ->
        need

      true ->
        kind = to_string(need[:kind] || "need")

        Map.merge(need, %{
          ok: false,
          kind: kind,
          tags: [],
          cleared: true,
          clear: kind,
          recast: nil,
          replaces: [],
          replaced: nil
        })
    end
  end

  def clear(_), do: curious()

  @doc """
  Drop Has tags. Need stays live. Find is none — no
  stale match. Curious stays curious. A Need rec is
  left alone.
  """
  def clear_has(has) when is_map(has) do
    kind = to_string(has[:kind] || "has")

    cond do
      has[:curious] == true ->
        has

      kind != "has" ->
        has

      true ->
        clear(Map.put(has, :kind, "has"))
    end
  end

  def clear_has(_), do: curious()

  @doc """
  Clear the live Need that carries `tag`. Other Needs stay
  live. Dropped tags are kept on the cleared rec for LOOK.
  """
  def clear_one(needs, tag) when is_list(needs) do
    want = tag |> to_string() |> String.trim() |> String.downcase()

    Enum.map(needs, fn need ->
      dropped = List.wrap(need[:tags])

      if want != "" and want in dropped do
        need
        |> clear()
        |> Map.put(:dropped, dropped)
      else
        need
      end
    end)
  end

  def clear_one(_, _), do: []

  @doc """
  Clear every live Need. Find is none on each until a
  later recast. Dropped tags stay on each rec for LOOK.
  """
  def clear_both(needs) when is_list(needs) do
    Enum.map(needs, fn need ->
      dropped = List.wrap(need[:tags])

      need
      |> clear()
      |> Map.put(:dropped, dropped)
    end)
  end

  def clear_both(_), do: []

  @vault "self_report"

  def vault_rel, do: @vault

  @doc """
  Remove a Has slice from the vault. After clear_has so
  find cannot stale-match. Need slices stay.
  """
  def drop(root, rec) when is_binary(root) and is_map(rec) do
    kind = to_string(rec[:kind] || "")

    if kind != "has" do
      {:error, :not_has}
    else
      dir = Path.join([root, "index", @vault])
      path = Path.join(dir, slice_name(rec))
      _ = File.rm(path)
      {:ok, clear_has(rec)}
    end
  end

  def drop(_, _), do: {:error, :not_has}

  @doc """
  Remove a Need slice from the vault. After update_need
  so find cannot stale-match the old tags. Has slices stay.
  """
  def drop_need(root, rec) when is_binary(root) and is_map(rec) do
    kind = to_string(rec[:kind] || "")

    if kind != "need" do
      {:error, :not_need}
    else
      dir = Path.join([root, "index", @vault])
      path = Path.join(dir, slice_name(rec))
      _ = File.rm(path)
      {:ok, rec}
    end
  end

  def drop_need(_, _), do: {:error, :not_need}

  @doc """
  Persist a self-report rec under index/self_report/.
  Never writes proof Has. Claim / vibe / empty tags never write.
  """
  def put(root, rec) when is_binary(root) and is_map(rec) do
    rec = check(rec)

    cond do
      rec[:curious] == true or rec[:unfit] == true or rec[:ok] != true ->
        {:error, :curious}

      List.wrap(rec[:tags]) == [] ->
        {:error, :curious}

      true ->
        dir = Path.join([root, "index", @vault])
        File.mkdir_p!(dir)
        name = slice_name(rec)
        File.write!(Path.join(dir, name), slice_md(rec))
        {:ok, Map.put(rec, :path, Path.join([@vault, name]))}
    end
  end

  def put(_, _), do: {:error, :curious}

  @doc "Load self-report slices. kind is :has / :need / :all."
  def vault(root, kind \\ :all)

  def vault(root, kind) when is_binary(root) do
    dir = Path.join([root, "index", @vault])

    rows =
      if File.dir?(dir) do
        dir
        |> File.ls!()
        |> Enum.filter(fn name -> String.ends_with?(name, ".md") end)
        |> Enum.map(&parse_vault(Path.join(dir, &1)))
        |> Enum.reject(&is_nil/1)
      else
        []
      end

    case kind do
      :all -> rows
      k when k in [:has, :need, "has", "need"] -> Enum.filter(rows, fn row -> row.kind == to_string(k) end)
      _ -> []
    end
  end

  def vault(_, _), do: []

  def vault_has_count(root) when is_binary(root) do
    root |> vault(:has) |> Enum.count(&live_has?/1)
  end

  def vault_has_count(_), do: 0

  def vault_need_count(root, now \\ DateTime.utc_now())

  def vault_need_count(root, now) when is_binary(root) do
    root
    |> vault(:need)
    |> Enum.count(fn row -> live_need?(row, now) end)
  end

  def vault_need_count(_, _), do: 0

  @doc """
  Any-tag overlap. A multi-tag Need hits when any Need
  tag is on Has. Empty overlap never matches.
  """
  def overlap(has, need) when is_map(has) and is_map(need) do
    Enum.filter(List.wrap(need[:tags]), &(&1 in List.wrap(has[:tags])))
  end

  def overlap(_, _), do: []

  @doc """
  Prompt-check a self-report rec. Claim / contradiction → curious.
  Built into match — not a later LOOK filter.
  """
  def check(rec, transcript \\ "")

  def check(rec, transcript) when is_map(rec) do
    text = [rec[:text], rec[:raw], transcript] |> Enum.map(&to_string/1) |> Enum.join(" ")
    tags = List.wrap(rec[:tags])

    cond do
      rec[:reject] == "empty_tags" ->
        rec

      claim_text?(text) ->
        refuse(rec, "claim")

      contradict_text?(tags, text) ->
        refuse(rec, "contradiction")

      rec[:curious] == true or rec[:unfit] == true or rec[:check] in ["claim", "contradiction"] ->
        refuse(rec, rec[:check] || rec[:reason] || "claim")

      true ->
        Map.merge(rec, %{check: "pass", prompt_check: "pass", unfit: false, curious: false})
    end
  end

  def check(_, _), do: refuse(%{}, "claim")

  @doc """
  Stamp Need TTL on a self-report rec. Fresh has a future
  expires_at. Expired is already past. Built into match.
  """
  def stamp_ttl(need, ttl, now \\ DateTime.utc_now())

  def stamp_ttl(need, :fresh, now) when is_map(need) do
    Map.merge(need, %{
      expires_at: DateTime.to_iso8601(DateTime.add(now, 72, :hour)),
      need_ttl: :fresh
    })
  end

  def stamp_ttl(need, :expired, now) when is_map(need) do
    Map.merge(need, %{
      expires_at: DateTime.to_iso8601(DateTime.add(now, -1, :hour)),
      need_ttl: :expired
    })
  end

  def stamp_ttl(need, _, _), do: need

  def match(has, need, opts \\ [])

  def match(has, need, opts) when is_map(has) and is_map(need) and is_list(opts) do
    transcript = Keyword.get(opts, :transcript) || ""
    now = Keyword.get(opts, :now) || DateTime.utc_now()
    has = check(has, transcript)
    need = check(need, transcript)
    tags = overlap(has, need)
    need_ttl = Room.Need.freshness(need, now)

    cond do
      has[:reject] == "empty_tags" ->
        %{ok: false, tags: [], handle: nil, query: nil, error: "empty_tags", find: :not_called, mazel_d: :none}

      need[:reject] == "empty_tags" ->
        %{ok: false, tags: [], handle: nil, query: nil, error: "empty_tags", find: :none, mazel_d: :none}

      has[:check] == "claim" or need[:check] == "claim" ->
        miss("curious", "claim")

      has[:check] == "contradiction" or need[:check] == "contradiction" ->
        miss("curious", "contradiction")

      has[:curious] == true or need[:curious] == true or has[:unfit] == true or need[:unfit] == true ->
        miss("curious", "claim")

      need_ttl == :expired ->
        %{ok: false, tags: [], handle: nil, query: nil, error: "expired", need_ttl: :expired}

      tags == [] ->
        %{ok: false, tags: [], handle: nil, query: nil, error: "no_overlap"}

      true ->
        query = hd(tags)

        %{
          ok: true,
          tags: tags,
          handle: has[:handle] || "kai@mazel",
          query: query,
          error: nil,
          prompt_check: "pass",
          need_ttl: need_ttl
        }
        |> stamp_shape(has, need)
    end
  end

  def match(_, _, _), do: %{ok: false, tags: [], handle: nil, query: nil, error: "no_overlap"}

  @doc """
  Need × Has both exist, tags miss. Find is none.

  Primary miss — not a secondary beat after a hit.
  Distinct from empty vault (`error=empty`) and from
  overlap (partial hit first). Never Find.query.
  """
  def mismatch(has, need, opts \\ [])

  def mismatch(has, need, opts) when is_map(has) and is_map(need) and is_list(opts) do
    has_tags = List.wrap(has[:tags])
    need_tags = List.wrap(need[:tags])
    tags = overlap(has, need)
    hit = match(has, need, opts)

    cond do
      has_tags == [] ->
        %{
          ok: false,
          tags: [],
          overlap: [],
          handle: nil,
          query: nil,
          error: "empty",
          find: :none,
          mazel_d: :none
        }

      need_tags == [] ->
        %{
          ok: false,
          tags: [],
          overlap: [],
          handle: nil,
          query: nil,
          error: "no_need",
          find: :none,
          mazel_d: :none
        }

      tags != [] or hit.ok ->
        Map.merge(hit, %{error: "overlap", overlap: tags, find: hit.query, mazel_d: hit.handle})

      true ->
        %{
          ok: false,
          tags: [],
          overlap: [],
          handle: nil,
          query: nil,
          error: "no_overlap",
          find: :none,
          mazel_d: :none
        }
    end
  end

  def mismatch(_, _, _),
    do: %{
      ok: false,
      tags: [],
      overlap: [],
      handle: nil,
      query: nil,
      error: "no_overlap",
      find: :none,
      mazel_d: :none
    }

  @doc """
  Overlap against many Has peers. Order is the given list
  (tag order). Empty overlap drops a peer. First hit is mazel'd.
  """
  def match_all(has_list, need, opts \\ [])

  def match_all(has_list, need, opts) when is_list(has_list) and is_map(need) and is_list(opts) do
    has_list
    |> Enum.map(&match(&1, need, opts))
    |> Enum.filter(& &1.ok)
  end

  def match_all(_, _, _), do: []

  @doc """
  Persist a self-report rec into a vault. Curious / empty
  never writes. Not proof Has. Not index/has.
  """
  def put(root, rec) when is_binary(root) and is_map(rec) do
    cond do
      rec[:source] != "self_report" ->
        {:error, :not_self_report}

      rec[:curious] == true or rec[:unfit] == true or rec[:ok] == false ->
        {:error, :curious}

      rec[:kind] not in ["has", "need"] or List.wrap(rec[:tags]) == [] ->
        {:error, :empty_tags}

      true ->
        dir = vault_dir(root)
        File.mkdir_p!(dir)
        File.write!(Path.join(dir, vault_name(rec)), encode_vault(rec))
        {:ok, rec}
    end
  end

  def put(_, _), do: {:error, :not_self_report}

  def vault_has_count(root), do: length(vault(root, "has"))

  def vault_need_count(root, now \\ DateTime.utc_now()) do
    root
    |> vault("need")
    |> Enum.count(&(Room.Need.freshness(&1, now) != :expired))
  end

  def vault(root, kind) when is_binary(root) do
    kind = to_string(kind)
    dir = vault_dir(root)

    if File.dir?(dir) do
      dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".md"))
      |> Enum.filter(fn name ->
        String.starts_with?(name, kind <> "-") or name == kind <> ".md"
      end)
      |> Enum.map(&decode_vault(Path.join(dir, &1)))
      |> Enum.reject(&is_nil/1)
    else
      []
    end
  end

  def vault(_, _), do: []

  @doc """
  Self-report tags overlap → find → in-agent chat.
  Isolated. Proof-path chat_depth LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-match-" <> random_id()

    has = parse(Keyword.get(opts, :has) || "has: series-a")
    need = parse(Keyword.get(opts, :need) || "need: series-a")
    claim = parse("claim: passionate visionary hunt for series-a")
    hit = match(has, need)
    missed = match(claim, need)

    with {:ok, found} <- Room.Find.query(hit.query || "series-a"),
         {:ok, session} <- keep_agent(prefix, hit) do
      card = List.first(found[:hits] || [])
      events = Enum.map(session.events || [], & &1.type)

      cond do
        has.source != "self_report" or need.source != "self_report" ->
          {:error, :not_self_report}

        has.tags != ["series-a"] or need.tags != ["series-a"] ->
          {:error, :tags_miss}

        not hit.ok or hit.handle != "kai@mazel" or hit.tags != ["series-a"] ->
          {:error, :overlap_miss}

        missed.ok or missed.tags != [] ->
          {:error, :claim_hit}

        claim.curious != true or claim.tags != [] ->
          {:error, :claim_fit}

        is_nil(card) or card.handle != "kai@mazel" ->
          {:error, :find_miss}

        session.status != :open or session.session_kind != :direct ->
          {:error, :session_miss}

        session.badge != nil or "morph.commit" in events ->
          {:error, :morphed}

        humans_awake?(session) ->
          {:error, :human_woke}

        true ->
          pack = %{
            has: has,
            need: need,
            hit: hit,
            claim: claim,
            find: found,
            session: session,
            complete: :agent
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp slice_name(rec) do
    kind = rec[:kind] || "has"
    tag = List.first(List.wrap(rec[:tags])) || "tag"
    local =
      rec[:handle]
      |> to_string()
      |> String.trim_leading("@")
      |> String.split("@")
      |> hd()

    suffix = if local != "", do: "-#{local}", else: ""
    "#{kind}#{suffix}-#{tag}.md"
  end

  defp slice_md(rec) do
    kind = rec[:kind] || "has"
    tags = Enum.join(List.wrap(rec[:tags]), ",")
    handle = rec[:handle]
    expires = rec[:expires_at]

    extras =
      [
        if(handle, do: "handle: #{handle}\n", else: nil),
        if(expires, do: "expires_at: #{expires}\n", else: nil)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join()

    """
    ---
    id: #{kind}-#{tags}
    kind: #{kind}
    source: self_report
    tags: #{tags}
    #{extras}---

    self-report #{kind}
    """
  end

  defp parse_vault(path) do
    raw = File.read!(path)

    case String.split(raw, ~r/\n---\n/, parts: 2) do
      [front, _body] ->
        meta =
          front
          |> String.replace_leading("---\n", "")
          |> String.split("\n")
          |> Enum.reduce(%{}, fn line, acc ->
            case String.split(line, ":", parts: 2) do
              [k, v] -> Map.put(acc, String.trim(k), String.trim(v))
              _ -> acc
            end
          end)

        tags =
          (meta["tags"] || "")
          |> String.split(",", trim: true)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        %{
          id: meta["id"] || Path.basename(path, ".md"),
          kind: meta["kind"] || "has",
          source: meta["source"] || "self_report",
          tags: tags,
          handle: meta["handle"],
          expires_at: meta["expires_at"],
          curious: false,
          unfit: false,
          ok: tags != []
        }

      _ ->
        nil
    end
  end

  defp live_has?(row) do
    row.kind == "has" and row.source == "self_report" and row.tags != [] and row.curious != true
  end

  defp live_need?(row, now) do
    row.kind == "need" and row.source == "self_report" and row.tags != [] and row.curious != true and
      not Room.Index.expired?(row, now)
  end

  defp keep_agent(id, hit) do
    peer = hit[:handle] || "kai@mazel"

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup(peer) do
      Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}])
    end
  end

  defp reject_empty_tags(kind, chat, raw_tags) do
    rec = %{
      ok: false,
      kind: to_string(kind),
      source: "self_report",
      tags: [],
      handle: nil,
      curious: false,
      unfit: false,
      reject: "empty_tags",
      error: "empty_tags",
      from: "chat",
      cast: to_string(kind),
      text: chat
    }

    if raw_tags == [] do
      rec
    else
      Map.put(rec, :raw_tags, raw_tags)
    end
  end

  defp ws_only_tag?(tag) do
    text = to_string(tag)
    text != "" and String.trim(text) == ""
  end

  defp padded_skill_raw(chat) when is_binary(chat) do
    trimmed = chat |> String.trim() |> String.downcase()

    if chat != String.trim(chat) and trimmed != "" and trimmed in Room.Has.domain_skills() do
      chat
    end
  end

  defp padded_skill_raw(_), do: nil

  defp cased_skill_raw(chat) when is_binary(chat) do
    trimmed = String.trim(chat)
    down = String.downcase(trimmed)

    if trimmed != "" and trimmed != down and down in Room.Has.domain_skills() do
      trimmed
    end
  end

  defp cased_skill_raw(_), do: nil

  defp attach_padded_trim(rec, raw, ids) do
    shown = Enum.map(List.wrap(raw), &to_string/1)

    rec
    |> maybe_attach_pad(shown, ids)
    |> maybe_attach_norm(shown, ids)
    |> maybe_attach_dedupe(shown, ids)
  end

  defp maybe_attach_pad(rec, shown, ids) do
    if ids != [] and padded_real?(shown) do
      Map.merge(rec, %{raw_tags: shown, trim: Enum.join(ids, ",")})
    else
      rec
    end
  end

  defp maybe_attach_norm(rec, shown, ids) do
    if ids != [] and cased_real?(shown) do
      Map.merge(rec, %{raw_tags: rec[:raw_tags] || shown, norm: Enum.join(ids, ",")})
    else
      rec
    end
  end

  defp maybe_attach_dedupe(rec, shown, ids) do
    pre = skill_tags_before_uniq(shown)

    if ids != [] and length(pre) > length(ids) do
      Map.merge(rec, %{raw_tags: rec[:raw_tags] || pre, dedupe: ids})
    else
      rec
    end
  end

  defp cased_real?(shown) do
    Enum.any?(shown, fn tag ->
      trimmed = String.trim(tag)
      trimmed != "" and trimmed != String.downcase(trimmed)
    end)
  end

  defp padded_real?(shown) do
    Enum.any?(shown, fn tag ->
      trimmed = String.trim(tag)
      tag != trimmed and trimmed != ""
    end)
  end

  defp curious do
    refuse(%{kind: "curious", source: "self_report", tags: [], handle: nil}, "claim")
  end

  defp refuse(rec, reason) do
    Map.merge(rec, %{
      ok: false,
      kind: rec[:kind] || "curious",
      source: rec[:source] || "self_report",
      tags: [],
      handle: nil,
      curious: true,
      unfit: true,
      check: reason,
      reason: reason,
      prompt_check: reason,
      class: "curious"
    })
  end

  defp miss(error, check) do
    %{
      ok: false,
      tags: [],
      handle: nil,
      query: nil,
      error: error,
      prompt_check: check,
      class: "curious"
    }
  end

  defp claim_text?(text) do
    down = String.downcase(to_string(text))
    claim?(down) or Regex.match?(~r/\b(claim:|vibe:|passionate|visionary|thought[- ]leader)\b/i, down)
  end

  defp contradict_text?(tags, text) do
    down = String.downcase(to_string(text))

    Enum.any?(List.wrap(tags), fn tag ->
      tag = to_string(tag)

      String.contains?(down, "not #{tag}") or String.contains?(down, "no #{tag}") or
        String.contains?(down, "do not do #{tag}")
    end)
  end

  defp vault_dir(root), do: Path.join([root, "index", "self_report"])

  defp vault_name(%{kind: "has"} = rec) do
    local =
      rec[:handle]
      |> to_string()
      |> String.trim_leading("@")
      |> String.split("@")
      |> hd()

    "has-#{local}.md"
  end

  defp vault_name(_), do: "need.md"

  defp encode_vault(rec) do
    tags = rec[:tags] |> List.wrap() |> Enum.join(",")

    [
      "---",
      "kind: #{rec[:kind]}",
      "source: self_report",
      "tags: #{tags}",
      "handle: #{rec[:handle] || ""}",
      "expires_at: #{rec[:expires_at] || ""}",
      "---",
      ""
    ]
    |> Enum.join("\n")
  end

  defp decode_vault(path) do
    raw = File.read!(path)

    meta =
      raw
      |> String.replace_leading("---\n", "")
      |> String.split("\n")
      |> Enum.reduce(%{}, fn line, acc ->
        case String.split(line, ":", parts: 2) do
          [k, v] -> Map.put(acc, String.trim(k), String.trim(v))
          _ -> acc
        end
      end)

    tags = normalize_tags(meta["tags"] || "")
    expires = meta["expires_at"]
    expires = if expires in [nil, ""], do: nil, else: expires

    %{
      ok: tags != [],
      kind: meta["kind"] || "has",
      source: "self_report",
      tags: tags,
      handle: empty_to_nil(meta["handle"]),
      expires_at: expires,
      curious: false,
      unfit: false
    }
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(v), do: v

  defp normalize_tags(tags) do
    tags
    |> List.wrap()
    |> Enum.flat_map(&String.split(to_string(&1), ~r/[,]+/, trim: true))
    |> Enum.map(&(&1 |> String.trim() |> String.downcase()))
    |> Enum.reject(&(&1 == ""))
    |> Enum.filter(&(&1 in Room.Has.domain_skills()))
    |> Enum.uniq()
  end

  defp strip_prefix(text, prefix) do
    String.slice(text, String.length(prefix)..-1//1)
  end

  defp claim?(down) do
    String.starts_with?(down, "claim:") or String.starts_with?(down, "vibe:") or
      String.contains?(down, "passionate") or String.contains?(down, "visionary")
  end

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
