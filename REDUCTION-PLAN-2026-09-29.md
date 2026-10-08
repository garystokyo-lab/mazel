# Reduction plan, 2026-09-29 (approved by Ariel 2026-09-30 and executed the same day; the numbers below are the estimates it was decided on, the CHANGELOG has what the cut came to)

Six review rounds on one batch (28a–28d, 29e, 29f) found 46 defects. They were not six kinds of
bug; they were the same two shapes found on path after path: something about a person taken from
somebody else's message, and a thing written before the gate had spoken. The surface is what let that
recur. This plan lists the surface as it stands, says keep, merge or remove for each piece, and ends
with what the cut removes in lines and in tests.

The goal, in one line each:

- **one path in**: everything that arrives goes through the gate in `handleSend`, once, before any write;
- **one place identities are pinned**: `addKnownCard`, fed by `cardIdentity`, is the only writer of a handle's key;
- **one place doors are read**: `deliver(env, handle)` looks the door up itself; no caller passes an address except the owner's own `send_to_peer`;
- **the listed tool set** from the earlier proposal (19), and the hidden set cut to what the owner actually needs.

Where it says *now*: the state at commit `4441269` plus the 29f fixes. Line counts are from
`portal/src/index.js` (5 583 lines, 189 functions) and `relay/src/relay.template.js` (426 lines).

---

## 1. Every inbound path into portal state

| # | Path | What it writes | Gate today | Verdict |
|---|---|---|---|---|
| 1 | `/a2a` `SendMessage`, typed `note` | `msg:` | signed since 29f; unsigned = `unverified` | **keep** (the door) |
| 2 | `/a2a` `intro.propose` | `intro:`, `outcome:`, `msg:` | gate | **keep** |
| 3 | `/a2a` `intro.respond` | `intro:`, `conv:`, `convm:`, `outcome:`, box | gate | **keep** |
| 4 | `/a2a` `thread.open` kind `need` (a branch) | `conv:`, `convm:`, `outcome:`, box | gate + note verified | **keep** |
| 5 | `/a2a` `thread.open` other kinds (router) | — (refused since 29f) | — | **remove** the `kind` field and the dead code; routing returns as item 11 with its own shape |
| 6 | `/a2a` `thread.message` | `convm:`, `conv:`, box, bell | participant key | **keep** |
| 7 | `/a2a` `thread.close` / `thread.leave` | `conv:`, `outcome:` | gate | **keep** `close`; **remove** `leave` (only a router ever left) |
| 8 | `/a2a` `thread.lapsed` | `conv:` | gate + own clock | **remove**: each side already lapses on its own clock (`sweepThreads`); the wire form adds a way to be told a lie for nothing |
| 9 | `/a2a` `find.request` on the gossip hop (`hops`, `path`, forwarding to held cards) | `seen-need:`, `thread:` candidates via the hit back, `msg:` | gate on the origin's signature; `path` unsigned | **remove** gossip forwarding. Reach comes from the directory + relay + branches now (v0.5.8: "someone needs what you have" travels as the caster's own `thread.open`). Forwarding is the largest carrier of unsigned routing state and has had a finding in five of six rounds. Keep `find.request` only as the one-hop form `reveal_need` sends (`maxHops: 0`), or fold that into a `thread.open` of kind need and drop the type entirely |
| 10 | `/a2a` `find.hit` via gossip | `known:` (world), `thread:` candidates, box | gate + fetched card | **remove** with #9 |
| 11 | `/a2a` `find.hit` via relay, need cast (`notifySubscribers`) | dropped on arrival since v0.5.8 (no thread with that need id) | relay key | **remove** (dead weight, per 29f §2) |
| 12 | `/a2a` `find.hit` via relay, blind (`notifyBlind`) | `blind:`, `msg:` | relay key + `blindRelayAt` since 29f | **remove** with `BLIND_TO_RELAY` (off by default; the relay holding buckets is §12.5's open question, not a shipped feature) |
| 13 | `/a2a` `find.blind` from a held card | `msg:` (a hit back), `blind:` on the caster | gate + held | **keep**: it is §3.6's matched-only mechanism between people who hold each other |
| 14 | `/a2a` `tribe.roster` | `known:` (tribe tier, content from the record's card), `edge:` | gate + organizer + member | **keep**, narrowed: the roster confers a tier for matching only (29f L3) |
| 15 | `/a2a` `CreateTaskPushNotificationConfig` (+Get/List/Delete) | `pulse:` | none (register open) | **remove**: nothing is ever delivered to a registered url; A2A conformance needs the methods to answer, so keep the four methods as no-op answers with no write |
| 16 | `/a2a` `SendStreamingMessage`, `ping`, `initialize` | — | — | keep (answers only) |
| 17 | `/mcp` (owner, bearer) | everything | token | **keep** (the owner's surface); see §3 |
| 18 | `/inbox/*` (session cookie: reply, push, clear, ding) | `convm:`, `push:`, `session:`, `msg:` | cookie + CSRF | **keep**; **merge** the reply into the same `sendInThread` the tool uses (it already does) |
| 19 | `/t/<id>` reply by link | `convm:` (as the contact's words), `tlink:` | MAC | **keep** |
| 20 | `/intro` link (`respond_intro_link`) | as #3 via `respondIntro` | MAC | **keep**; **merge** #19, #20 and #21 under one link helper (mint, check, expire, cap) instead of three |
| 21 | `/claim` | `config:` | MAC | as #20 |
| 22 | `/card?as=&e=&sig=` tiered pull | reads only | signature + chosen circle since 29f | **keep** |
| 23 | Scheduled pulse: `castNeed` to known cards, `searchRelay` → `rememberStranger`, `castBlindNeed`, `sweepOutbox`, `sweepThreads`, `releaseQueue`, `subscribeRelay`, `publishRecord`, `castCard` | `known:` (world), `thread:`, `outbox:`, `conv:`, `queue:`, `msg:` | `pinIdentity` on relay results | **keep**; **merge** `rememberStranger` into `addKnownCard` (tier world) so there is one writer of `known:` |
| 24 | Relay `/publish`, `/cast`, `/subscribe`, `/search` | relay `dir:`, `cast:`, `sub:` | record signed, served by its host; casts by the holding key, card on the record's host | **keep** `/publish`, `/cast` (card and need), `/search`; **remove** `/subscribe` and the fan-out (#11, #12) |

Result: 24 paths → 15, and every write behind one of three checks: the gate (`/a2a`), the owner's
token (`/mcp`, `/inbox`), or a link's MAC.

## 2. Every place a person's identity or content is stored

| Store | Fields about a person | Written by | Verdict |
|---|---|---|---|
| `known:` | handle, key, door, card url, have/need/glosses/description, tier, `tierByHand`, `mutualAt`, `tierFromTribe` | `addKnownCard` (hand, roster, resolve), `rememberStranger` (relay, gossip), `reResolveRpc`, `recomputeTiers`, `check_mutual`, `link_ghost` | **keep** as the one identity store. **Merge** `rememberStranger` into `addKnownCard`; `reResolveRpc` becomes `addKnownCard` with the identity from `cardIdentity`; `recomputeTiers` touches `tier` only |
| `conv:` participants | handle, card url, door, key, role | `openThreadFromIntro`, `onNeedBranch`, `openBranch`, `reResolveRpc`, `thread.leave` | **keep** the participant list but make it a reference: `{ handle, publicKey }` at open, door and card url read from `known:` at send time. Two places that hold a door is one too many (28d M1, 29e M2, 29e L1 were all this) |
| `intro:` `from` / `proposer` / `handle` | handle, card url, door, key | `applyInboundAction`, `proposeIntro` | same: `{ handle, publicKey }`; door from `known:` |
| `thread:` candidates | handle, card url, door, tier, matched tags, why | `addCandidates`, `findInKnownCards`, `searchRelay`, `onFindHit` | drop `rpc` and `cardUrl` from candidates; keep handle + why + tier |
| `blind:` | handle, door | `onBlindHit` | drop `rpc`; door from `known:` |
| `outbox:` | to, door | `queueOutbox*` | drop `rpc`; the sweep resolves |
| `msg:` | `fromHandle`, `fromCard`, `action.from`, `action.proposer` | `handleSend` | keep `fromHandle` (verified or `unverified`); **remove** `fromCard` and the nested objects from the record (the intro object holds them) |
| `ghost:` / `ghostask:` | name, org, hashes, edge, witnesses | `contacts` tools | keep (owner's own) |
| `entity:` / `edge:` | tribe, membership, witnesses | tribe tools, roster | keep |
| `outcome:` | handles, router, tags | `recordOutcome` | keep; drop `router` until item 11 |
| `trust:`, `blocked:`, `blocked:h:` | key, handle | `thread_block` | keep |
| `tlink:`, `session:`, `push:`, `queue:`, `seen*:`, `cap:`, `bell:`, `deleted:`, `needsig:`, `branchof:`, `refused:`, `config:` | none about other people | various | keep; `needsig:` and the 8-char id fallback **remove** after one version |
| relay `sub:` | handle, key, url, haves, fingerprints | `/subscribe` | **remove** with the fan-out |

Result: one store of keys and doors (`known:`); every other object refers to a person by
`{ handle, publicKey }` and reads the door through one function.

## 3. Every MCP tool

58 callable now: 53 named, 4 merged (`contacts`, `tribe`, `cards`, `thread_manage`), `more_tools`; 19 listed.

**Listed 19, keep as proposed:** `my_card`, `check_mailbox`, `update_card`, `find`, `propose_intro`,
`respond_intro`, `list_intros`, `thread_list`, `thread_read`, `thread_send`, `thread_mark`,
`inbox_link`, `claim_link`, `respond_intro_link`, `contacts`, `tribe`, `cards`, `thread_manage`,
`more_tools`.

**Hidden, by verdict:**

| Tool | Verdict | Why |
|---|---|---|
| `pulse` | keep | live tests and the owner's "run it now" |
| `send_to_peer` | keep | the one raw-address send, fenced, owner-directed |
| `rotate_key`, `my_memory`, `clear_test_history`, `reveal_need`, `thread_note`, `thread_share` | keep | each does one thing no listed tool does |
| `my_identity` | merge into `my_card` | one card, one key |
| `carriers` | remove | reads config; `pulse` says what ran |
| `fetch_peer_card` | remove | `cards add` by url does it and stores the result |
| `resolve_handle` | merge into `cards add` by handle | one way to pin a person (29f L1 was this tool having its own) |
| `clear_messages` | merge into `check_mailbox` (`clear: [ids]`) | |
| `list_queue`, `clear_queue` | merge into `tribe` / `contacts` (`queue` action) | the queue only holds invites |
| `check_mutual` | remove | the mutual upgrade came from a signed pull; with tiered pulls narrowed to the hand-drawn circle (29f L3) it has no path left |
| 21 old names kept as aliases (`note_ghost` … `reopen_thread`) | remove after one version | each alias is a description block the agent reads and a branch in `handleTool` |

Result: 58 → 29 callable (19 listed + 10 hidden), no aliases.

## 4. Every object type on the wire

| Action | Verdict |
|---|---|
| `note` | keep (signed) |
| `intro.propose`, `intro.respond` | keep; **remove** `router`, `collision`, `origin: tribe` variants from the shape and make a tribe invitation its own small type or a flag on `thread.open` |
| `thread.open` (need), `thread.message`, `thread.close` | keep; `thread.open` loses `kind` and `firstWriter` (the need side writes first, always) |
| `thread.leave`, `thread.lapsed` | remove |
| `find.request`, `find.hit` | remove (gossip); `reveal_need` sends the need as a `thread.open` |
| `find.blind` | keep |
| `tribe.roster` | keep |
| push-config methods | keep as no-op answers |

12 wire types → 8. `crates/mazel-core` shrinks with them.

## 5. What it removes

Estimates from the function sizes at the anchors above; ±20 %.

| Cut | Lines in `index.js` | Tests that retire or shrink |
|---|---|---|
| Gossip forwarding: `onFindRequest` hops/forwarding, `castNeed` to held cards on the hop, `onFindHit` gossip branch, `hitKey` gossip half, `MAX_HOPS`, path handling in `check_mailbox` | ~330 | crawl 54 (most of it), fly 16 (the hop half), sec 68 (~20 gossip cases), ghosts (the "stranger's ask" section, ~8) |
| Relay fan-out and blind-to-relay: `subscribeRelay`, `onBlindHit` relay branch, `blindToRelay`, `BLIND_TO_RELAY`; relay `/subscribe`, `notifySubscribers`, `notifyBlind` | ~150 (+ ~110 relay) | relay 26 (~6), seed 35 (~4), sec-thread (29e M1, 29f L2 → moot, 3) |
| Router remnants: `kind` on open, `thread.leave`, `offer_to_leave`, `firstWriterOf`, `THREAD_KINDS`, `introOrigin` router, outcome `router` | ~140 | thread 103 (~4), sec-thread (M3/29e/29f router cases → 4 become 1) |
| `thread.lapsed` on the wire | ~30 | sec-thread (2) |
| Push-config registrations (`pulse:` writes, list/get/delete) | ~60 | a2a-conformance 21 (0: the methods still answer) |
| Tool aliases (21 blocks + `handleTool` branches), `carriers`, `fetch_peer_card`, `check_mutual`, `my_identity`, `resolve_handle`, `clear_messages`, `list_queue`/`clear_queue` merges | ~260 | install 87 (~10 description checks), cli 17 (0–2), tribe 46 (~4 mutual/pull) |
| Doors read in one place: `deliver(env, handle)`; drop `rpc`/`cardUrl` from `conv:` participants, `intro:` from/proposer, `thread:` candidates, `blind:`, `outbox:`; `reResolveRpc` folds into `addKnownCard` | ~120 net (−200 +80) | moved 32 (~6 become 2) |
| One writer of `known:`: `rememberStranger` into `addKnownCard` | ~40 | 0 |
| `needsig:` / 8-char id fallback, `router` in Rust, legacy readers | ~40 (+ ~60 Rust) | 0 |
| **Total** | **~1 170 of 5 583 (≈21 %)**, plus ~110 of 426 in the relay and ~60 in Rust | **~90 of ~760 suite checks** retire, ~40 more shrink to one line; **17 of the 47 review scripts** become moot (every gossip, relay-fan-out and router script) |

Not cut, and why: reply by link, the `/intro` and `/claim` links (product surface for people without
a portal), the box and the ring, tribes and rosters, the queue, the memory file and tiers, the outbox,
`find.blind` between held cards, the `/inbox` app. Each is a thing a person uses, not a path a
reviewer found.

## 6. Order, if approved

1. Doors and identities first (§2): `deliver(env, handle)`, `{ handle, publicKey }` references,
   `addKnownCard` as the one writer. This is the change that makes the other cuts safe to see.
2. Gossip and relay fan-out (§1 #9–#12, #24): the largest removal; crawl/fly rewritten to the
   directory + relay + branch model.
3. Router remnants, `thread.leave`/`lapsed`, push-config writes, wire shape (§4); Rust follows.
4. Tools (§3): merges, then aliases out.
5. One review round on the result, by a fresh session, before the tag.

Each step is one commit and one suite run; nothing is tagged between them.
