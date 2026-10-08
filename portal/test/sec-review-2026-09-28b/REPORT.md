# Security review — Mazel v0.5.8-box (`one need one thread with a branch per candidate, the box, the listed surface`)

Fresh reviewer, no context from the build. Read: `portal/src/index.js` (5393 lines), the existing
suites in `portal/test/`, and `MAZEL-SPEC.md` §3.6, §4.3b, §4.3c, §11.4 locks 11 and 12.

Nothing under `src/` or any existing test file was modified. Every finding below has a standalone
Node ESM script in this directory that fails today. Run each from `portal/test`:

```
node sec-review-2026-09-28b/01-directed-need-text-leaks-via-propose-intro.mjs
node sec-review-2026-09-28b/02-thread-open-replays-to-any-portal.mjs
node sec-review-2026-09-28b/03-branch-id-is-predictable-and-squattable.mjs
node sec-review-2026-09-28b/04-agent-message-passed-off-as-human.mjs
node sec-review-2026-09-28b/05-block-not-portal-wide-without-a-held-key.mjs
node sec-review-2026-09-28b/06-invite-text-spells-out-a-held-need.mjs
node sec-review-2026-09-28b/07-doorbell-cap.mjs
node sec-review-2026-09-28b/08-relay-search-fabricates-a-person.mjs
```

Each exits non-zero and prints one or more `FAIL` lines.

**Count by severity: 5 High, 2 Medium, 1 Low.**

---

## High

### H1 — A directed need's words travel to any candidate the agent proposes to

**Severity:** High
**Location:** `proposeIntro()`, `src/index.js:2889–2900` (`const needTier = needTierOf(...)` /
`const heldBack = needTier === "matched-only"` / the `needText: heldBack ? "" : thread.need_text`
on the `intro.propose` action), and the same expression again at line 2942.

`openBranch()` (4662–4666) enforces the rule the card sets: a `directed` need opens a branch only
with the handle in `need.to`, and a `tribe`/`inner` need opens none at all. `proposeIntro()` reads
the same tier and then throws it away — it holds the need back only when the tier is exactly
`matched-only`, so a **directed** need (and a tribe- or inner-held one) is put on the wire in full,
to whichever candidate the agent names. There is no check that the candidate is the named
recipient. The `why` line quotes the need text too, so it leaks twice over.

**Script:** `01-directed-need-text-leaks-via-propose-intro.mjs`. Alice holds
`directed-cfo → cal@mazel`; the branch guard correctly opens only with Cal; `propose_intro` is then
called for `mallory@mazel` and prints:

```
FAIL a directed need's words must not reach a portal it does not name
  -> intro 9ffaf412....needText = "a replacement CFO for Northwind before the board hears about it"
FAIL directed-need text escaped: proposeIntro sent needText="…" to mallory@mazel, who is not the
     need's named recipient (cal@mazel).
```

**Fix:** make `needTierOf()` the single gate in `proposeIntro`, not a special case for one tier.
Hold `needText`, `needTags` and the `why` back for every tier that is not `public` — i.e. replace
`heldBack = needTier === "matched-only"` with `heldBack = needTier !== "public"` — and refuse the
call outright when the tier is `directed` and `cand.handle` is not the `to` handle (the same
comparison `openBranch` already makes), and when the tier is `tribe` or `inner` and the candidate is
above that tier. The held-back `why` string already exists a few lines above and should be reused
for all of them; the release into the branch after 🌀 (`openThreadFromIntro`, 3879–3882) should be
generalised in the same way, keyed on `conv.needTier !== "public"`.

---

### H2 — `thread.open` is signed but not bound to its recipient, so it replays at any portal

**Severity:** High
**Location:** `onThreadOpen()`, `src/index.js:4139–4146` (the `action.kind === "need"` path), which
hands straight to `onNeedBranch()` at 4696; dispatched from `applyInboundAction()` at 2959.

The need path verifies the signature, the 48-hour `fresh(action.castAt)` window and the sender's
pinned key, and then never looks at `action.participants` — it builds the conversation from `me` and
the sender alone. The router path eleven lines below *does* check
`named.some(p => p.handle === me.handle)` (4167); the need path does not. So a signed branch-open is
a bearer object for two days: the named recipient of a directed need, a proxy, a log, or anyone who
sees one copy can POST it verbatim at any other portal that holds the opener's card, and that portal
will screen it, open a branch, record an outcome and put a 📬 "Someone needs what you have" item in
its owner's box — for a need whose owner never sent it there. Combined with H1's tier handling, a
directed need's words reach portals it explicitly named someone else for.

**Script:** `02-thread-open-replays-to-any-portal.mjs`. Alice's one branch-open to `cal@mazel` is
captured off the wire and replayed byte-for-byte at Carol's door:

```
FAIL a replayed thread.open must not open a branch at an unnamed portal
  -> carol now holds 1 branch(es): [["carol@mazel","alice@mazel"]]
FAIL a replayed thread.open must not put an item in an unnamed portal's box
  -> ["📬 Someone needs what you have: alice@mazel is looking for a replacement CFO for Northwind …"]
FAIL a directed need's words must not reach an unnamed portal
```

**Fix:** bind the open to its recipient inside the signature. `openBranch` already builds
`participants: [{…need…}, {…have…}]`; make `onThreadOpen`'s need path require that
`action.participants` names this portal's own handle in the `have` slot before calling
`onNeedBranch` — the one-line check the router path already performs. Belt and braces, key the
replay store by `(action.publicKey, action.contextId)` so the same open is accepted once per portal
rather than once per 48 hours, and have `onNeedBranch` derive its participants from the recipient
entry it just validated instead of from the sender alone.

---

### H3 — The relay's `/search` answer is unsigned and unchecked, and it fabricates a person

**Severity:** High
**Location:** `searchRelay()`, `src/index.js:3346–3369`, in particular the
`rememberStranger(env, { handle: r.handle, url: r.cardUrl, rpc: r.rpc, publicKey: r.publicKey,
have: r.have || [], … })` at 3356, and the `addCandidates(…, origin)` it feeds at 2805 / 5096.

`onFindHit()` is explicit about this class of problem in its own comment at 4977–4990 — it re-fetches
the card behind a hit and re-scores it, "because a key carried inside the message proves only that
whoever wrote it can generate a keypair". `searchRelay()` does neither: it takes handle, card URL,
rpc, public key, haves and glosses straight out of the relay's JSON, with no signature check and no
card fetch, stores them as a world-tier known card, scores the relay's own claimed tags against the
need, and — new in v0.5.8 — opens a branch, boxes a ✨ item naming that person, and delivers a
`thread.open` carrying the need's words to the rpc the relay chose. This is lock 12 ("every match
… exists as a signed object on a portal, with a real human behind it") and §7.5 ("the cache …
never decides a match a portal could not decide alone") in one call.

**Script:** `08-relay-search-fabricates-a-person.mjs`. A stubbed relay invents `greatcfo@mazel`:

```
FAIL a relay result must be checked against a real card before it is a candidate
  -> offered as rank 1: "You need a fractional cfo for Northwind; greatcfo@mazel has fractional-cfo …"
FAIL no box item may name a person with no signed object behind them
  -> ["✨ Found someone for \"a fractional cfo for Northwind\": greatcfo@mazel. …"]
FAIL nothing may be sent to an address the relay made up -> ["https://evil8.example/a2a (thread.open)"]
FAIL the need's words must not travel to it
```

**Fix:** give `searchRelay` the same discipline `onFindHit` already has. For each result, fetch
`r.cardUrl` and `parseAgentCard` it; drop the result unless the card's HAAH `handle` equals
`r.handle` and its `publicKey` equals both `r.publicKey` and the directory record `resolveHandle()`
returns for that handle; then score the card as fetched, never the relay's claimed `have`/`glosses`,
and take `rpc` from the card rather than from the search response. A result that cannot be
corroborated that way should be silently dropped, exactly as an unverifiable `find.hit` is.

---

### H4 — Branch ids are predictable, and a third party can squat one and silently kill the branch

**Severity:** High
**Location:** `branchId()`, `src/index.js:4646`
(`stableId("branch", mine, rootId, handle)`); the root id it is built on,
`findInKnownCards()` at 2777 (`stableId("thread", [...needTags].sort().join(","))` sliced to 8 hex);
and `onThreadOpen()` at 4139–4146, which accepts whatever `contextId` the sender writes and returns
early — silently — when `loadConv(action.contextId)` already exists.

Keying the branch to the opening portal fixed the collision between two openers, but the id is still
a pure function of public inputs: the opener's Ed25519 public key is published on their agent card,
and `rootId` is derived from the need's **tags** alone, so any plausible tag set gives the id. The
receiving portal never checks that the `contextId` is `branchId(sender's own key, …)`. A stranger
whose card the recipient holds can therefore register the id first; when the real opener's branch
arrives, the recipient drops it without a word and the two portals diverge permanently — the opener
believes the branch is open, the recipient holds a branch with the squatter, and nothing ever
reconciles. The same squat plants a box item whose `needId` is invented.

**Script:** `03-branch-id-is-predictable-and-squattable.mjs`:

```
PASS mallory could compute the id of a branch she is not part of  -> bc8056f8…
PASS alice's own branch really does land on the predicted id
FAIL bob's copy of that branch must be the one alice opened -> other party on bob's copy: ["mallory@mazel"]
FAIL alice's need must reach bob at all
FAIL branch-id squat: mallory@mazel pre-registered contextId bc8056f8… at bob's portal, so bob's
     portal silently dropped alice@mazel's real branch-open for the same id.
```

**Fix:** make the id self-authenticating at the receiver. Keep `branchId(openerPub, rootId, handle)`
as the opener's derivation, and have `onThreadOpen`'s need path recompute
`branchId(action.publicKey, action.origin.needId, myHandle)` and refuse any open whose `contextId`
does not equal it — a squatter then can only ever occupy ids derived from their own key, which is
exactly the namespace they are entitled to. (`action.origin.needId` is already on the wire and
inside the signature.) Salting `rootId` with the portal's key would additionally stop the id being
guessable from tags, but the derivation check is what closes the attack.

---

### H5 — An agent's words are passed off as a person's, and land in the box before 🌀

**Severity:** High
**Location:** `onNeedBranch()`, `src/index.js:4724` (message one is stored verbatim, with whatever
`note.metadata.haah.author` the sender wrote), and `onThreadMessage()`, `src/index.js:4084`
(`const author = h.author === "agent" ? "agent" : "human"`) with the box item it drives at 4105.

§4.3b: in a branch "the agents talk first, labeled as agent messages; on 🌀 the humans join the same
branch". Two local invariants follow, and neither is enforced. (a) Message one of a branch is by
construction the opening **agent's** summary, but the receiving portal stores whatever label arrived
— a branch-open whose note says `author: "human"` is rendered to the owner with no "(agent)" mark,
and `thread_read`'s own note tells the agent "author: human means a person wrote it, verbatim".
(b) In a branch where `humans === false`, no human has said yes yet, but a counterpart portal can
send an `author: "human"` message, which moves the thread to `sent` and puts a 💬 "A reply from X"
item in the owner's box with a doorbell — a human reply before either human consented. This is the
lock-12 question ("can an agent message be passed off as human?") answered yes, twice, with the
portal doing the mislabelling itself.

**Script:** `04-agent-message-passed-off-as-human.mjs`:

```
FAIL message one of a branch must be labelled author: agent -> stored as author: human
FAIL agent-as-human (open): bob's portal shows message one of a branch as author: human, from
     mallory@mazel, with humans=false.
FAIL no human reply lands in the box before both humans said yes
  -> humans=false, state=sent, box=[… "reply: 💬 A reply from bob4@mazel …"]
FAIL agent-as-human (message): a portal put an author: human message into a branch where
     humans=false; … the thread moved to state "sent" with no 🌀.
```

**Fix:** stop trusting the counterpart's label where the local state already determines it. In
`onNeedBranch`, force `note.metadata.haah.author = "agent"` before storing message one (and re-verify
it against the sender's key with `verifyMessage`, which is not done today). In `onThreadMessage`,
when `conv.branch && !conv.humans`, coerce the stored author to `"agent"` and use the
`found_for_you`/branch box kind rather than `reply` — or refuse the message with a readable error, as
the branch protocol says only agents speak there. Once `humans === true`, today's behaviour is
correct. `signedFields` already covers `author`, so the label cannot be forged in transit; the gap is
purely that a portal's claim about its own side is taken as fact where the local state contradicts it.

---

## Medium

### M1 — `thread_block` is not portal-wide when the counterpart's key was never pinned

**Severity:** Medium (regression on the previous review's H1)
**Location:** `callTool`, `name === "thread_block"`, `src/index.js:1582–1590`, specifically
`for (const p of others) { if (!p.publicKey) continue; … }` at 1584.

The two portal-wide markers — `blocked:<publicKey>` (1585) and `blocked:h:<handle>` (1586) — are both
inside the loop body, after a `continue` that skips any participant with no pinned key. So for that
counterpart the block collapses back to `conv.blocked`, i.e. one thread. That counterpart is the
ordinary case for an unverified intro: `applyInboundAction`'s `intro.propose` branch (2966–2972)
builds `from` as `{ handle, cardUrl, rpc }` with no `publicKey` when the portal holds no card for the
proposer, and `openThreadFromIntro` copies it onto the participant unchanged. `thread_manage`
describes block as "one step for someone being harassed"; for exactly the stranger a person is most
likely to want blocked, it blocks nothing but the thread they were harassed in.

**Script:** `05-block-not-portal-wide-without-a-held-key.mjs`:

```
PASS a thread opened with the unverified proposer -> [["victim@mazel",true],["spam@mazel",false]]
FAIL blocking records the portal, not just the thread -> []
FAIL a blocked portal is refused everywhere, not only in that thread
  -> door answered ok; mailbox 2 -> 3
FAIL block is not portal-wide: thread_block wrote 0 blocked: key(s) …
```

**Fix:** move the handle marker out from under the key guard — always write
`blocked:h:<handle.toLowerCase()>` for every non-`me` participant that has a handle, and write
`blocked:<publicKey>` additionally when a key is known. Better still, resolve the key at block time
via `keyFromCard(p.cardUrl, p.handle)` (4121) and, failing that, `resolveHandle()`, so the block also
survives a handle change; and when the key later becomes known (e.g. `onThreadMessage` pins it at
4074–4077), promote the handle block to a key block at the same moment.

---

### M2 — `invite_text` spells out a matched-only or directed need for an outsider

**Severity:** Medium
**Location:** `callTool`, `name === "invite_text"`, `src/index.js:1759–1800`, specifically
`needText = t.need_text` at 1772 with no tier check, feeding `inviteText()` at 4763–4778.

§3.6 is unambiguous: a matched-only need "travels only as a fingerprint … Text appears only after
both humans say yes." `openBranch`/`needParts` honour that for a saved contact — the ghost's branch
carries buckets. `invite_text`, which `find`'s own `invites_note` tells the agent to call next for
exactly those contacts, reads the root thread's `need_text` with no tier check and hands back a
ready-to-send paragraph naming the held-back ask, addressed to a person who has said nothing. The
same call spells out a `directed` need to a contact it does not name.

**Script:** `06-invite-text-spells-out-a-held-need.mjs`:

```
PASS the contact's branch carries buckets, not words
FAIL a matched-only need's words must not be drafted for an outsider
  -> Someone I know is looking for a replacement CFO for Northwind before the board hears about it, …
FAIL a directed need's words must not be drafted for someone it does not name
```

**Fix:** apply `needTierOf(card, thread)` in the `invite_text` handler as `openBranch` does. For a
`matched-only` root, drop `needText` and build the invitation from the matched tags only ("something
I am working on lines up with what you do"), which is the same sentence the branch already sends. For
a `directed` root, refuse the call unless the ghost has been linked to the named handle. `inviteText`
already renders sensibly with an empty `needText` (the tribe branch of that function), so the change
is a tier lookup plus one refusal, not a rewrite.

---

## Low

### L1 — An empty `DOORBELL_DAILY_CAP` silently means zero, not the default

**Severity:** Low
**Location:** `boxItem()`, `src/index.js:4743`
(`const cap = Number(env.DOORBELL_DAILY_CAP ?? DOORBELL_DAILY_CAP_DEFAULT)`).

`??` only catches `null`/`undefined`. A var that is *present but empty* — which is what a blank
wrangler var or a cleared dashboard field looks like — gives `Number("") === 0`, and `0 >= 0` passes
the finiteness guard, so the doorbell is switched off for every agent-found item with no diagnostic.
The waiting counter still accrues, but nothing announces it until an uncapped ring (a reply or a 🌀)
happens to fire.

**Script:** `07-doorbell-cap.mjs` (the other seven assertions in that file confirm the cap behaves as
§4.3c specifies; this is the only failure):

```
FAIL an empty DOORBELL_DAILY_CAP must fall back to the default of 3, not to silence
  -> rings 0, waiting 5, cap counter 0
FAIL DOORBELL_DAILY_CAP="" is read as 0: Number("") is 0 and 0 >= 0, …
```

**Fix:** treat an empty or blank string as unset — e.g.
`const raw = String(env.DOORBELL_DAILY_CAP ?? "").trim(); const cap = raw === "" ? DOORBELL_DAILY_CAP_DEFAULT : Number(raw);`
— and keep the existing `Number.isFinite(cap) && cap >= 0` guard for a garbage value. The same shape
appears in `daysCfg()` (3701), which already handles it correctly via `Number.isFinite`; worth
routing `DOORBELL_DAILY_CAP` through a shared helper so the two cannot drift.

---

## Checked and found sound

**Tier on branches (§3.6)**
- `needAt()` (310) drops `matched-only` and `directed` needs from every card projection, at every
  tier; they never reach `agentCard`, `publicCard`, `castCard` or `subscribeRelay`.
- `needParts()` (4649) sends a fingerprint plus the matched tags for a `matched-only` branch, and
  deliberately omits the why line ("a why line quotes the need"). `box-test.mjs:95` already asserts
  the words are absent.
- `openBranch()` (4662–4666) refuses a `directed` branch to anyone but the named handle, and refuses
  `tribe`/`inner` branches entirely. Tested at `box-test.mjs:110`, and again in script 01.
- `findInKnownCards()` gates the relay cast and `searchRelay` behind `isPublicNeed` (2801–2805);
  `runPulse()` (5065–5083) skips `directed`/`tribe`/`inner` outright and routes `matched-only`
  through `castBlindNeed` (buckets) instead of `castNeed`/`gossipCast`.
- `onNeedBranch`'s screening (4700–4715) scores a `matched-only` need by fingerprint overlap against
  the portal's own public haves and stays silent below `FP_MATCH_MIN`.
- The release after 🌀 (`openThreadFromIntro`, 3879–3882) only fires once the intro is `connected`.
- The doorbell and web push are contentless by construction: `pushAll()` (4533) sends an empty body
  with only a VAPID header, and `/inbox/ding` is session-gated and returns a name plus a context id.
- Outcome records (`recordOutcome`, 3783) hold tags, tier, carrier and a state history and never a
  word of content, and they are local — nothing publishes them.
- `deliverThread`'s error strings carry the *remote* door's response, not local content; the
  give-up mailbox notes (3999–4013) name the counterpart and nothing else.
- The reply-by-link page (`handleReplyLink`, 4571) is MAC-scoped to one thread, expires at 14 days,
  is rate-limited to 30 replies a day, and shows one plain page for forged / unknown / expired.

**The `thread.open` wire message**
- Signature verified against a key pinned *before* the message arrived — a known card above world
  tier, or `keyFromCard()` (4121), which cross-checks the card's handle and the directory's signed
  record. A card planted under someone else's name fails.
- `fresh(action.castAt)` (2959) with `castAt` inside the signature; `parseAction`'s `ACTION_FIELDS`
  allow-list (2366–2379) keeps sender-controlled junk out of the stored record.
- Blocked senders are refused by key and by handle before anything is written (4141).
- An existing conversation is never overwritten by an inbound open; the router path may only supply a
  missing `cardUrl`/`rpc`, never a key (4151–4163).
- `onThreadMessage` requires the sender to be a named participant *and* to have signed with that
  participant's pinned key, dedupes by `messageId`, and enforces `MAX_THREAD_BODY_BYTES`.
- `onThreadAction`'s `thread.lapsed` can only end a thread still in `open` past the configured lapse
  window — a counterpart cannot use it to kill a live conversation.
- Door-level ceilings hold: `MAX_MAILBOX` as a listing (not a counter), plus per-IP and per-sender
  daily caps, applied to the thread path as well as the mailbox path.

**Lock 12 (nothing fabricated)**
- Every box item is written by `boxItem()` (4734) from a conversation object that exists on this
  portal; the four kinds map to a verified inbound action, a verified inbound message, a local scorer
  result, or a connected intro. The one exception is H3, where the "signed object" is the relay's
  word.
- `onFindHit()` (4977) is the model for the rest: replay check first, key from the relay this portal
  chose or from the card behind the hit, the card re-fetched and re-scored at the same bar and rarity
  weighting as a hand-added card, and a hard floor (`strongFit`, `weighted < 2`) before anything
  surfaces.
- `rememberStranger()` (4780) will not let a wire card overwrite one the owner placed, and will not
  change a key under a handle.
- `intro.respond` is refused unless the intro was sent from here, is still `proposed`, and is signed
  by the counterparty's held key (3000–3005) — a guessed intro id cannot manufacture a 🌀.
- `thread_send` requires `confirmed: true` and sends the person's words verbatim; `thread_note` is
  the only agent-authored path and is labelled `author: "agent"` locally.
- `DOORBELL_DAILY_CAP` behaves as §4.3c specifies for a set value: 3 by default, honoured at 1,
  silent at 0, the overflow counted in `bell:waiting:<day>` and named in the next ring, and replies
  and 🌀 never capped (`boxItem` returns `ringBell` before the cap is consulted). Seven assertions in
  script 07 cover this.

**Observations that did not reach a ranked finding** (no script, so not counted): `onThreadMessage`
has no freshness check and dedupes only against the most recent 200 messages, so a captured signed
message could in principle be re-accepted in a very long thread; and there is no per-sender ceiling
on how many branches one portal may open, beyond the generic 100/sender/day door cap, while
conversation records are written with no TTL.
