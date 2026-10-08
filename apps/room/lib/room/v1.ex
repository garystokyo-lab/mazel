defmodule Room.V1 do
  @moduledoc """
  Find by skill → mazel chat. Morph is later, not the LOOK.

  File cards. No DNS.
  """

  def run(opts \\ []) do
    from_raw = Keyword.get(opts, :from) || "ariel"
    peer_raw = Keyword.get(opts, :peer) || "kai"

    with {:ok, contrast} <- Room.Find.contrast(),
         {:ok, from} <- Room.Human.require_card(from_raw, :from),
         {:ok, peer} <- Room.Human.require_card(peer_raw, :peer),
         {:ok, badge} <- mint_badge(from),
         {:ok, state} <- play(from, peer, badge) do
      {:ok, %{from: from, peer: peer, badge: badge, state: state, contrast: contrast}}
    end
  end

  def look(%{contrast: contrast}) do
    contrast |> Room.Find.look_chat() |> Enum.join("\n")
  end

  def look(_), do: "ok  find=series-a→kai@mazel  mazel'd @kai"

  defp mint_badge(from) do
    root = Room.Index.fixtures_root()
    need = Room.Index.get(root, "need", "need-enterprise-ai")

    if is_nil(need) do
      {:error, :no_pull_match}
    else
      Room.Badge.from_need_matches(need, Room.Need.match(need, root), from)
    end
  end

  defp play(from, peer, badge) do
    context_id = "v1-" <> random_id()

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
      "v1 Direct. #{from.id} and #{peer.id}. Humans inherit this packet.",
      [
        %{speaker: Map.take(from, [:id, :card_url]), text: "Ariel is up."},
        %{speaker: Map.take(peer, [:id, :card_url]), text: "Buddy is up. Morph."}
      ]
    )
  end

  defp random_id do
    :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
  end
end
