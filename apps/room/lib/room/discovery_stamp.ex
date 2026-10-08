defmodule Room.DiscoveryStamp do
  @moduledoc """
  Discovery Need is stamp-gated. Unstamped: agent soft-no, human asleep.

  Stamped need@mazel / 🪽@mazel return real handles. 🪽@kai stays Direct.
  Does not rewrite discovery / discovery_badge / soft_no LOOK.
  """

  def look_none, do: "error  discovery=need@mazel  stamp=none  agent=soft_no  human=asleep"

  def look_stamp(rec) when is_map(rec) do
    listed = rec[:handles] |> List.wrap() |> Enum.join(",")
    "ok  discovery=need@mazel  stamp=pull_match  kind=need  handles=[#{listed}]"
  end

  def look_stamp(_), do: "ok  discovery=need@mazel  stamp=pull_match  kind=need  handles=[kai@mazel]"

  def look_wing(rec) when is_map(rec) do
    listed = rec[:handles] |> List.wrap() |> Enum.join(",")
    "ok  discovery=🪽@mazel  kind=need  handles=[#{listed}]"
  end

  def look_wing(_), do: "ok  discovery=🪽@mazel  kind=need  handles=[kai@mazel]"

  def look_direct, do: "ok  discovery=🪽@kai  kind=direct"

  def look(pack) when is_map(pack) do
    [look_none(), look_stamp(pack.sink), look_wing(pack.wing), look_direct()]
  end

  def look(_), do: look(%{sink: %{handles: ["kai@mazel"]}, wing: %{handles: ["kai@mazel"]}})

  @doc """
  Unstamped discovery: soft-no + asleep.
  Stamped need@mazel / 🪽@mazel return kai. 🪽@kai is Direct.
  Isolated. discovery_demo LOOK stays.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-disco-stamp-#{System.unique_integer([:positive])}")
          File.mkdir_p!(Path.join(path, "index/has"))
          File.mkdir_p!(Path.join(path, "index/needs"))
          File.mkdir_p!(Path.join(path, "index/opens"))
          {path, true}
      end

    try do
      demo_on(root, opts)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp demo_on(root, opts) do
    File.cp!(
      Path.join(Room.Index.repo_root(), "index/has/kai.md"),
      Path.join(root, "index/has/kai.md")
    )

    none_id = Keyword.get(opts, :none_id) || "disco-stamp-none-" <> random_id()
    person_id = Keyword.get(opts, :person_id) || "disco-stamp-kai-" <> random_id()

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
         {:ok, none} <-
           Room.open(none_id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}]),
         {:ok, :soft_no} <- Room.SoftNo.agent(none),
         {:error, :human_asleep} <- Room.SoftNo.wake(none),
         {:ok, _open} <-
           Room.Open.dispatch("ping me for series-a", handle: "kai@mazel", root: root, topic: "series-a"),
         {:ok, sink} <-
           Room.Discovery.dispatch(Room.Discovery.sink_wing(),
             root: root,
             via: "need@mazel",
             actor: ariel
           ),
         {:ok, wing} <-
           Room.Discovery.dispatch(Room.Discovery.mazel_wing(),
             root: root,
             via: "🪽@mazel",
             actor: ariel
           ),
         {:ok, person} <- Room.Wings.run("🪽 @kai hello", context_id: person_id) do
      cond do
        humans_awake?(none) or none.badge != nil ->
          {:error, :none_woke}

        sink.handles != ["kai@mazel"] or sink.kind != "need" ->
          {:error, :sink_miss}

        stamp_of(sink[:badge]) != "pull_match" ->
          {:error, :stamp_miss}

        wing.handles != ["kai@mazel"] or wing.kind != "need" ->
          {:error, :wing_miss}

        person.state.session_kind != :direct or Map.has_key?(person, :need_id) ->
          {:error, :person_not_direct}

        true ->
          pack = %{none: none, sink: sink, wing: wing, person: person}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp stamp_of(badge) when is_map(badge) do
    to_string(badge[:source] || badge["source"] || "")
  end

  defp stamp_of(_), do: "none"

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
