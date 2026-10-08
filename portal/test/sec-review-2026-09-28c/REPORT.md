# Security review — Mazel v0.5.8-box, third pass (`sec-review-2026-09-28c`)

Fresh reviewers, no context from the build. Read: `portal/src/index.js` at `a3bb021` (5432 lines), the
suites in `portal/test/`, the 28b report, and `MAZEL-SPEC.md` §3.6, §4.3b, §4.3c, §11.4 lock 12. Nothing
under `src/` or in any existing test was changed.

Two reviewer sessions ran on this tag at the same time and wrote into this folder independently; the
scripts are kept as they were written, and this report is the union, one entry per defect, citing every
script that reproduces it. Every script is a standalone Node ESM file that fails today. Run from
`portal/test`:

```
for f in sec-review-2026-09-28c/0*.mjs; do node "$f"; done
```

Each prints `FAIL` lines and exits non-zero; the two overlapping passes agree on every shared defect.

**Count by severity: 4 High, 5 Medium, 3 Low** (12 defects, 17 scripts).

---

## Part 1. The eight 28b fixes

The security suite (`sec-thread-test.mjs`, 47 checks) and `box-test.mjs` (43) are green. The original 28b
scripts now either pass or stop at the fix's own refusal (01 and 06 throw the new error; 03 asserts a
predictable id that no longer exists; 04(a) is dropped by the H2 binding before it reaches H5; 08's one
"send" is the card GET the commit says is by design). Each fix, and what still goes around it:

| 28b | Fix | Holds? | Goes around it |
|---|---|---|---|
| H1 directed-need refusal | `proposeIntro` refuses a directed need to anyone but `need.to` (2899) | Yes, by handle string | **M1**: tribe/inner-held needs are not held at all. **H1**: the handle string can be an impostor's. |
| H2 thread.open bound | need path requires `participants` to name this portal and the sender (4166–4168) | Yes | **L1**: the only replay guard at the named portal is "conv exists"; delete and it comes back. **M5**: the note inside the open is not bound to the signer. |
| H3 relay results verified | card at `r.cardUrl` fetched, handle compared (3369–3375) | Half | **H1**: handle is compared to the card's own claim, never to the directory; same for gossip in `hitKey`. |
| H4 random branch ids | `branchId()` is 128 random bits (4675) | Yes, for branches | **H3**: the thread id on 🌀, `stableId("ctx", intro.id)` (3870), is still a pure function of public inputs. |
| H5 author forced to agent | message one and every message in a `humans=false` branch (4761, 4106) | Yes | **L2**: done by rewriting a signed field, so the stored copy no longer verifies. **M5**: `from` and `at` on message one are still the sender's to write. |
| M1 block portal-wide | `blocked:h:<handle>` written with or without a key (1584) | Yes, when the sender names itself | **M2**: the door reads the block from `metadata.handle` only; omit it and the block is not consulted. **M3**: a reply link is not a "portal" and ignores the block. |
| M2 invite_text | refuses matched-only and mis-directed (1772–1780) | Yes | **M1**: tribe/inner spelled out to a contact in no tribe. |
| L1 doorbell cap | blank var reads as the default (4781–4782) | Yes | — |

---

## High

### H1 — A stranger becomes any handle this portal does not already hold, through the relay and through gossip

**Scripts:** `02-stranger-under-a-real-handle-relay-and-gossip.mjs`, `01-relay-impostor-card-under-a-real-handle.mjs`,
`02-gossip-impostor-takes-a-directed-need.mjs`
**Location:** `searchRelay()` 3369–3376; `hitKey()` 5001–5013 and `onFindHit()` 5034; the
`intro.respond` check at 3007 (`knownCards.find(handle === intro.handle)`, any tier, no directory).

The 28b H3 fix compares the fetched card's handle to the handle the relay claimed. That is the card agreeing
with itself. `keyFromCard()` (4144) — the path used for `thread.open` and thread messages — additionally
requires the directory's signed record for that handle to name the same key. Neither `searchRelay` nor the
gossip path of `hitKey` does that. So a card on any host that says "I am sarah@mazel" *is* sarah@mazel to a
portal that holds no card for her yet: `rememberStranger` stores it at world tier under her handle with the
impostor's key and rpc. From there, in order: a ✨ "Found someone: sarah@mazel" in the box; a branch; the
need's words to the impostor's door; the owner's `propose_intro` to the impostor; the impostor's signed
`intro.respond` verifying against "sarah's" held key; "🌀 You and sarah@mazel both said yes"; the owner's first
message, in their own words, to the impostor. The real sarah, whose record the directory holds under another
key, never hears a word. The relay binds handle to key only for names it holds, so an unregistered name or any
`name@otherdomain` is claimable there; gossip has no relay in the loop at all. Script `02-gossip-impostor…`
does it against a **directed** need: the `need.to` comparison in `openBranch` is on the handle string, so the
strictest tier's words go to a stranger who claimed the named handle.

```
FAIL relay: a card that only says it is sarah must not become sarah  -> candidate rank 1 at https://evil2c.example/card; known card key is the impostor's: true
FAIL relay: the impostor's signed yes must not read as sarah's  -> intro connected; box: 🌀 Both said yes: you and sarah@mazel are in the thread.
FAIL gossip: a signed hit from a stranger whose card claims sarah's handle must not become sarah
FAIL a directed need's words must not reach a door that is not the named person's  -> 1 message(s) carrying the need reached https://evil.c2/a2a
```

**Fix:** one rule for every stranger: the key this portal pins for a handle is `keyFromCard(cardUrl, handle)`
— card handle equals claimed handle *and* `resolveHandle()`'s signed record names the card's key — or nothing.
Apply it in `searchRelay` (drop the result when it returns null), in `hitKey`'s gossip branch (return that key,
not the card's), and in `rememberStranger` (refuse to store a key the directory does not vouch for). The
`intro.respond` check at 3007 should then pin from the same place rather than from any world-tier card.
Cost: one directory GET per new stranger, cached.

### H2 — `intro.propose` is unsigned on the wire and unverified on arrival; an anonymous POST plus the owner's yes is a 🌀

**Scripts:** `01-unsigned-intro-propose-fabricates-a-yes.mjs` (also visible in `07-block-misses-a-sender-who-omits-the-handle.mjs`)
**Location:** `proposeIntro()` 2921–2930 (a bare object handed to `deliverResilient`, never `signPayload`);
`applyInboundAction()` 2974–2993 (`verified: !!held` at 2986, no `verifyPayload`); `respondIntro()` →
`openThreadFromIntro(…, "responder")`.

`tribe_invite` signs its proposal; `propose_intro` does not, and the receiving portal checks nothing on any of
them. It looks the claimed proposer up among the cards it holds and, finding one, copies that card's handle, rpc
and key onto the intro and marks it `verified: true`. So a POST with no signature, no key and no
`metadata.handle` that names any handle the portal holds is a proposal "from" that person, indistinguishable
from a real one: `list_intros` and `check_mailbox` show no signal either way. The owner's yes then runs
`openThreadFromIntro`: a thread with that person, an outcome record, and "🌀 Both said yes: you and
alice@mazel" — lock 12's fake intro, and a fake yes, from one anonymous request.

```
FAIL an unsigned proposal must not become a verified intro from a card this portal holds  -> stored as from alice@mazel, verified: true, door said ok
FAIL no 🌀 may be boxed for a yes nobody but bob gave  -> ["🌀 Both said yes: you and alice@mazel are in the thread."]
FAIL bob must not be told that alice said yes  -> 🌀 You and alice@mazel both said yes. A thread is open between you
```

**Fix:** build the proposal with `signedCast()` like every other action; on arrival, when a card is held for
the proposer verify against its key, otherwise against `keyFromCard(proposer.cardUrl, proposer.handle)`, and
refuse an unverifiable proposal outright (`ACTION_FIELDS["intro.propose"]` already carries the envelope). Drop
the `verified` flag or make it mean "signature checked". `sec-thread-test.mjs:25` already signs its
proposals, so the suite will not notice the change.

### H3 — The thread id at 🌀 is computable, so a third party's branch can swallow the owner's yes

**Script:** `06-tribe-need-leaks-and-its-yes-is-hijackable.mjs` (part b)
**Location:** `openThreadFromIntro()` 3870 (`stableId("ctx", intro.id)`) and 3873–3890 (the
`already.branch && !already.humans` join, which never checks that the intro's counterpart is a participant);
`intro.id` is `stableId("intro", proposerOrigin, threadId, cardUrl)` (2897), and `threadId` is
`stableId("thread", sortedTags).slice(0, 8)` (2787).

28b H4 made branch ids random; the id both sides derive when an intro carries no `contextId` — any intro whose
need opened no branch: tribe/inner-held, a candidate that failed screening, a collision — is still a hash of
public inputs. A third party whose card the responder holds opens a need-branch at that exact id first (a
signed `thread.open`, legitimate in every other respect). The responder's yes to the real proposer then
"joins the branch the agents opened": the squatter's. The box says "🌀 Both said yes: you and mallory@mazel",
the outcome ledger records a connection with the wrong person, and the real proposer's first message is
refused at the door as "not a participant".

```
FAIL bob's yes to alice must open a thread with alice  -> participants: ["bob@mazel","mallory@mazel"], humans=true
FAIL no 🌀 may name someone who never said yes  -> ["🌀 Both said yes: you and mallory@mazel are in the thread."]
FAIL alice's first message must reach bob  -> queued (door returned JSON-RPC error -32003: not a participant in that thread)
```

**Fix:** in the `already` path, join only when the existing branch's non-`me` participant is the intro's
counterpart (`intro.handle` / `intro.from.handle`); otherwise fall through and open a new thread. And stop
deriving: have the proposer mint a random `contextId` for every intro (it already sends one when a branch
exists) and refuse to open on the responder side without one.

### H4 — A matched-only need's fingerprint goes to any stranger who guesses its tag

**Script:** `05-matched-only-fingerprint-goes-to-a-stranger.mjs`
**Location:** `onFindHit()` 5049 → `addCandidates(…, origin)` → `openBranch()` → `needParts()` 4685–4691;
the thread id at 2787.

§3.6 measured this exact risk ("four buckets identify a need's word set to about one in ten to the twelfth")
and decided blind casts go only to cards held at tribe or inner; `runPulse` and `findInKnownCards` honour that.
`onFindHit` does not: a stranger who can name the thread id — `stableId("thread", sortedTags).slice(0, 8)`,
computed here from the tag `fractional-cfo` alone — sends a gossip `find.hit` under their own real card, and
the portal opens a branch to them, boxes them as ✨ found, and sends a `thread.open` carrying the need's
fingerprint and matched tags. No blind cast ever went to them; they were never held; they guessed a tag.

```
FAIL a matched-only need's fingerprint must not go to a stranger nobody blind-cast to  -> 1 thread.open(s) with fp reached https://stranger.c5/a2a
FAIL a held need does not get a ✨ for a stranger who guessed its tag
```

**Fix:** in `onFindHit`, when `needTierOf(card, thread).tier !== "public"`, accept the hit only from a card
already held above world tier (the set `castBlindNeed` sends to) and otherwise drop it silently; and salt the
thread id with the portal's key so it is not guessable from tags (the 28b report suggested the same for
`rootId`).

---

## Medium

### M1 — Tribe- and inner-held needs are held nowhere but `openBranch`

**Scripts:** `03-tribe-held-need-words-travel-to-a-stranger.mjs`, `06-tribe-need-leaks-and-its-yes-is-hijackable.mjs` (part a)
**Location:** `proposeIntro()` 2903 (`heldBack = needTier === "matched-only"`, unchanged by 28b); `invite_text` 1772–1780.

The memory file accepts `[tribe]` and `[inner]` on a need (`FIELD_TIERS`, `cardFromMemory` 237), `needAt` keeps
them off lower projections, and `openBranch` refuses them a branch. `proposeIntro` knows two held tiers: it
holds words back for matched-only and refuses mis-directed, and for tribe/inner sends `needText`, the tags and a
why that quotes the need — to whichever candidate `find` produced, which scores every known card, world tier
included. `invite_text` spells the same need out to a saved contact in no tribe. The 28b fix text said to key
the hold on `needTier !== "public"`; the commit kept `=== "matched-only"`.

```
FAIL a tribe-held need's words must not travel to a world-tier stranger  -> intro.propose to https://wally3c.test: a CFO for Northwind before the board meets on the 14th
FAIL a tribe-held need must not be spelled out for a contact outside the tribe
```

**Fix:** `heldBack = needTier !== "public"`; refuse `propose_intro` for a tribe/inner need to a candidate below
that tier; in `invite_text` refuse tribe/inner unless the contact has a `member_of` edge into a tribe at or above
it.

### M2 — The block is read from a field the sender can leave out

**Scripts:** `04-block-bypassed-by-omitting-the-metadata-handle.mjs`, `07-block-misses-a-sender-who-omits-the-handle.mjs`
**Location:** `handleSend()` 605 (`fromHandle = metadata.handle || message.role`) and 639.

The 28b M1 fix writes `blocked:h:<handle>` for an unpinned stranger. The door then consults it by
`metadata.handle` only. With that field omitted, `fromHandle` is `"ROLE_USER"`, no held card matches, and the
handle block is never read; every typed action carries its own `handle` (and `intro.propose` its `proposer`) and
neither is checked. The harasser M1 was for drops one optional field and their proposals and needs land again —
as `verified: true`, because the held card supplies `from` (H2).

```
FAIL a blocked handle's proposal is refused even with metadata.handle left out  -> door: ok; intro stored: true
FAIL and so is its need  -> door: ok
```

**Fix:** at the door, check `blockedHandle` against every handle the message names — `metadata.handle`,
`action.handle`, `action.proposer.handle`, `action.from.handle` — and `blockedKey` against `action.publicKey`
(already done) before `applyInboundAction`.

### M3 — A reply link keeps working after `thread_block`

**Script:** `05-reply-link-outlives-a-block.mjs`
**Location:** `handleReplyLink()` 4615 (checks `closed` and `lapsed`, never `conv.blocked`); `thread_block`
1576–1592 records nothing for a participant with no handle and no key.

For a saved contact the only way in is the link. After the owner blocks the thread, each POST is still stored as
the contact's words, moves the thread to sent/replied, puts "💬 A reply from <name>" in the box and rings the
doorbell, which for a reply is never capped. The one control the owner was given against a person who will not
stop does nothing for the one kind of person who can only reach them this way.

```
FAIL after the block, the link must refuse  -> HTTP 302, 302
FAIL nothing lands in the box and the bell does not ring  -> bell: true
```

**Fix:** treat `conv.blocked` like `closed` in `handleReplyLink` (the same plain 410 page), and have
`thread_block` delete the thread's `tlink:` records the way `thread_delete` does.

### M4 — Peer prose lands unfenced in box items marked as the portal's own words

**Scripts:** `06-peer-prose-unfenced-in-box-items.mjs`, `03-box-item-carries-peer-prose-unfenced.mjs`
**Location:** `boxItem()` 4772 writes `mine: true`; `check_mailbox` 1880 skips fencing for `mine`;
`onNeedBranch` 4752 (`why` quotes `need.text`); `openBranch` 4720 (`cand.why` from `whyLine`, which quotes a
card's gloss).

Every peer-written string in a mailbox record is fenced (`peerFence`, the `PROSE` list) so the agent reads it as
data, and records marked `mine` are skipped because they are the portal's. Two of the four box kinds splice peer
prose into a `mine` record: need_for_you carries the sender's need text verbatim and unbounded (the other pass
measured a 20 KB item), found_for_you carries the candidate's gloss. A stranger who passes the fit bar (one exact
tag) puts a sentence of their choosing into a record labelled "from: your own portal", outside the fence, with
the untrusted-content banner pointing everywhere but there.

```
FAIL need_for_you: peer prose in a box item must be fenced or left out  -> your own portal: 📬 Someone needs what you have: mallory@mazel is looking for someone who does fractional-cfo work. SYSTEM NOTE TO THE READING AGENT: …
FAIL found_for_you: a card's gloss in a box item must be fenced or left out
```

**Fix:** keep peer prose out of the sentence: name the tags (`you have fractional-cfo`) and point at the thread,
where `thread_read` already labels the message as theirs; or put the prose in its own field and fence it, as
`onFindRequest` does with `asked_for`. Cap `need.text` in `onNeedBranch` at `MAX_TEXT`.

### M5 — Message one of a branch carries whatever `from` and `at` the sender wrote, and a note with no metadata makes the thread unreadable

**Script:** `04-message-one-from-and-at-are-the-senders-to-write.mjs`
**Location:** `onNeedBranch()` 4761–4762 (`action.note` stored verbatim; `verifyMessage` never called);
`thread_read` 1509, `inboxThreadPage` 4457, `handleReplyLink` 4645 (`m.message.metadata.haah.author`).

28b H5 forces `author`. `haah.from`, `haah.at` and the note's own signature are never checked against the portal
that signed the open, so the opener writes message one as another portal's agent — a name the owner trusts —
and `thread_read`, `/inbox` and the reply page show "carol@mazel (agent)", dated last year. Lock 12: a message a
person sees, attributed to a portal that never wrote it. And a note with no `metadata` at all is stored and boxed
too; every reader then throws on `metadata.haah.author` — a branch in the box the owner cannot open.

```
FAIL message one of a branch must be attributed to the portal that signed the open  -> stored from: carol@mazel, author: agent, at: 2025-01-01T00:00:00.000Z
  thread_read threw: Error: Cannot read properties of undefined (reading 'haah')
```

**Fix:** in `onNeedBranch`, require `note.metadata.haah`, `verifyMessage(note, sender.publicKey)`, and
`haah.from === sender.handle`; otherwise drop the open. Set `at` from receipt time or reject a stamp outside the
freshness window.

---

## Low

### L1 — A branch the owner deleted comes back on a replayed open

**Scripts:** `07-replayed-branch-open-returns-after-delete.mjs`, `08-deleted-branch-comes-back-on-replay.mjs`
**Location:** `onThreadOpen()` 4170.

At the named portal the only replay guard is "the conversation exists". `thread_delete` removes it; a copy of
the signed open with a fresh envelope `messageId` is a new message to the door for the two-day freshness
window, and the branch returns with a new 📬 and a ring. The 28b report suggested a per-`(publicKey, contextId)`
replay store; it was not added.

**Fix:** `seen-open:<publicKey>:<contextId>` with the freshness TTL, written before `onNeedBranch`.

### L2 — Author coercion rewrites a signed field, so the stored message no longer verifies

**Script:** `08-coerced-author-breaks-the-stored-signature.mjs`
**Location:** `onThreadMessage()` 4107.

`author` is inside `signedFields`. Overwriting it on the message that is then stored leaves a signature over
bytes the object no longer contains: `verifyMessage` fails on this portal's own copy, `thread_export` hands out a
message that looks tampered with, and nothing records what the sender claimed.

**Fix:** store the message as signed and keep the shown label beside it (`shownAs: "agent"`, or on the seq
record), so the signed bytes stay intact and the claim is on file.

### L3 — A signed message replays once it is past the 200-message dedupe window

**Script:** `09-signed-message-replays-past-the-window.mjs`
**Location:** `onThreadMessage()` 4102–4103.

Noted without a script in 28b. No freshness check, and dedupe only against the newest 200 messages: a captured
human message is accepted again after 200 newer ones, stored as a new reply, boxed 💬, the bell rung — the
person's words re-said at a time they did not say them.

**Fix:** `seen:<messageId>` for thread messages (the mailbox path already keeps one), plus `fresh(h.at)`.

---

## Part 2. Tier on branches (§3.6) — where a held need's words could leave, checked

Sound, with the exceptions above (H1 impersonating the named recipient of a directed need; H4 the fingerprint
to a stranger; M1 tribe/inner):

- **Card projections:** `needAt` (310) drops matched-only and directed at every tier; tribe/inner sit above
  lower tiers. Nothing held reaches `agentCard`, `castCard` or `subscribeRelay`.
- **Casts:** `findInKnownCards` gates the relay on `isPublicNeed` (any held tag); `runPulse` (5105) skips
  directed/tribe/inner and routes matched-only through `castBlindNeed` (buckets, tribe/inner cards only unless
  `BLIND_TO_RELAY`). `searchRelay` sends `need_text` as a query only on those paths.
- **thread.open:** `needParts` sends a fingerprint plus matched tags for matched-only and deliberately no why;
  `openBranch` refuses directed-to-others and tribe/inner; a contact branch gets buckets. `box-test.mjs:95` and
  28b 01/06 assert the words are absent.
- **Proposals and the branch note:** for matched-only, `why`, `needText`, `needTags` and the `introNote` data
  are all held back (2903–2905, 2955); the release (3899–3902) fires only inside `already.humans = true`, i.e.
  after `connected`.
- **Box, doorbell, push:** box items name the owner's own need text only on the owner's portal; `ringBell` and
  `/inbox/ding` carry a name and a context id; `pushAll` sends an empty body.
- **Outcomes, logs, errors:** `recordOutcome` holds tags, tier, carrier and states, never text, and nothing
  publishes it. There is no `console.*` in the Worker. `deliverThread` reasons carry the remote door's text,
  not local content; the give-up notes name the counterpart only.
- **Reply-by-link page:** MAC-scoped to one thread, 14 days, 30 replies a day; message one of a matched-only
  contact branch renders as the tags sentence, data parts as `[data]`.
- **invite_text:** matched-only and mis-directed refused (28b M2 holds).

**Observations, no script:** the tier is keyed on tags matching `card.need`, so `find(need_text)` with different
or no tags casts a held need's words as public — the agent's discipline, not the portal's. `thread_note` can
paste the words into a held branch before 🌀; the portal could refuse a note in a `needTier !== "public"`,
`humans === false` branch that contains the root's `need_text`. `reveal_need` sends a matched-only need's words
to a blind-hit portal on the owner's yes alone (pre-v0.5.8, explicit in its tool text; the branch model has
superseded it and it could retire).

## Part 3. Lock 12 — nothing fabricated reaches a person, checked

Sound, with the exceptions above (H1 an impostor's candidate and yes; H2 an unsigned proposal and its yes; H3 the
wrong person's 🌀; M5 a mis-attributed message one):

- **📬 need_for_you** exists only after a `thread.open` verified against a key pinned before arrival (a held
  card above world tier, or `keyFromCard` with the directory), bound to this portal and its sender, screened at
  the local fit bar. **✨ found_for_you** is the local scorer's result on a card fetched and re-scored, capped
  and rarity-weighted. **💬 reply** requires a named participant's signature (or the link's MAC for a contact).
  **🌀 both_yes** on the proposer's side requires a signed `intro.respond` from the counterparty's held key, and
  the intro to have been sent from here and still `proposed`.
- The router path of `thread.open` accepts only a held non-world card's signature, pins third parties through
  the directory, and never overwrites a key.
- `thread_send` requires `confirmed: true` and sends verbatim; `thread_note` is the only agent-authored path and
  is labelled so. `rememberStranger` never overwrites a card the owner placed or changes a key under a handle.
- The doorbell cap behaves as §4.3c says (28b script 07, 8 checks).

**Observation:** neither `list_intros` nor `check_mailbox` surfaces the intro's `verified` flag, so even where
the portal knows a proposer is unverified the agent is not told; worth showing once H2 makes the flag mean
something.

---

*Second-pass scripts (`01-relay-impostor…`, `02-gossip-impostor…`, `03-box-item…`, `04-message-one…`,
`05-matched-only-fingerprint…`, `06-tribe-need-leaks…`, `07-block-misses…`, `08-deleted-branch…`,
`09-signed-message-replays…`) were written by the parallel reviewer session and are cited above as they stand.*

---

## Part 4. The eight 28b fixes under variation (second pass, `10-28b-fixes-under-variation.mjs`)

Not a finding: the record of what the second reviewer pushed against each 28b fix from an angle the
regression at the end of `sec-thread-test.mjs` does not take. Fourteen checks, all PASS today; the run
loop above (`0*.mjs`) skips it by name, run it as `node sec-review-2026-09-28c/10-28b-fixes-under-variation.mjs`.
Anything here that later prints FAIL is a regression on a 28b fix.

- **H1:** a directed need with a mixed-case `need_to` (`Cal@Mazel`) still opens only with that person;
  proposing it to someone else *as a router* (`router_for`) is refused before anything leaves; the directed
  need never reached the relay as text.
- **H2:** a replay at the named recipient after `thread_close` does not reopen it; adding a third portal to
  `participants` breaks the signature and opens nothing there; a portal holding the opener at **inner** tier
  still refuses an open that does not name it.
- **Receiving door vs. H1 above:** a `thread.open` signed by an impostor card under `alice@mazel` is refused at
  the receiving door, because `keyFromCard` asks the directory. This is the exact check the originating side
  (`searchRelay`, `hitKey`) lacks; the asymmetry is H1.
- **H4:** two portals opening the same need to the same person land on different branch ids.
- **H5:** a `human`-labelled message from the *need* side into an agents-only branch is stored as the agent's
  (the regression tests the have side); after 🌀 a person's message stays `human`.
- **M1:** a *signed* `thread.open` from a blocked portal opens nothing (the M2 bypass above is unsigned traffic
  with the handle omitted).
- **M2:** `invite_text` itself, not only the `contacts` wrapper, refuses a held need and drafts no word of it.
- **L1:** a whitespace-only `DOORBELL_DAILY_CAP` means the default.
- **H3:** a relay result pointing at a *real* card under the *wrong* handle is dropped (the impostor case, same
  handle, is H1 above).

**Further observations from the second pass, no script, not counted:** `needTierOf()` (4671) takes the first
held need whose tag is on the thread, so a thread tagged with both a matched-only tag and a directed tag takes
whichever the card lists first — the strictest should win. `onNeedBranch` stores `sender.rpc` from the signed
action rather than from the held card, so a counterpart can route the owner's replies to a door of its choosing
(its own conversation, so low). `searchRelay` and `onFindHit` fetch whatever `cardUrl` the relay or the hit
names, `http:` included, once per message. The `/inbox` list page truncates box text to 140 characters, which
is why M4 is an agent-side problem and not a phone-screen one.

*Merged in by the second reviewer session after the first had written the report; nothing above this line was
changed.*
