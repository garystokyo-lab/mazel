defmodule Room.Return do
  @moduledoc """
  After morph.commit + warm packet, humans drop back.
  Agents keep the thread. Morph surface closes.
  """

  def look(_state \\ nil) do
    "ok  return=agent  morph=closed  session=agent"
  end

  def after_warm(result, wrapped \\ nil) do
    Room.Warm.look(result) ++ [look(wrapped)]
  end

  def wrap(context_id) when is_binary(context_id) do
    Room.return(context_id)
  end
end
