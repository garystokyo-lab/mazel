defmodule Room.Warm do
  @moduledoc """
  Human-visible warm packet after morph.commit.

  Who / why / opener / dual consent / return-to-agent.
  Not a JSON dump.
  """

  def look(%{from: from, peer: peer, state: state}) do
    strip(id_of(from), id_of(peer), state)
  end

  def look(state) when is_map(state) do
    {from, peer} = ends_of(state)
    strip(from, peer, state)
  end

  defp strip(from, peer, state) do
    badge = state[:badge] || state["badge"] || %{}
    kind = badge["kind"] || badge[:kind] || "pull_intent"
    morph = last_morph(state)

    ["ok  morph=#{morph}  badge=#{kind}"] ++ fields(from, peer, state)
  end

  @doc "Warm field strip only (no morph ok-line). Pull-mint path reuses this."
  def fields(%{from: from, peer: peer, state: state}), do: fields(id_of(from), id_of(peer), state)

  def fields(%{peer: peer, state: state} = pack) do
    from = pack[:from] || "ariel@mazel"
    fields(id_of(from), id_of(peer), state)
  end

  def fields(from, peer, state) when is_map(state) do
    badge = state[:badge] || state["badge"] || %{}
    packet = state[:warm_packet] || state["warm_packet"] || %{}

    [
      "warm  from=#{from}  peer=#{peer}",
      "warm  why=#{why(badge, packet)}",
      "warm  opener=#{opener_of(packet)}",
      "warm  consent=#{consent_of(state)}",
      "warm  return=agent"
    ]
  end

  def fields(_, _, _), do: []

  defp ends_of(state) do
    agents =
      (state[:participants] || state["participants"] || [])
      |> Enum.filter(&agent?/1)

    {id_of(Enum.at(agents, 0)), id_of(Enum.at(agents, 1))}
  end

  defp agent?(%{role: role}) when role in [:agent, "agent"], do: true
  defp agent?(%{"role" => role}) when role in [:agent, "agent"], do: true
  defp agent?(_), do: false

  defp why(badge, packet) do
    badge["topic"] || badge[:topic] || badge["intent"] || packet[:summary] ||
      packet["summary"] || "morph"
  end

  defp opener_of(packet) do
    excerpt = packet[:transcript_excerpt] || packet["transcript_excerpt"] || []

    case List.first(excerpt) do
      %{text: text} when is_binary(text) -> text
      %{"text" => text} when is_binary(text) -> text
      _ -> ""
    end
  end

  defp consent_of(%{dual_consent: true}), do: "dual"
  defp consent_of(_), do: "required"

  defp last_morph(%{events: events}) when is_list(events) do
    events
    |> Enum.map(& &1.type)
    |> Enum.reverse()
    |> Enum.find(&(&1 == "morph.commit")) || "morph.commit"
  end

  defp last_morph(_), do: "morph.commit"

  defp id_of(%{handle: handle}), do: id_of(handle)
  defp id_of(%{"handle" => handle}), do: id_of(handle)
  defp id_of(%{id: id}) when is_binary(id), do: id
  defp id_of(%{"id" => id}) when is_binary(id), do: id
  defp id_of(id) when is_binary(id), do: id
  defp id_of(_), do: ""
end
