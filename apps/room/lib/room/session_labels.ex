defmodule Room.SessionLabels do
  @moduledoc """
  Direct / Intro / Group show id + current label.

  Swappable table. Distinct from labels_demo (has/need/morph)
  and session_intro / session_group / match_chat_direct (no
  label table). Off mint / talk / wiki.
  """

  @swap_id :direct
  @swap_label "1:1"

  def session_ids, do: Room.Labels.session_ids()
  def swap_id, do: @swap_id
  def swap_label, do: @swap_label

  def look_line(id) do
    "ok  id=#{id}  label=#{Room.Labels.get(id)}  wing=#{Room.Types.wing_mark(id)}"
  end

  def look_swap(id, label), do: Room.Labels.look_swap(id, label)

  def look(pack \\ %{}) do
    ids = pack[:ids] || session_ids()
    Enum.map(ids, &look_line/1) ++
      [
        look_swap(@swap_id, pack[:swapped] || @swap_label),
        look_swap(@swap_id, pack[:restored] || Room.Labels.get(@swap_id))
      ]
  end

  @doc """
  Session wing ids + one swap beat (direct → 1:1 → Direct).
  Isolated. Sibling labels / intro / group LOOK stays.
  """
  def demo do
    Room.Labels.reset()

    ids = session_ids()
    rows = Enum.map(ids, &look_line/1)
    Room.Labels.put(@swap_id, @swap_label)
    swapped = look_swap(@swap_id, Room.Labels.get(@swap_id))
    Room.Labels.reset()
    restored = look_swap(@swap_id, Room.Labels.get(@swap_id))

    {:ok, %{lines: rows ++ [swapped, restored], ids: ids, swapped: @swap_label}}
  end
end
