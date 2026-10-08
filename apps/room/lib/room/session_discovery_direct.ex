defmodule Room.SessionDiscoveryDirect do
  @moduledoc """
  Pick a discovery handle and open Direct talk.

  need@mazel lists handles. pick/direct @kai talks.
  Morph denied without a badge. Distinct from
  session_discovery (list only) and match_chat_direct
  (no discovery lead-in). Off wiki / stamp / score.
  """

  def look_discovery(handles \\ ["kai@mazel"]),
    do: Room.SessionDiscovery.look_discovery(handles)

  def look_pick(handle \\ "kai@mazel") do
    local = handle |> to_string() |> String.trim_leading("@") |> String.split("@") |> hd()
    "ok  pick=@#{local}  direct=@#{local}  morph=none"
  end

  def look_talk, do: Room.MatchChat.look_talk(%{local: "kai"}, 1)
  def look_denied, do: Room.TalkNoMorph.look_denied()

  def look(pack) when is_map(pack) do
    [look_discovery(pack[:handles]), look_pick(pack[:picked]), look_talk(), look_denied()]
  end

  def look(_), do: look(%{handles: ["kai@mazel"], picked: "kai@mazel"})

  @doc """
  Discovery handles → pick @kai → Direct talk. Morph denied.
  Isolated. Sibling list / direct LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "session-disco-direct-" <> random_id()

    with {:ok, listed} <- Room.SessionDiscovery.demo(context_id: prefix <> "-list"),
         picked when is_binary(picked) <-
           Room.SessionDiscovery.pick(listed.handles, Keyword.get(opts, :pick) || "@kai"),
         {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup(picked),
         {:ok, opened} <-
           Room.open(prefix <> "-talk", :direct, [
             %{handle: ariel, role: :agent},
             %{handle: kai, role: :agent}
           ]),
         {:ok, after_talk} <- Room.talk(prefix <> "-talk", kai, "hello"),
         {:error, :badge_required} <- Room.propose_morph(prefix <> "-talk", ariel) do
      talks = Enum.filter(after_talk.events || [], &(&1.type == "talk"))
      events = Enum.map(after_talk.events || [], & &1.type)

      cond do
        listed.handles != ["kai@mazel"] or picked != "kai@mazel" ->
          {:error, :pick_miss}

        opened.session_kind != :direct or after_talk.session_kind != :direct ->
          {:error, :not_direct}

        after_talk.badge != nil or "morph.commit" in events ->
          {:error, :morphed}

        length(talks) != 1 or after_talk.status != :open ->
          {:error, :talk_miss}

        humans_awake?(after_talk) or humans_awake?(listed.session) ->
          {:error, :human_woke}

        true ->
          pack = %{
            handles: listed.handles,
            picked: picked,
            listed: listed,
            session: after_talk,
            denied: :badge_required
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    else
      nil -> {:error, :pick_miss}
      other -> other
    end
  end

  defp humans_awake?(state) do
    Enum.any?(state.participants || [], fn p -> (p[:role] || p.role) == :human end)
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end
