defmodule Room.PullMint do
  @moduledoc """
  Find → mazel'd → pull-match mint → morph.

  Agents talk free. Morph still needs the badge. Invite stays
  the other day-one path. No messenger.
  """

  def look(pack) when is_map(pack) do
    peer = pack[:peer] || "kai@mazel"
    skill = pack[:skill] || "series-a"
    local = peer |> to_string() |> String.split("@") |> hd()

    [
      "ok  find=#{skill}→#{peer}  mazel'd @#{local}",
      "ok  mint=pull_match  badge=pull_intent",
      "ok  morph=morph.commit  badge=pull_intent  consent=dual"
    ]
  end

  def look(_), do: look(%{})

  @doc """
  Find → mint → morph plus the human-visible warm strip.
  Does not change standalone pull_mint / warm_packet LOOK.
  """
  def look_warm(pack) when is_map(pack) do
    look(pack) ++ Room.Warm.fields(pack)
  end

  def look_warm(_), do: look_warm(%{from: "ariel@mazel", peer: "kai@mazel", state: %{}})

  @doc """
  Find → mint → morph → warm plus the return wrap beat.
  Does not change standalone return / warm_pull LOOK.
  """
  def look_return(pack) when is_map(pack) do
    look_warm(pack) ++ [Room.Return.look(pack[:wrapped])]
  end

  def look_return(_),
    do: look_warm(%{from: "ariel@mazel", peer: "kai@mazel", state: %{}}) ++ [Room.Return.look()]

  @doc """
  Real find of series-a→kai, Need×Has mint, mazel'd chat, dual morph.
  Isolated tmp for Need/Has. Does not rewrite badge_demo LOOK.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-pull-mint-#{System.unique_integer([:positive])}")
          File.mkdir_p!(Path.join(path, "index/has"))
          File.mkdir_p!(Path.join(path, "index/needs"))
          {path, true}
      end

    try do
      demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp demo_on(root) do
    now = ~U[2026-09-11 12:00:00Z]
    dest = Path.join(root, "index/has/kai.md")
    File.cp!(Path.join(Room.Index.repo_root(), "index/has/kai.md"), dest)

    with {:ok, found} <- Room.Find.query("series-a"),
         {:ok, need} <- Room.Need.seed("founders-investors", root: root, now: now),
         {:ok, match} <- Room.Need.match_has(need, root: root, now: now),
         {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
         {:ok, badge} <- Room.Badge.from_need_has(need, match, ariel),
         {:ok, chat} <- Room.Tools.wing(Room.Find.wing_at(match.handle)),
         {:ok, state} <- morph(ariel, kai, badge) do
      cond do
        get_in(found, [:hits, Access.at(0), :handle]) != "kai@mazel" ->
          {:error, :find_miss}

        match.handle != "kai@mazel" or match[:unfit] ->
          {:error, :has_miss}

        badge["source"] != "pull_match" or badge["kind"] != "pull_intent" ->
          {:error, :bad_mint}

        not chat.ok or chat.handle != "kai@mazel" ->
          {:error, :chat_miss}

        state.status != :morphed or not state.dual_consent ->
          {:error, :morph_miss}

        true ->
          pack = %{
            skill: "series-a",
            from: "ariel@mazel",
            peer: "kai@mazel",
            badge: badge,
            state: state,
            match: match,
            find: found
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  @doc """
  Same find→mint→morph path as `demo/1`, with warm fields appended.
  """
  def warm_demo(opts \\ []) do
    case demo(opts) do
      {:ok, pack} -> {:ok, Map.put(pack, :lines, look_warm(pack))}
      other -> other
    end
  end

  @doc """
  Same find→mint→morph→warm path, then humans drop back.
  Agents keep the thread. Morph surface closes.
  """
  def return_demo(opts \\ []) do
    case demo(opts) do
      {:ok, pack} ->
        wrap_return(pack)

      other ->
        other
    end
  end

  defp wrap_return(pack) do
    context_id = pack.state[:context_id] || pack.state["context_id"]

    case Room.Return.wrap(context_id) do
      {:ok, wrapped} ->
        if wrapped.status == :returned and wrapped.session == "agent" and
             wrapped.morph == "closed" do
          pack =
            pack
            |> Map.put(:wrapped, wrapped)
            |> Map.put(:lines, look_return(Map.put(pack, :wrapped, wrapped)))

          {:ok, pack}
        else
          {:error, :return_miss}
        end

      other ->
        other
    end
  end

  defp morph(from, peer, badge) do
    context_id = "pull-mint-" <> random_id()

    {:ok, _} =
      Room.open(context_id, :direct, [
        %{handle: Map.take(from, [:id, :card_url]), role: :agent},
        %{handle: Map.take(peer, [:id, :card_url]), role: :agent}
      ])

    {:ok, _} = Room.submit_badge(context_id, badge)
    {:ok, _} = Room.propose_morph(context_id, from.id)
    {:ok, _} = Room.consent(context_id, from.id)
    {:ok, _} = Room.consent(context_id, peer.id)

    Room.commit_morph(
      context_id,
      "Find minted pull-match. Humans may join.",
      [
        %{speaker: Map.take(from, [:id, :card_url]), text: "Ariel is up."},
        %{speaker: Map.take(peer, [:id, :card_url]), text: "Kai is up. Morph."}
      ]
    )
  end

  defp random_id do
    :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
  end
end
