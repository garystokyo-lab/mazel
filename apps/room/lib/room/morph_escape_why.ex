defmodule Room.MorphEscapeWhy do
  @moduledoc """
  Why beat when the morph escape hatch closes.

  Same escape path as morph_escape, then why return= from
  Score.why_fields. Distinct from morph_escape (no why) and
  why_demo (need/has comments, no return). Not Needs-import.
  """

  def look_why(rec \\ %{}) do
    id = rec[:why_return] || rec[:why_need] || rec[:why_has] || "series-a"
    "why  return=#{id}"
  end

  def look(pack) when is_map(pack) do
    Room.MorphEscape.look(pack) ++ [look_why(pack)]
  end

  def look(_), do: look(%{badge: %{}})

  @doc """
  Escape + return, then why the hatch closed.
  Isolated. morph_escape LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "morph-escape-why-" <> random_id()

    with {:ok, escape} <- Room.MorphEscape.demo(Keyword.put(opts, :context_id, prefix)) do
      why = Room.Score.why_fields(%{wants: ["series-a"]}, escape.match)
      id = why.why_need || why.why_has

      cond do
        id in [nil, ""] ->
          {:error, :why_miss}

        Enum.any?(escape.lines, &String.starts_with?(&1, "why  return=")) ->
          {:error, :already_why}

        escape.wrapped.status != :returned ->
          {:error, :no_return}

        true ->
          pack =
            escape
            |> Map.merge(why)
            |> Map.put(:why_return, id)

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
