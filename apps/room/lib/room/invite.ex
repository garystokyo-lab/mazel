defmodule Room.Invite do
  @moduledoc """
  Invite-token badge mint. No pull-match. Distinct from `badge_demo`.
  """

  @token "invite-token-v0"

  def token, do: @token

  @doc "Mint source `invite` → kind `invite_token`. No need↔open fit."
  def mint(opts \\ []) do
    issuer = Keyword.get(opts, :issuer) || "ariel@mazel"
    token = Keyword.get(opts, :token) || @token

    with {:ok, issuer} <- resolve_issuer(issuer) do
      Room.Badge.mint(:invite, issuer: issuer, token: token)
    end
  end

  defp resolve_issuer(%{id: id} = handle) when is_binary(id), do: {:ok, handle}
  defp resolve_issuer(raw) when is_binary(raw), do: Room.Cards.lookup(raw)
  defp resolve_issuer(_), do: {:error, :missing_issuer}

  @doc """
  Direct mazel path mints invite_token. Not pull_match. Not the
  isolated invite gate strip (talk-denied / self-vouch).
  """
  def look_direct(%{handle: handle}) do
    [
      "ok  verb=mazel  kind=direct  handle=#{handle}",
      "ok  mint=invite  badge=invite_token",
      "ok  morph=morph.commit  badge=invite_token  consent=dual"
    ]
  end

  def look_direct(_), do: look_direct(%{handle: "kai@mazel"})

  def look(%{badge: badge, denied: denied, morph: morph, self: self}) do
    kind = badge["kind"] || badge[:kind]
    source = badge["source"] || badge[:source]

    [
      "ok  mint=#{source}  badge=#{kind}",
      "ok  talk=free  morph=denied  denied=#{denied}",
      "ok  morph=#{morph}  badge=#{kind}  consent=dual",
      "error  vouch=self  error=#{self}"
    ]
  end

  def demo(opts \\ []) do
    context = Keyword.get(opts, :context_id) || "invite-" <> random_id()

    with {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
         {:ok, badge} <- mint(issuer: ariel) do
      denied = deny_without_badge(ariel, kai)
      morph = commit_with_invite(context, ariel, kai, badge)
      self = self_vouch(kai)

      cond do
        badge["source"] != "invite" or badge["kind"] != "invite_token" ->
          {:error, :not_invite}

        badge["source"] == "pull_match" or badge["kind"] == "pull_intent" ->
          {:error, :pull_match}

        denied != :badge_required ->
          {:error, :no_deny}

        morph != "morph.commit" ->
          {:error, :no_commit}

        self != :self_vouch ->
          {:error, :self_vouch_broke}

        true ->
          pack = %{badge: badge, denied: denied, morph: morph, self: self}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  @doc """
  `mazel @kai` is Direct. Invite mints the badge. Morph commits.
  Isolated from invite_demo LOOK.
  """
  def direct_demo(opts \\ []) do
    context = Keyword.get(opts, :context_id) || "invite-direct-" <> random_id()

    with {:ok, cmd} <- Room.Wings.parse("mazel @kai hello"),
         {:ok, ariel} <- Room.Cards.lookup("@ariel"),
         {:ok, kai} <- Room.Cards.lookup("@kai"),
         {:ok, badge} <- mint(issuer: ariel) do
      morph = commit_with_invite(context, ariel, kai, badge)

      cond do
        cmd.session_kind != :direct or cmd.verb != true ->
          {:error, :not_direct}

        cmd.target.id != "kai@mazel" ->
          {:error, :handle_miss}

        badge["source"] != "invite" or badge["kind"] != "invite_token" ->
          {:error, :not_invite}

        badge["source"] == "pull_match" or badge["kind"] == "pull_intent" ->
          {:error, :pull_match}

        morph != "morph.commit" ->
          {:error, :no_commit}

        true ->
          pack = %{handle: "kai@mazel", badge: badge, morph: morph, verb: cmd}
          {:ok, Map.put(pack, :lines, look_direct(pack))}
      end
    end
  end

  defp deny_without_badge(ariel, kai) do
    id = "invite-deny-" <> random_id()

    {:ok, talking} =
      Room.open(id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}])

    if talking.badge != nil do
      :talk_had_badge
    else
      case Room.propose_morph(id, ariel) do
        {:error, :badge_required} -> :badge_required
        other -> other
      end
    end
  end

  defp commit_with_invite(context_id, ariel, kai, badge) do
    {:ok, _} =
      Room.open(context_id, :direct, [%{handle: ariel, role: :agent}, %{handle: kai, role: :agent}])

    {:ok, _} = Room.submit_badge(context_id, badge)
    {:ok, _} = Room.propose_morph(context_id, ariel)
    {:ok, _} = Room.consent(context_id, ariel)
    {:ok, _} = Room.consent(context_id, kai)
    {:ok, state} = Room.commit_morph(context_id, "Invite token minted. Humans may join.", [])

    if state.badge["source"] == "invite" and state.badge["kind"] == "invite_token" and
         state.dual_consent do
      "morph.commit"
    else
      :bad_commit
    end
  end

  defp self_vouch(kai) do
    case Room.Badge.mint(:vouch, voucher: kai, subject: kai, note: "I know me.") do
      {:error, :self_vouch} -> :self_vouch
      other -> other
    end
  end

  defp random_id do
    :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
  end
end
