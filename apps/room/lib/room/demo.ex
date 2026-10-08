defmodule Room.Demo do
  @moduledoc """
  Two mock agents, Direct session, badge, dual consent, morph.commit, warm packet.
  No model APIs.
  """

  @nova Room.Types.handle!("nova.ariel@mazel.ai", "https://mazel.ai/cards/nova")
  @kai Room.Types.handle!("kai.sam@mazel.ai", "https://mazel.ai/cards/kai")

  def run(context_id \\ nil) do
    context_id = context_id || ("morph-" <> random_id())

    {:ok, _} =
      Room.open(context_id, :direct, [
        %{handle: @nova, role: :agent},
        %{handle: @kai, role: :agent}
      ])

    badge = %{
      kind: "pull_intent",
      actor: @nova,
      intent: "Wake Ariel and Sam so they can see the morph path on spine v0."
    }

    {:ok, _} = Room.submit_badge(context_id, badge)
    {:ok, _} = Room.propose_morph(context_id, @nova)
    {:ok, _} = Room.consent(context_id, @nova)
    {:ok, _} = Room.consent(context_id, @kai)

    {:ok, state} =
      Room.commit_morph(
        context_id,
        "Agents aligned on spine v0. Humans inherit the room.",
        transcript()
      )

    {:ok, state}
  end

  def print do
    {:ok, state} = run()
    IO.puts(banner())
    IO.puts("context     #{state.context_id}")
    IO.puts("session     #{Room.Labels.format(state.session_kind)} #{state.wings}")
    IO.puts("status      #{state.status}")
    IO.puts("#{pad(:badge)}  kind=#{state.badge["kind"]}")
    IO.puts("#{pad(:consent)}  dual=#{state.dual_consent}")
    IO.puts("")
    IO.puts("events")

    Enum.each(state.events, fn event ->
      IO.puts("  • #{Room.Labels.format(event.type)}")
    end)

    IO.puts("")
    IO.puts("#{Room.Labels.format(:warm_packet)}")
    IO.puts(Jason.encode!(state.warm_packet, pretty: true))
    state
  end

  def transcript do
    [
      %{speaker: @nova, text: "Shipping spine v0 — room, badge, morph. No messenger."},
      %{speaker: @kai, text: "Badge before wake. Dual consent before morph."},
      %{speaker: @nova, text: "The humans should see the commit path. Proposing morph."},
      %{speaker: @kai, text: "Consenting. Hand them a warm packet."}
    ]
  end

  defp banner do
    """

    ── Mazel ─────────────────────────────────────────
    Find → chat. Morph when the humans join.
    ──────────────────────────────────────────────────
    """
  end

  defp pad(id) do
    String.pad_trailing(Room.Labels.format(id), 22)
  end

  defp random_id do
    :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
  end
end
