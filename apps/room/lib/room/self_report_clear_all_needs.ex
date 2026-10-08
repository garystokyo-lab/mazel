defmodule Room.SelfReportClearAllNeeds do
  @moduledoc """
  Cast two Needs, both find; clear all → find none.

  Named thin of self_report_multi_need_clear_both.
  Off PDF / badge / GH / score / wiki / morph / toolbelt.
  """

  def look(pack), do: Room.SelfReportMultiNeedClearBoth.look(pack)
  def demo(opts \\ []), do: Room.SelfReportMultiNeedClearBoth.demo(opts)
end