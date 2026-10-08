defmodule Room.Ready do
  @moduledoc """
  Ready path LOOK. Add Mazel in-agent → Mazel is ready → find → chat.

  No terminal on this path. Smoke may still call `mix ready_demo`.
  """

  def add_lines do
    [
      "1) add      Mazel",
      "   Mazel is ready."
    ]
  end

  def look(contrast) do
    add_lines() ++ Room.Find.look_chat(contrast)
  end
end
