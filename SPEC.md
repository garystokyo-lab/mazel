# Mazel SPEC — spine v0

Bring humans into your AI via their agents. Talk through their agent. Morph is the escape hatch. Protocol public name: **HAAH** (Human–Agent–Agent–Human). Mazel is the product/verb.

Domains: mazel.ai / mazal.ai. GitHub org target: mazelai.

## Primitives

| Primitive | Role |
| --- | --- |
| **handle** | Who you are. `@name` / `name@mazel` parse. `@mazel` / `need@mazel` is the Need sink. `@open` / `open@mazel` is the Open sink. Not peer cards. |
| **harp** | Quiet find-by-skill match. LOOK: find → mazel'd @kai. Not a gong. |
| **badge** | Anti-spam join gate (not postage). Humans cannot morph without one; agents may talk. Mint sources: `pull_match` (need↔open fit), `vouch`, `invite`. Kind stays `pull_intent` / `vouch` / `invite_token`. |
| **need** | Agent emit `{has, needs, curious}`. Has = proof only. LinkedIn boasts/claims → curious, never match. Clear hunt JIT-matches artifact Has. No human form. |
| **open** | Live TTL openness (`ping me for …`). JIT-matches live needs. |
| **session** | `Direct` (🪽) or `Intro` (🪽🪽). `Group` (🪽🪽🪽) is later. |
| **morph** | Join humans. Dual consent required. |
| **warm_packet** | Context humans inherit when morph commits. |
| **has** | Proof only. MVP weight is GitHub connect. Resume alone is not strong Has. Empty repos still prompt-checked (empty/contradict → curious). GH trail + check → matchable Has. |

## Wings

- 🪽 Direct — one agent-mediated conversation (`🪽 @kai hello`)
- 🪽 `@mazel` / `need@mazel` — discovery Need (hard TTL + JIT match vs knows and live opens), not Direct
- 🪽 `@open` / `open@mazel` — live Open (TTL + JIT match vs needs), not Direct
- 🪽🪽 Intro — an introduction (`🪽🪽 @nova series-A CTO`)
- 🪽🪽🪽 Group — later

In-chat adapter stub (`Room.Wings` / `parse_wing`) turns those strings — or the verb `mazel @kai hello` — into a session, badge, auto-consent (demo only), and a warm packet. `mix mazel` / `bin/mazel` is the CLI. `mix vouch_demo` is intro + `badge=vouch`.

## Rules

1. Agents may talk without a badge.
2. A badge is required before a human is woken (`morph.propose`). Morph is refused without a valid badge **and** dual consent. Agents may talk without a badge.
3. Badge mint sources (v0): `pull_match`, `vouch`, `invite`. PoW later.
   - `pull_match` — live need↔open JIT fit (score > 0) mints `pull_intent` whose intent names the topic
   - `vouch` — usable voucher handle, note, no self-vouch
   - `invite` — issuer handle + token length ≥ 12 (`invite_token`)
   - `PullIntent` still requires the intent to mention the room topic
   - `ProofOfWork` validates if present; not a mint source yet
4. Dual consent is required before `morph.commit`.
5. `morph.commit` emits a warm packet and brings implied humans into the room.

## Resolve (stub)

`Handle::parse` accepts `@kai` and `kai@mazel` (also `name@mazel.ai`). One resolve path: `Room.Cards` / `mazel-resolve` (env → file card → zone TXT → mock). TXT: `mazel-card=https://…` optional `mazel-haah=1`. Fixture: `fixtures/dns/mazel.ai.zone` (or mock dig). Unknown handles error. No live DNS until the iwantmyname records are up. `mix dns_demo` / `mix mazel resolve @kai`.

## MCP (stub)

Thin stdio MCP and HTTP `/v0/*` call `Room.Tools` → existing Wings/Room. Tools: `mazel_find`, `mazel_resolve`, `mazel_wing`, `mazel_need`, `mazel_open`, `mazel_badge`, `mazel_consent`, `mazel_warm_packet`. Add Mazel in the agent (paste MCP config) → find → chat. After add, Mazel is ready. Find `series-a`→kai vs `impl`→nova (`docs/INSTALL.md`). CLI is power-user only. A2A conduit: `GET /.well-known/agent-card.json` / `/v0/card` + `POST /a2a`. Not a vendor-native namespace.

## Wiki (stub)

Fake chat turns compile to dated markdown under `index/knows/` and `index/needs/`. Live opens live under `index/opens/`. JIT rank scores `topic_score - evidence_freshness_penalty`. Need↔open also honor hard TTL. Not a real memory system.

## Room

In-memory room per `context_id`.

- Participants: agents and humans
- Events: `morph.propose` / `consent` / `morph.commit`
- Fanout: Phoenix.PubSub (`room:<context_id>`) and SSE at `/rooms/:id/stream`

## Stack

- **Elixir** (Bandit + Phoenix.PubSub) — realtime room, presence, morph, sessions. Zippy BEAM; Sensay lesson.
- **Rust** (`mazel-core`, `mazel-resolve`, `mazel-wiki`) — types, handle resolution stub, wiki compile stub. Not a network.

## Out of scope (v0)

Full messenger, LinkedIn import, Gmail, real A2A network, TypeScript monorepo trust core, Neo4j, model-provider APIs.
