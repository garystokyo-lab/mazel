defmodule Room.ConsentRevokeMidSession do
  @moduledoc """
  After dual yes + humans joined, one revokes.

  Humans out. Agents stay. Named thin of
  agent_stay_presence_revoke_mid. Off Match / wiki.
  """

  def look(pack), do: Room.AgentStayPresenceRevokeMid.look(pack)
  def demo(opts \\ []), do: Room.AgentStayPresenceRevokeMid.demo(opts)
end