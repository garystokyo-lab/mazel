defmodule Room.SelfMint do
  @moduledoc """
  Self cannot mint a badge. Day-one sources stay invite,
  pull_match, and vouch-from-other. No PoW. No messenger.
  """

  def look_self, do: "error  mint=self  error=self_vouch"

  def look_invite(badge) when is_map(badge) do
    "ok  mint=#{badge["source"] || badge[:source]}  badge=#{badge["kind"] || badge[:kind]}"
  end

  def look_pull(badge) when is_map(badge) do
    "ok  mint=#{badge["source"] || badge[:source]}  badge=#{badge["kind"] || badge[:kind]}"
  end

  def look_vouch_self, do: "error  vouch=self  error=self_vouch"

  def look_vouch_other(rec), do: Room.Has.look_vouch(rec)

  def look(pack) when is_map(pack) do
    [
      look_self(),
      look_invite(pack.invite),
      look_pull(pack.pull),
      look_vouch_self(),
      look_vouch_other(pack.vouch)
    ]
  end

  def look(_), do: look(%{invite: %{}, pull: %{}, vouch: %{}})

  @doc """
  Self-mint refused. Invite / pull_match / other-vouch still mint.
  Isolated Has write. Does not rewrite badge_demo LOOK.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-self-mint-#{System.unique_integer([:positive])}")
          File.mkdir_p!(Path.join(path, "index/has"))
          {path, true}
      end

    try do
      demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp demo_on(root) do
    File.cp!(
      Path.join(Room.Index.repo_root(), "index/has/kai.md"),
      Path.join(root, "index/has/kai.md")
    )

    fixtures = Room.Index.fixtures_root()
    need = Room.Index.get(fixtures, "need", "need-enterprise-ai")
    open = Room.Index.get(fixtures, "open", "open-enterprise-ai")

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
         {:error, :self_vouch} <- Room.Badge.mint(:self, actor: kai),
         {:ok, invite} <- Room.Invite.mint(issuer: ariel),
         {:ok, pull} <- pull_mint(need, open, ariel),
         {:error, :self_vouch} <- Room.Badge.mint(:vouch, voucher: kai, subject: kai, note: "I know me."),
         {:error, :self_vouch} <- Room.Has.vouch("kai@mazel", "kai@mazel", root: root),
         {:ok, vouch} <- Room.Has.vouch("ariel@mazel", "kai@mazel", root: root) do
      cond do
        "self" in Room.Badge.mint_sources() ->
          {:error, :self_is_source}

        invite["source"] != "invite" or invite["kind"] != "invite_token" ->
          {:error, :invite_miss}

        pull["source"] != "pull_match" or pull["kind"] != "pull_intent" ->
          {:error, :pull_miss}

        vouch.status != "has" or vouch.vouched_by != "ariel@mazel" ->
          {:error, :vouch_miss}

        true ->
          pack = %{invite: invite, pull: pull, vouch: vouch, self: :self_vouch}
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
