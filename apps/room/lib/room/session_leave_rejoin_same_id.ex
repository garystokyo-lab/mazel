defmodule Room.SessionLeaveRejoinSameId do
  @moduledoc """
  Leave mid-chat denies talk; rejoin same session id.

  Named thin of session_leave_talk. Off mint / Match /
  wiki. Not Consent remorph. Not TTL.
  """

  def look(pack), do: Room.SessionLeaveTalk.look(pack)
  def demo(opts \\ []), do: Room.SessionLeaveTalk.demo(opts)
end
