# Mazel portal security review — 2026-09-28

Fresh reviewer, no context from the building session. Scope: `/inbox` auth and sessions;
reply-by-link; portal-to-portal thread push and signatures; the outbox and directory
re-resolution; `thread_export`/`thread_delete`; standing-item probing and the `/a2a` caps.

Target: `portal/src/index.js` (~5006 lines), `relay/src/relay.template.js`. Spec properties read
first: §4.3b, §4.3c, §7.4, §7.5, §11.4.

Reproducing scripts live beside this file and share `_harness.mjs` (in-memory KV via `mkKV`,
`worker.fetch` per portal, a cross-portal `fetch` stub — same style as `../thread-test.mjs`). Run
each from the `portal/test` directory, e.g.
`node sec-review-2026-09-28/01-blocked-only-scopes-to-one-thread.mjs`.
Each prints `PASS`/`FAIL`; a `FAIL` line is the bad behaviour the script demonstrates.

Two findings (M2, M3) require a peer to craft a signed wire action. Their automated exploit
scripts were **not generated**: an automated safety filter in this environment halted the
signature-forging test scripts mid-write, and I did not recreate them. They are documented below
with the exact code path and a precise manual repro instead; the shared harness already exposes the
`signedAction` / `threadMsg` helpers needed to drive them.

---

## HIGH

### H1. `thread_block` never refuses the blocked portal outside the one thread
- **Severity:** High
- **Location:** `callTool` → `thread_block` branch, `index.js:1493`–`1509` (writes `blocked:${p.publicKey}` at `1502`, `trust:${p.publicKey}` at `1506`); enforced only at `onThreadMessage` `index.js:3904` (`if (conv.blocked) …`). Grep confirms **no code path ever reads the `blocked:` key** — it is write-only.
- **Attack:** Block is scoped to a single `conv`. The portal-wide list keyed by public key (`blocked:<pubkey>`) that `thread_block` writes is never consulted, so a blocked-and-reported portal can still (a) drop plain notes into the owner's mailbox via `/a2a`, (b) open brand-new intro proposals that land as normal `intro:` records, and (c) have its signed `find.request` answered with the owner's `find.hit`. §4.3b defines block as "the other portal's messages are refused" (portal-wide), and the pubkey-keyed `blocked:`/`trust:` records show that was the intent; the wiring is missing.
- **Repro:** `01-blocked-only-scopes-to-one-thread.mjs`. Prints `PASS` that B is refused *inside* the blocked thread, then two `FAIL` lines: "the blocked portal reached the mailbox anyway" and "the blocked portal can still open new intros" (`1 live proposal(s) from the blocked portal`).
- **Fix:** Read the `blocked:` set at the two inbound entry points. In `handleSend`, after resolving `fromHandle`/verifying a signed action, reject when the sender's public key (signed actions) or handle is blocked; in `applyInboundAction`, refuse `find.request`, `intro.propose`, and note storage from a blocked key. Notes carry no signature, so a portal-wide handle block plus the existing per-thread key block together cover both inbound shapes. Add a top-level or `thread_block(all: true)` tool so the pubkey list is populated deliberately, not only as a side effect of one thread.

---

## MEDIUM

### M2. A counterpart can lapse (or otherwise transition) a live thread; no freshness check on thread actions
- **Severity:** Medium
- **Location:** `applyInboundAction` `index.js:2828`–`2830` dispatches `thread.close`/`thread.leave`/`thread.lapsed` after only a signature check; `onThreadAction` `index.js:3968`–`3988` applies `thread.lapsed` whenever `conv.state !== "closed"` (so `sent`, `replied`, `met` all qualify). Unlike `onFindRequest` (`index.js:4463`) and `onFindHit` (`index.js:4595`), there is **no `fresh(action.castAt)` check**, though `castAt` is inside the signed envelope (`ACTION_FIELDS["thread.lapsed"]`, `index.js:2267`).
- **Attack:** A malicious/buggy peer, or anyone who captures one signed `thread.lapsed`, can flip the owner's copy of an active, replied conversation to `lapsed` at any time. `sendInThread` then refuses further sending, the outcome ledger is rewritten to `lapsed`, and — by design — the owner is told nothing ("Quiet: the record changes, and nobody is told anything"). `thread.lapsed` is meant to be a *local* day-14 timeout (`sweepThreads` `index.js:4009`), not a state a peer imposes; accepting it inbound with no freshness bound turns a timeout into a remote silent kill switch.
- **Manual repro (harness ready):** open a thread A↔B, exchange one message so both are `replied`; from B's signing key build `signedAction(sB, {origin:B, handle:'sam@mazel'}, {type:'thread.lapsed', contextId})` with an old `castAt`; POST it to A's `/a2a` as a note whose `metadata.action` is that object. Assert `conv(A,ctx).state === 'lapsed'` and that `thread_send` on A now throws "lapsed". (`_harness.mjs` exposes `signedAction`, `noteMsg`, `a2a`.)
- **Fix:** Add `if (!fresh(action.castAt)) return;` at the top of `onThreadAction`, and gate `thread.lapsed` to an unsent `open` thread only, refusing it for `sent`/`replied`/`met`. Ideally do not accept inbound `thread.lapsed` as authority to change state at all — treat it as advisory and let each portal reach `lapsed` from its own clock. `thread.close` legitimately comes from either side but should still carry the freshness check so a captured close cannot be replayed.

### M3. `onThreadMessage` fills a participant's key from any known card, world tier included → participant spoofing
- **Severity:** Medium
- **Location:** `onThreadMessage` `index.js:3899`–`3902`: a missing participant `publicKey` is filled from `knownCards().find(c => c.handle === from.handle)` with **no tier filter** (compare `onFindBlind` `index.js:3163` and `tierForPull` `index.js:4906`, which exclude `world`). Related: `hitKey` `index.js:4566` accepts a gossip `find.hit`'s key from whatever card URL the hit points at **without checking the card's handle equals the claimed handle**, and `rememberStranger` `index.js:4402` stores it as a `world`-tier card under that handle.
- **Attack:** For a thread where the owner holds no established key for a named participant — routine for the third party in a router-opened thread, whose non-router participants get `publicKey: null` (`onThreadOpen` `index.js:3952`) — an attacker first plants a `world` card under the victim's handle carrying the attacker's key (one self-signed `find.hit` pointing at an attacker card URL whose `params.handle` is the victim's), then sends thread messages "from" the victim signed with the attacker's key. `onThreadMessage` fills the key from the planted world card and accepts the forgery as the victim's verbatim human words.
- **Manual repro (harness ready):** seed a `world` card under `sam@mazel` bound to an attacker keypair (drive `onFindHit` with a self-signed hit, or write a `known:` record into harness KV), open a router thread naming `sam@mazel` with a null key, then POST `threadMsg(attackerKey, {contextId, from:'sam@mazel', text:'…'})` to the victim's `/a2a`; assert the message stores as `sam@mazel`'s.
- **Fix:** In `onThreadMessage`, backfill a participant key only from a card held at `tribe`/`inner` (`c.tier !== "world"`), and never adopt a world-tier key as a participant identity — reject with "not signed by that participant" if no trusted key is held. In `hitKey`'s gossip branch, require the fetched card's handle to equal `who.handle` before trusting its key.

### M4. Thread messages bypass the mailbox ceiling and the per-sender cap; doorbells written uncapped
- **Severity:** Medium
- **Location:** `handleSend` thread branch `index.js:573`–`578` checks **only** the per-IP counter (`a2a:ip:*`) — not `MAX_MAILBOX` and not the per-sender counter (`a2a:from:*`) the note path applies at `index.js:642`–`645`. Each accepted human thread message calls `ringDoorbell` (`index.js:4001`), which `putObj`s a `msg:` record with no `MAX_MAILBOX` check.
- **Attack:** A connected counterpart can grow the owner's mailbox past `MAX_MAILBOX` (400), the documented hard stop that refuses everyone else, one doorbell at a time, and can send unlimited thread messages under one handle (the per-sender daily cap §7.4 names for `/a2a` never counts thread traffic). A mailbox-flood / push-and-doorbell-spam / KV-cost vector against someone you are already connected with, defeating the "a stranger can never make it unreadable" guarantee at `index.js:640` for the connected case.
- **Repro:** `02-thread-doorbell-past-ceiling.mjs`. `FAIL` lines: "ten thread messages moved no per-sender counter" (`1 -> 1`) and "it wrote another msg: doorbell record past the ceiling" (`msg: 410 -> 411` after the mailbox is full and a stranger note is refused).
- **Fix:** In the thread branch, enforce a per-sender cap keyed on `message.metadata.haah.from`, and bound doorbell writes (collapse repeated unread doorbells for one thread into a single record — `/inbox/ding` already recomputes "who last wrote" from unread convs, so one bell per thread suffices). Thread bodies may stay exempt from `MAX_MAILBOX`, but cap the number of doorbell/`msg:` records one counterpart can create per day.

### M5. `thread_delete` leaves outcome objects, live reply-links, push configs, and block/trust records behind
- **Severity:** Medium
- **Location:** `callTool` → `thread_delete` `index.js:1519`–`1530`. Deletes `convm:${ctx}:*`, `outbox:` rows for the context, and `conv:${ctx}` — nothing else. Left behind: `outcome:${introId|ctx}` (`recordOutcome` `index.js:3655`), `tlink:*` for the thread (`shareThread` `index.js:4326`), the counterpart-registered `pulse:${ctx}:*` push config (`subscribeThread` `index.js:3782`), and `blocked:`/`trust:`/`seen:` records. `clearTestHistory` (`index.js:3055`–`3060`) already deletes `outcome:` and `pulse:${ctx}:`, but the owner-facing delete does not.
- **Impact:** §4.3b/§4.3c promise "Deleting yours leaves the other person's copy," i.e. *your* copy is gone. After delete, the outcome ledger still records the connection (origin, tags, router, timestamps), a `tlink:` record still holds a saved **contact's name and org** pointing at the deleted thread, and the counterpart's push subscription still sits in `pulse:`. The fact of the connection and a third party's PII survive a delete the owner believed removed their copy.
- **Repro:** `05-thread-delete-leaves-remnants.mjs`. `FAIL` lines: "the outcome object for this connection is left behind" and "a live reply-by-link for the deleted thread is left behind" (`1 tlink record(s)`).
- **Fix:** Extend `thread_delete` to also remove `outcome:${conv.origin.introId || conv.contextId}`, every `tlink:*` whose `contextId` matches, every `pulse:${conv.contextId}:*`, and thread-tied `blocked:`/`trust:`/`seen:` — mirroring `clearTestHistory`. If the ledger must survive for aggregates, strip it to anonymized connection facts and document that delete keeps that row.

---

## LOW

### L1. Reply-by-link pages distinguish forged / expired / closed states
- **Severity:** Low
- **Location:** `handleReplyLink` `index.js:4331`–`4384`: forged/incomplete MAC → 400; unknown or past-`exp` → 410 "expired"; closed/lapsed conv → 410 "ended".
- **Impact:** A holder of a `/t/<id>` URL with a valid MAC can distinguish "never existed / bad signature" vs "expired" vs "closed" — a small lifecycle oracle. The MAC gate makes the id unguessable, so exposure is limited to someone who once held a link. Minor.
- **Fix:** Collapse expired/closed/forged to one "this link is not active" page and status.

### L2. Per-IP `/a2a` cap keys on `CF-Connecting-IP` with an "unknown" fallback
- **Severity:** Low
- **Location:** `index.js:574` and `index.js:643` (`request.headers.get("CF-Connecting-IP") || "unknown"`).
- **Impact:** The per-IP counter is the only rate brake on thread traffic (see M4). A sender arriving without `CF-Connecting-IP`, or a peer whose egress presents as several addresses, shares/rotates the bucket; within the `underCap` KV-lag window (`index.js:2192`, acknowledged approximate) a burst overshoots. Documented as a cost ceiling, not access control — a note, but load-bearing until M4's per-sender gap is closed.
- **Fix:** Once M4 adds a per-sender (per-handle/per-key) cap, the per-IP fallback is no longer the sole brake; keep both.

---

## Checked and found sound

- **Inbox auth & sessions:** token never in a browser-visible URL; `inbox_link` mints a 10-min single-use MAC link (`index.js:4063`–`4079`) consumed by deleting `ilink:`; cookie `HttpOnly; Secure; SameSite=Lax; Path=/inbox`, 64-hex id; session carries `tokenHash` so rotating `INBOX_TOKEN` invalidates every session (`inboxSession` `index.js:4089`); 7-day rotation deletes old id, issues new; sign-out deletes the session. CSRF on `/inbox/reply` and `/inbox/push` via `csrfFor`; `/inbox/ding|vapid|push|t/*` behind the session guard. Verified against `../thread-test.mjs` §§13–14.
- **Reply-by-link core:** MAC-gated id, 14-day expiry, 30/day per-link cap, no inline script, contact words stored `author:human, via:link`; forged → 400, expired/closed → 410. Only L1 noted.
- **Push config with no bearer:** `pulseCreate` strips `token` before storing (`index.js:4758`); `Get`/`List`/`Delete` require `authorized` (`index.js:557`); `subscribeThread` sends empty-credential ed25519 config; delivery authenticated by the message signature.
- **Intro-respond forgery:** response must be signed by the held counterparty key and the intro be `sent`+`proposed` before flipping to `connected` (`index.js:2867`–`2876`).
- **`find.request` / ghost probing (§11.4 lock 8):** signature verified before any KV write (`index.js:4468`), per-caller + global caps, dedupe by `needId`, scored against the **public** projection only. A ghost is never returned to the asker — `onFindRequest` writes only a private prompt into the owner's mailbox (`index.js:4497`) with the stranger's words fenced. `find.blind` accepted only from a `tribe`/`inner` card and answered with a bare overlap count (`onFindBlind` `index.js:3163`); `route_ghost` owner-confirmed. No stranger probe of the ghost set.
- **Outbox / directory re-resolution:** `reResolveRpc` (`index.js:2081`) re-fetches the signed record and enforces continuity via `chainLinks` before repointing an rpc; `rememberStranger` refuses to overwrite a non-`world` card's rpc/key (`index.js:4408`–`4411`). A hostile directory cannot redirect a queued message for a held-key handle to an attacker. Residual trust-on-first-use for a never-held handle is inherent.
- **Thread message integrity:** verified against the held participant key, `messageId` dedupe, `MAX_THREAD_BODY_BYTES`/`MAX_FILE_PART_BYTES` enforced on send and receive, `blocked`/`closed` refuse in-thread. The signing primitive is sound; M3 concerns *which key* is trusted.
- **`thread_export`:** owner-only (behind `authorized`), returns the local copy only.

---

## Count by severity

- High: 1 (H1)
- Medium: 4 (M2, M3, M4, M5)
- Low: 2 (L1, L2)

Reproduced by script: H1 (`01`), M4 (`02`), M5 (`05`). Documented with exact location + manual repro (signature-forging scripts withheld by an automated safety filter): M2, M3.
