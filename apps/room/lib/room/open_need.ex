defmodule Room.OpenNeed do
  @moduledoc """
  Live Open → agent Need via shape preset + hard TTL.

  Shape and TTL live on the same Need. Fresh can match Has/Open.
  Expired is unfit, out of the pool. Vibe is curious and never matches.
  """

  @shape :icp_pain
  @peer "nova@mazel"

  def shape, do: @shape
  def peer, do: @peer

  @doc """
  Stamp hard TTL onto a shape-cast Need. Same object. Soft age
  is not this gate — expired is out.
  """
  def stamp(need, opts \\ []) when is_map(need) do
    now = now_of(opts)
    ttl = Keyword.get(opts, :ttl_hours) || need[:ttl_hours] || 72
    as_of = DateTime.to_date(now) |> Date.to_iso8601()
    expires_at = DateTime.add(now, ttl * 3600, :second) |> DateTime.to_iso8601()

    stamped =
      Map.merge(need, %{
        ttl: :hard,
        ttl_hours: ttl,
        as_of: as_of,
        expires_at: expires_at
      })

    Map.put(stamped, :need_ttl, Room.Need.freshness(stamped, now))
  end

  @doc "Flip the same Need past its hard TTL."
  def expire(need, opts \\ []) when is_map(need) do
    now = now_of(opts)
    dead = Map.put(need, :expires_at, DateTime.add(now, -3600, :second) |> DateTime.to_iso8601())
    Map.merge(dead, %{need_ttl: :expired, ttl: :hard})
  end

  @doc """
  Agent emit from a live Open. Preset + hard TTL on one Need.
  Unknown / vibe / claim stays curious.
  """
  def emit(open, raw \\ @shape, opts \\ []) do
    params = Keyword.get(opts, :params, %{})
    transcript = Keyword.get(opts, :transcript, "")

    with {:ok, need} <- Room.Need.Shape.cast(raw, params),
         {:ok, need} <- Room.NeedCheck.check(need, transcript) do
      if need.unfit do
        {:ok, need}
      else
        stamped = stamp(need, opts)
        open_id = open[:open_id] || open[:id] || open["id"]

        {:ok,
         Map.merge(stamped, %{
           open_id: open_id,
           from_open: true
         })}
      end
    end
  end

  def look_cast(%{unfit: true}), do: "error  vibe→curious  unfit=true"

  def look_cast(%{ok: true, shape: shape} = need) do
    ttl = need[:need_ttl] || :fresh
    "ok  open→need  shape=#{shape}  ttl=hard  need_ttl=#{ttl}"
  end

  def look_cast(_), do: "error  vibe→curious  unfit=true"

  def look_match(%{ok: true, handle: handle}) when is_binary(handle) do
    "ok  need×has  peer=#{handle}"
  end

  def look_match(_), do: "ok  need×has  peer="

  def look_expired(%{unfit: true}), do: Room.Jit.look(%{unfit: true, need_ttl: :expired})
  def look_expired(_), do: Room.Jit.look(%{unfit: true, need_ttl: :expired})

  def look_vibe(need), do: Room.Need.Shape.look(need)

  def look(pack) when is_map(pack) do
    [look_cast(pack.need), look_match(pack.match), look_expired(pack.expired), look_vibe(pack.vibe)]
  end

  def look(_), do: look(%{need: %{}, match: %{}, expired: %{unfit: true}, vibe: %{unfit: true}})

  def look_check_cast(%{ok: true, shape: shape} = need) do
    "ok  open→need  shape=#{shape}  check=pass  need_ttl=#{need[:need_ttl] || :fresh}"
  end

  def look_check_cast(_), do: "error  claim→curious  unfit=true"

  def look_check(pack) when is_map(pack) do
    [
      look_check_cast(pack.need),
      look_match(pack.match),
      Room.NeedCheck.look_claim(),
      Room.NeedCheck.look_contradict()
    ]
  end

  def look_check(_), do: look_check(%{need: %{shape: @shape, need_ttl: :fresh}, match: %{}})

  @doc """
  Open→Need cast with prompt-check. Claim / contradict → curious.
  Isolated. Does not rewrite open_need_demo LOOK.
  """
  def check_demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-open-need-check-#{System.unique_integer([:positive])}")
          File.mkdir_p!(Path.join(path, "index/has"))
          {path, true}
      end

    try do
      check_demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp check_demo_on(root) do
    now = ~U[2026-09-11 12:00:00Z]
    File.mkdir_p!(Path.join(root, "index/has"))

    File.cp!(
      Path.join(Room.Index.repo_root(), "index/has/nova.md"),
      Path.join(root, "index/has/nova.md")
    )

    agree = "need: enterprise customer needs impl"
    boast = "claim: passionate visionary hunt for impl"
    deny = "transcript: we do not do impl"

    with {:ok, open} <- Room.Open.from_has(@peer, root: root, now: now),
         {:ok, need} <- emit(open, @shape, now: now, transcript: agree),
         {:ok, match} <- Room.Need.match_has(need, root: root, now: now, transcript: agree),
         {:ok, claim} <- emit(open, @shape, now: now, transcript: boast),
         {:ok, contradict} <- emit(open, @shape, now: now, transcript: deny) do
      {:ok, skipped} = Room.Need.match_has(claim, root: root, now: now)
      {:ok, blocked} = Room.Need.match_has(contradict, root: root, now: now)

      cond do
        need.check != "pass" or need.unfit or need.need_ttl != :fresh ->
          {:error, :pass_miss}

        not match.ok or match.handle != @peer ->
          {:error, :match_miss}

        not claim.unfit or claim.reason != "claim" ->
          {:error, :claim_fit}

        not contradict.unfit or contradict.reason != "contradict" ->
          {:error, :contradict_fit}

        skipped.ok or blocked.ok or skipped.matches != [] or blocked.matches != [] ->
          {:error, :curious_matched}

        true ->
          pack = %{open: open, need: need, match: match, claim: claim, contradict: contradict}
          {:ok, Map.put(pack, :lines, look_check(pack))}
      end
    end
  end

  @doc """
  Live Open → icp_pain Need (hard TTL) → Has when fresh.
  Same Need expired → unfit. Vibe refused. Isolated tmp.
  Does not rewrite open_demo / need_shape_demo / jit_demo LOOK.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-open-need-#{System.unique_integer([:positive])}")
          File.mkdir_p!(Path.join(path, "index/has"))
          File.mkdir_p!(Path.join(path, "index/opens"))
          File.mkdir_p!(Path.join(path, "index/needs"))
          {path, true}
      end

    try do
      demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp demo_on(root) do
    now = ~U[2026-09-11 12:00:00Z]
    File.mkdir_p!(Path.join(root, "index/has"))

    Enum.each(["kai.md", "nova.md"], fn name ->
      File.cp!(
        Path.join(Room.Index.repo_root(), Path.join("index/has", name)),
        Path.join(root, Path.join("index/has", name))
      )
    end)

    with {:ok, open} <- Room.Open.from_has(@peer, root: root, now: now),
         {:ok, need} <- emit(open, @shape, now: now),
         {:ok, match} <- Room.Need.match_has(need, root: root, now: now),
         {:ok, vibe} <- Room.Need.Shape.cast("vibe: passionate energy") do
      opens = Room.Open.for_need(need, root: root, now: now)
      dead = expire(need, now: now)
      {:ok, expired} = Room.Need.match_has(dead, root: root, now: now)

      cond do
        not need.ok or need.shape != @shape or need.ttl != :hard or need.need_ttl != :fresh ->
          {:error, :cast_miss}

        is_nil(need.expires_at) or Room.Need.expired?(need, now) ->
          {:error, :ttl_soft}

        not match.ok or match.handle != @peer or match[:unfit] ->
          {:error, :match_miss}

        opens == [] or not Enum.any?(opens, &(&1.handle == @peer)) ->
          {:error, :open_miss}

        expired.ok or not expired.unfit or expired.need_ttl != :expired or expired.matches != [] ->
          {:error, :expired_matched}

        not vibe.unfit or vibe.ok or not Room.Need.curious?(vibe) ->
          {:error, :vibe_matched}

        true ->
          pack = %{
            open: open,
            need: need,
            match: match,
            opens: opens,
            expired: expired,
            vibe: vibe
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp now_of(opts) do
    Keyword.get(opts, :now) || DateTime.utc_now() |> DateTime.truncate(:second)
  end
end
