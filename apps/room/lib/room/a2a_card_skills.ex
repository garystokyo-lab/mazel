defmodule Room.A2aCardSkills do
  @moduledoc """
  A2A Agent Card skills on the well-known card.

  Mazel surface is find + direct. Distinct from a2a_card
  (handle → card URL only). Off Match / wiki / mint.
  """

  @surface ~w(find direct)

  def surface, do: @surface

  def look_card(rec \\ %{}) do
    handle = rec[:handle] || rec["handle"] || "kai@mazel"
    listed = rec[:skills] || @surface
    "ok  a2a  card=#{handle}  skills=#{Enum.join(List.wrap(listed), ",")}"
  end

  def look_skill(id), do: "ok  skill=#{id}"

  def look_ghost, do: "error  card=@ghost  error=unknown_handle"

  def look(pack \\ %{}) do
    rec = pack[:hit] || %{}
    skills = rec[:skills] || @surface
    [look_card(rec)] ++ Enum.map(skills, &look_skill/1) ++ [look_ghost()]
  end

  @doc "Skill ids from a well-known card body. A string is not a list. Mixed lists list none."
  def skill_ids(card) when is_map(card) do
    raw = skills_raw(card)

    cond do
      bad_skills?(card) ->
        []

      is_list(raw) ->
        raw
        |> Enum.map(&skill_id/1)
        |> Enum.reject(&(&1 in [nil, ""]))
        |> Enum.uniq()

      true ->
        []
    end
  end

  def skill_ids(_), do: []

  @doc "Mazel capability surface present on the card."
  def mazel_skills(card) do
    ids = skill_ids(card)
    Enum.filter(@surface, &(&1 in ids))
  end

  @doc "skills is a non-list (string / map / number) or a list with a non-skill item. Not [] or null."
  def bad_skills?(card) when is_map(card) do
    raw = skills_raw(card)

    cond do
      is_nil(raw) -> false
      not is_list(raw) -> true
      Enum.any?(raw, &(not skill_item?(&1))) -> true
      true -> false
    end
  end

  def bad_skills?(_), do: false

  @doc "Read find+direct off a card. Empty / missing is empty_skills. A string or mixed list is bad_skills."
  def of(card) when is_map(card) do
    cond do
      bad_skills?(card) ->
        {:error, :bad_skills}

      mazel_skills(card) == @surface ->
        {:ok, %{handle: card["handle"] || card[:handle], skills: @surface}}

      true ->
        {:error, :empty_skills}
    end
  end

  def of(_), do: {:error, :empty_skills}

  defp skills_raw(card) do
    cond do
      Map.has_key?(card, "skills") -> card["skills"]
      Map.has_key?(card, :skills) -> card[:skills]
      true -> nil
    end
  end

  @doc """
  Well-known kai card lists find + direct. Ghost 404.
  Isolated. Sibling a2a_card LOOK stays (no skills=).
  """
  def demo(_opts \\ []) do
    with {:ok, hit} <- Room.A2aCard.resolve("@kai"),
         {:ok, skills} <- of(hit.card),
         {:error, :unknown_handle} <- Room.A2aCard.resolve("@ghost") do
      cond do
        skills.handle != "kai@mazel" ->
          {:error, :handle_miss}

        skills.skills != @surface ->
          {:error, :skills_miss}

        hit.path != Room.A2aCard.path() ->
          {:error, :path_miss}

        true ->
          pack = %{
            hit: Map.merge(hit, skills),
            ghost: :unknown_handle
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp skill_item?(id) when is_binary(id), do: id != ""

  defp skill_item?(id) when is_atom(id) and id not in [true, false, nil], do: true

  defp skill_item?(%{"id" => id}) when is_binary(id), do: id != ""

  defp skill_item?(%{"id" => id}) when is_atom(id) and id not in [true, false, nil], do: true

  defp skill_item?(%{id: id}) when is_binary(id), do: id != ""

  defp skill_item?(%{id: id}) when is_atom(id) and id not in [true, false, nil], do: true

  defp skill_item?(_), do: false

  defp skill_id(%{"id" => id}) when is_binary(id), do: id
  defp skill_id(%{"id" => id}) when is_atom(id), do: Atom.to_string(id)
  defp skill_id(%{id: id}) when is_binary(id), do: id
  defp skill_id(%{id: id}) when is_atom(id), do: Atom.to_string(id)
  defp skill_id(id) when is_binary(id), do: id
  defp skill_id(id) when is_atom(id), do: Atom.to_string(id)
  defp skill_id(_), do: nil
end
