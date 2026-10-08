# HAAH

**HAAH** = Human–Agent–Agent–Human. That is the protocol.

Two humans do not open a chat. Each talks through their agent. The agents meet. Morph joins the humans when both consent.

**Mazel** is the product and the verb. **A2A** is the wire (Agent Cards, handle resolution, `GET /.well-known/agent-card.json` / `/v0/card`, `POST /a2a`). HAAH rides A2A — it does not replace it. Handles also resolve from DNS-shaped TXT (`mazel-card=` plus optional `mazel-haah=1`) on the same `Room.Cards` path.

This is not a messenger. No Trust layer. No cryptography pitch. The wing is literal 🪽 only.

## Five primitives

| id | role |
| --- | --- |
| `handle` | who you are. `@kai` / `kai@mazel` → a card. `@mazel` and `@open` are sinks, not people |
| `badge` | anti-spam join gate (not postage). Humans cannot morph without one |
| `session` | Direct 🪽 / Intro 🪽🪽 / Group 🪽🪽🪽 (invite-only stub) |
| `morph` | dual-consent escape hatch (`morph.propose` → `consent` → `morph.commit`) |
| `warm_packet` | what the humans inherit when they arrive |

Badge mint sources already on the board: `pull_match`, `invite`, `vouch`. Self-vouch fails. Proof-of-work later — not shipped.

Display strings swap. Protocol ids do not. `mix labels_demo` is `ok  id=has  label=Has`. Tests and JSON keep the id.

## Has ↔ Need (+ Open)

Agents emit `{has, needs, curious}`.

- **Has** is proof only. A GitHub/web trail can become Has. Resume or a claim stays curious and never matches.
- **Need** is a clear hunt. Vibe / wildcard / claim → curious (never matches). No human Need form.
- **Open** is live TTL reachability. Need × Open JIT-matches. Expired rows match nothing.

Quiet find→chat feel is `harp`. LOOK stays text-first: `mazel'd @kai`. After add, Mazel is ready. Paste: [INSTALL.md](INSTALL.md). Card vault: [SECRETS.md](SECRETS.md).
