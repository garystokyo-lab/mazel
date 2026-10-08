defmodule Room.DiscoveryBadge do
  @moduledoc """
  Discovery Need is badge/postage gated. Returns real handles.

  🪽@mazel / need@mazel open a Need. Morph without stamp is denied.
  Does not rewrite discovery / badge / soft_no LOOK.
  """

  def look_need(rec) when is_map(rec) do
    via = rec[:via] || "need@mazel"
    listed = rec[:handles] |> List.wrap() |> Enum.join(",")
    kind = badge_kind(rec[:badge])
    "ok  discovery=#{via}  kind=need  handles=[#{listed}]  badge=#{kind}"
  end

  def look_need(_), do: "ok  discovery=need@mazel  kind=need  handles=[kai@mazel]  badge=pull_intent"

  def look_denied, do: "error  morph=denied  denied=badge_required"

  def look(pack) when is_map(pack) do
    [look_need(pack.sink), look_need(pack.wing), look_denied()]
  end

  def look(_), do: look(%{sink: %{via: "need@mazel", handles: ["kai@mazel"]}, wing: %{via: "🪽@mazel", handles: ["kai@mazel"]}})

  @doc """
  need@mazel + 🪽@mazel return kai and mint pull_intent.
  No stamp → morph denied. Isolated. discovery_demo LOOK stays.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-disco-badge-#{System.unique_integer([:positive])}")
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

    id = Keyword.get(opts, :context_id) || "disco-badge-" <> random_id()

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
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
         {:ok, _} <-
           Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}]),
         {:error, :badge_required} <- Room.propose_morph(id, ariel) do
      cond do
        sink.handles != ["kai@mazel"] or sink.kind != "need" ->
          {:error, :sink_miss}

        wing.handles != ["kai@mazel"] or wing.kind != "need" ->
          {:error, :wing_miss}

        badge_kind(sink[:badge]) != "pull_intent" or badge_kind(wing[:badge]) != "pull_intent" ->
          {:error, :badge_miss}

        true ->
          pack = %{sink: sink, wing: wing, denied: :badge_required}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp badge_kind(badge) when is_map(badge) do
    badge[:kind] || badge["kind"] || "pull_intent"
  end

  defp badge_kind(_), do: "none"

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
