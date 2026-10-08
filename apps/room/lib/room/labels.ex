defmodule Room.Labels do
  @moduledoc """
  Display labels for stable protocol ids.

  Wire, events, serde `kind` tags, and tests use **ids** (`badge`, `direct`,
  `need`, …). Humans see whatever this table currently says. Swap or override
  the table without renaming types or breaking tests.

  Override a row: `Room.Labels.put(:badge, "Token")`.
  Reset: `Room.Labels.reset/0`.
  """

  @core_ids ~w(
    badge
    pull_intent
    pull_match
    vouch
    invite_token
    proof_of_work
    find
    chat
    harp
    direct
    series-a
    cto
    impl
    enterprise
    intro
    group
    need
    open
    discovery
    morph
    morph.propose
    morph.commit
    consent
    room.open
    handle
    warm_packet
    has
    curious
    candidate
    proof
    claim
    fresh
    stale
  )a

  @default %{
    badge: "Badge",
    pull_intent: "Pull intent",
    pull_match: "Pull match",
    vouch: "Vouch",
    invite_token: "Invite token",
    proof_of_work: "Proof of work",
    find: "Find",
    chat: "Chat",
    harp: "Harp",
    direct: "Direct",
    "series-a": "Series A",
    cto: "CTO",
    impl: "Impl",
    enterprise: "Enterprise",
    intro: "Intro",
    group: "Group",
    need: "Need",
    open: "Open",
    discovery: "Discovery",
    morph: "Morph",
    "morph.propose": "Morph propose",
    "morph.commit": "Morph commit",
    consent: "Consent",
    "room.open": "Room open",
    handle: "Handle",
    warm_packet: "Warm packet",
    has: "Has",
    curious: "Curious",
    candidate: "Candidate",
    proof: "Proof",
    claim: "Claim",
    fresh: "Fresh",
    stale: "Stale"
  }

  # Featured LOOK ids. Full table stays on `ids/0`. Swap proves the
  # display string moves; the protocol id does not.
  @look_ids [:has, :need, :badge, :morph, :open]
  @session_ids [:direct, :intro, :group]
  @swap_id :morph
  @swap_label "Connect"

  @doc "Stable protocol ids that have a default display row."
  def ids, do: @core_ids

  def look_ids, do: @look_ids

  @doc "Session wing ids. Display labels swap; wire ids stay."
  def session_ids, do: @session_ids

  @doc "ADHD LOOK line. Id is stable; label is whatever the table says."
  def look_line(id) do
    "ok  id=#{id_string(id)}  label=#{get(id)}"
  end

  def look_swap(id, label) when is_binary(label) do
    "ok  swap  id=#{id_string(id)}  label=#{label}"
  end

  @doc """
  Featured ids + one swap beat (morph → Connect → Morph).
  Isolated to process overrides. Does not touch score / need / has.
  """
  def demo do
    reset()

    rows = Enum.map(@look_ids, &look_line/1)
    put(@swap_id, @swap_label)
    swapped = look_swap(@swap_id, get(@swap_id))
    reset()
    restored = look_swap(@swap_id, get(@swap_id))

    {:ok, %{lines: rows ++ [swapped, restored], ids: @look_ids}}
  end

  @doc "Full current table (defaults + app env + process overrides)."
  def table do
    @default
    |> Map.merge(app_overrides())
    |> Map.merge(overrides())
  end

  @doc "Display label for a protocol id. Unknown ids echo as strings."
  def get(id) do
    key = norm(id)

    case table()[key] do
      nil -> to_string(id)
      label -> label
    end
  end

  @doc "One demo line: `badge  Badge` (id stays; label is swappable)."
  def format(id) do
    "#{id_string(id)}  #{get(id)}"
  end

  @doc "Override one display row for this process. Does not change protocol ids."
  def put(id, label) when is_binary(label) do
    Process.put({__MODULE__, :overrides}, Map.put(overrides(), norm(id), label))
    :ok
  end

  @doc "Drop process overrides; back to the default English table."
  def reset do
    Process.delete({__MODULE__, :overrides})
    :ok
  end

  defp overrides do
    Process.get({__MODULE__, :overrides}, %{})
  end

  defp app_overrides do
    Application.get_env(:room, :labels, %{})
    |> Enum.into(%{}, fn {key, value} -> {norm(key), value} end)
  end

  defp norm(id) when is_atom(id), do: id

  defp norm(id) when is_binary(id) do
    try do
      String.to_existing_atom(id)
    rescue
      ArgumentError -> id
    end
  end

  defp id_string(id) when is_atom(id), do: Atom.to_string(id)
  defp id_string(id) when is_binary(id), do: id
end
