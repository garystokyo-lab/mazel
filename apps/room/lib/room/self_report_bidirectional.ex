defmodule Room.SelfReportBidirectional do
  @moduledoc """
  Double-magic bidirectional self-report match.

  A needs X / B has X and B needs Y / A has Y → both
  mazel'd. Distinct from self_report_match / why (one
  need×has direction). Off PDF / badge / GH / score /
  wiki / morph / toolbelt.
  """

  @x "series-a"
  @y "cto"
  @a "ariel@mazel"
  @b "kai@mazel"

  def x, do: @x
  def y, do: @y
  def a, do: @a
  def b, do: @b

  def look_a, do: "ok  a need=#{@x}  has=#{@y}"
  def look_b, do: "ok  b need=#{@y}  has=#{@x}"

  def look_find_ab(rec \\ %{}) do
    Room.SelfReportMatch.look_find(%{handle: rec[:handle] || @b, query: rec[:query] || @x})
  end

  def look_find_ba(rec \\ %{}) do
    Room.SelfReportMatch.look_find(%{handle: rec[:handle] || @a, query: rec[:query] || @y})
  end

  def look_why_x, do: "why  need=#{@x}  has=#{@x}"
  def look_why_y, do: "why  need=#{@y}  has=#{@y}"
  def look_complete, do: Room.SelfReportMatch.look_complete()

  def look(pack) when is_map(pack) do
    [
      look_a(),
      look_b(),
      look_find_ab(pack[:ab] || %{}),
      look_find_ba(pack[:ba] || %{}),
      look_why_x(),
      look_why_y(),
      look_complete()
    ]
  end

  def look(_), do: look(%{})

  @doc """
  Pair both directions, open two in-agent sessions.
  Isolated. Sibling match / why LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "self-report-bidirectional-" <> random_id()

    a = %{
      need: Room.SelfReportMatch.report(:need, @x, handle: @a),
      has: Room.SelfReportMatch.report(:has, @y, handle: @a)
    }

    b = %{
      need: Room.SelfReportMatch.report(:need, @y, handle: @b),
      has: Room.SelfReportMatch.report(:has, @x, handle: @b)
    }

    one = %{
      need: a.need,
      has: a.has
    }

    only_b = %{need: Room.SelfReportMatch.report(:need, "impl", handle: @b), has: b.has}
    paired = Room.SelfReportMatch.both(a, b)
    missed = Room.SelfReportMatch.both(one, only_b)

    with {:ok, session_ab} <- keep_pair(prefix <> "-ab", @a, paired.ab.handle),
         {:ok, session_ba} <- keep_pair(prefix <> "-ba", @b, paired.ba.handle) do
      events_ab = Enum.map(session_ab.events || [], & &1.type)
      events_ba = Enum.map(session_ba.events || [], & &1.type)

      cond do
        a.need.source != "self_report" or b.has.source != "self_report" ->
          {:error, :not_self_report}

        not paired.ok or paired.error != nil ->
          {:error, :both_miss}

        paired.ab.handle != @b or paired.ab.query != @x ->
          {:error, :ab_miss}

        paired.ba.handle != @a or paired.ba.query != @y ->
          {:error, :ba_miss}

        missed.ok or missed.error != "one_way" ->
          {:error, :one_way_hit}

        session_ab.status != :open or session_ba.status != :open ->
          {:error, :session_miss}

        session_ab.badge != nil or session_ba.badge != nil ->
          {:error, :morphed}

        "morph.commit" in events_ab or "morph.commit" in events_ba ->
          {:error, :morphed}

        humans_awake?(session_ab) or humans_awake?(session_ba) ->
          {:error, :human_woke}

        true ->
          pack = %{
            a: a,
            b: b,
            ab: paired.ab,
            ba: paired.ba,
            paired: paired,
            missed: missed,
            session_ab: session_ab,
            session_ba: session_ba,
            complete: :agent
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp keep_pair(id, from, peer) do
    with {:ok, speaker} <- Room.Cards.lookup(from),
         {:ok, other} <- Room.Cards.lookup(peer) do
      Room.open(id, :direct, [%{handle: speaker, role: :agent}, %{handle: other, role: :agent}])
    end
  end

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
