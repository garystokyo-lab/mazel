defmodule Room.PostageSources do
  @moduledoc """
  One-strip mint sources: invite / pull_match / vouch-from-other / pow.

  Day-one `mint_sources()` stay pull_match, vouch, invite.
  pow is optional alternate. Self still fails.
  Does not rewrite invite / pull_mint / self_mint / pow_mint LOOK.
  """

  def look_invite(badge) when is_map(badge) do
    "ok  mint=#{badge["source"] || badge[:source]}  badge=#{badge["kind"] || badge[:kind]}"
  end

  def look_invite(_), do: "ok  mint=invite  badge=invite_token"

  def look_pull(badge) when is_map(badge) do
    "ok  mint=#{badge["source"] || badge[:source]}  badge=#{badge["kind"] || badge[:kind]}"
  end

  def look_pull(_), do: "ok  mint=pull_match  badge=pull_intent"

  def look_vouch(badge, from \\ "ariel@mazel", to \\ "kai@mazel") do
    source = (badge && (badge["source"] || badge[:source])) || "vouch"
    kind = (badge && (badge["kind"] || badge[:kind])) || "vouch"
    "ok  mint=#{source}  badge=#{kind}  from=#{from}→#{to}"
  end

  def look_pow(badge) when is_map(badge) do
    "ok  mint=#{badge["source"] || badge[:source]}  badge=#{badge["kind"] || badge[:kind]}"
  end

  def look_pow(_), do: "ok  mint=pow  badge=proof_of_work"

  def look_self, do: "error  mint=self  error=self_vouch"

  def look(pack) when is_map(pack) do
    from = pack[:from] || "ariel@mazel"
    to = pack[:to] || "kai@mazel"

    [
      look_invite(pack.invite),
      look_pull(pack.pull),
      look_vouch(pack.vouch, from, to),
      look_pow(pack.pow),
      look_self()
    ]
  end

  def look(_), do: look(%{invite: %{}, pull: %{}, vouch: %{}, pow: %{}})

  @doc """
  Mint invite, pull_match, vouch-from-other, and optional pow.
  Self fails. Isolated. Sibling mint LOOK stays.
  """
  def demo(_opts \\ []) do
    fixtures = Room.Index.fixtures_root()
    need = Room.Index.get(fixtures, "need", "need-enterprise-ai")
    open = Room.Index.get(fixtures, "open", "open-enterprise-ai")

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
         {:ok, invite} <- Room.Invite.mint(issuer: ariel),
         {:ok, pull} <- pull_mint(need, open, ariel),
         {:ok, vouch} <-
           Room.Badge.mint(:vouch, voucher: ariel, subject: kai, note: "vouch-from-other"),
         {:ok, answer} <- Room.PowMint.solve(Room.PowMint.challenge()),
         {:ok, pow} <-
           Room.Badge.mint(:pow,
             challenge: Room.PowMint.challenge().id,
             response: answer,
             nonce: answer,
             difficulty: Room.PowMint.difficulty(),
             actor: ariel
           ),
         {:error, :self_vouch} <- Room.Badge.mint(:self, actor: kai),
         {:error, :self_vouch} <-
           Room.Badge.mint(:vouch, voucher: kai, subject: kai, note: "I know me.") do
      cond do
        "pow" in Room.Badge.mint_sources() ->
          {:error, :pow_is_source}

        Room.Badge.mint_sources() != ~w(pull_match vouch invite) ->
          {:error, :mint_sources}

        invite["source"] != "invite" or invite["kind"] != "invite_token" ->
          {:error, :invite_miss}

        pull["source"] != "pull_match" or pull["kind"] != "pull_intent" ->
          {:error, :pull_miss}

        vouch["source"] != "vouch" or vouch["kind"] != "vouch" ->
          {:error, :vouch_miss}

        pow["source"] != "pow" or pow["kind"] != "proof_of_work" ->
          {:error, :pow_miss}

        true ->
          pack = %{
            invite: invite,
            pull: pull,
            vouch: vouch,
            pow: pow,
            from: ariel.id,
            to: kai.id,
            self: :self_vouch
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp pull_mint(need, open, actor) do
    matches = Room.Need.match(need, Room.Index.fixtures_root())
    hit = Enum.find(matches, &(&1.id == open.id and &1.kind == "open"))

    if is_nil(hit) do
      {:error, :no_pull_match}
    else
      Room.Badge.mint(:pull_match, need: need, open: open, match: hit, actor: actor)
    end
  end
end