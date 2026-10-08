# Security review — Mazel v0.5.8-box, sixth pass (`sec-review-2026-09-29f`)

Fresh reviewer (Fable), no context from the build. Commit `4441269`, untagged. Read: `portal/src/index.js`
(5541 lines), `relay/src/index.js`, the suites in `portal/test/`, all five earlier reports and their scripts,
and `MAZEL-SPEC.md` (from git HEAD; the working-tree copy is deleted) §3.6, §4.2, §4.3, §4.3b, §4.3c, §6.2,
§6.4, §6.5, §7.5, §11.4. Nothing under `src/`, `relay/`, or in any existing test was changed (`git status`:
only this folder is new). Every finding below has a standalone Node ESM script in this folder that fails
today. Run from `portal/test`:

```
for f in sec-review-2026-09-29f/0*.mjs; do node "$f"; done
```

**Count by severity: 3 High, 3 Medium, 3 Low** (nine defects, nine scripts).

The rule under review: everything about a handle (key, door, card content, presence in a thread) comes only
from something that handle's owner signed or from the directory's record; nothing about a person is taken
from another party's message. The gate (`pinIdentity` / `verifyInbound` / `cardIdentity`) enforces it for
keys and doors on every signed path I traced. The three Highs are the three places a message about a person
still gets past it with nothing that person signed: a router's `thread.open` (H1), a typed action the gate
refused but the mailbox kept (H2), and a thread id on a proposal that points at a branch the proposal is not
about (H3).

---

## 1. The five earlier passes: every script passes, or fails on a precondition that no longer exists

`test/run.sh` is green: 16 suites `N passed, 0 failed`, `live-peer` skipped (no `PEER_URL`), fixtures match
the Worker. All 38 earlier scripts were re-run from `portal/test`. As in 28d and 29e, an exploit script
"passes" when its exploit assertion no longer reproduces; the remaining `FAIL` lines and throws are one of
four kinds, none a live defect:

| Script | What prints `FAIL` / throws | Why it is not a defect |
|---|---|---|
| 28/01 | `A blocked B in this thread and filed a report` | The script asserts exactly one `blocked:` key; 28b M1 now writes two (by key and by handle). Both refusal assertions pass. |
| 28/05 | `the outcome object for this connection is left behind` | Decided at the 28 M5 fix: `thread_delete` keeps the intro's ledger row and says so in its own reply; the reply-link assertion passes. |
| 28b/01, 28b/06, 28c/06-tribe | throw `that need is directed at …` / `holding back` / `held at tribe` | The fix's own refusal, thrown before the exploit step. |
| 28b/05, 28c/04-block-bypassed | throw `no intro bbbb…` / `no intro dddd…` | Precondition gone: an unsigned proposal no longer becomes an intro (28c H2), so there is nothing to block or bypass. |
| 28b/03, 28c/02-gossip, 28c/05 | "could compute the id", "pure function of the tag" | Ids are random (28b H4, 28c H3/H4); the property assertions pass. |
| 28b/04, 28c/03-box-item, 28c/04-message-one | "no branch", "the need reached bob's box", throw `no conversation` | Precondition gone: a forged open opens nothing (28c M5), so there is no branch, box item or thread to inspect. |
| 28c/08 | `it is shown as an agent's -> human` | Reads the signed `haah.author`; the L2 fix keeps that field intact and records the coerced label in the record's `author`, which `thread_read` returns (28d note). "Must still verify" passes. |
| 28d/01 | `FAIL note: sarah did not become a candidate` | A note line, `1 passed 0 failed`: the planted key is refused. |
| 28c/01-relay-impostor | `must not become a candidate -> card https://victim.c1/…, rpc https://victim.c1/a2a`; `no box item may name a real handle` | **New since 29e, and not a defect.** The relay points at an impostor card; 29e H2 makes the portal resolve the *real* victim through the directory and read the card at the record's address, which has `fractional-cfo`, so the real victim - real key (that assertion passes), real door - becomes a candidate and a ✨ names them. The script's "(impostor)" label on its PASS line is its own text. Nothing from the impostor's card was used. |

29e's seven scripts pass 5/5, 5/5, 3/3, 4/4, 4/4, 4/4, 4/4. The six 29e fixes hold: `cardIdentity` reads the
record's card (4204-4212), rosters and pulls store content from it (2523-2528), `router_for` is refused
(2966) and a wire `router` object dropped (3051-3054), the 🌀 line names the counterpart only (3955), a blind
hit's door is the directory's (5070-5075), the router `thread.open` takes doors from the directory
(4290-4296), `reResolveRpc` never writes a key (2218-2232), a keyless card never replaces a keyed one (2534).

---

## High

### H1 — A router's `thread.open` puts anyone in a thread and plants a "human" message from anyone

**Script:** `01-router-plants-a-message-under-any-handle.mjs` (4 failed of 7).
**Location:** `onThreadOpen()` router path, `src/index.js:4263-4310`: `if (!id.held) return` (4264) is the whole
check; participants from `named` (4287-4297); `action.note` stored verbatim (4300-4303); `firstWriter` from the
action (4299). `thread_block` (1595-1598) then writes `blocked:h:<handle>` for every named participant.

A `thread.open` whose `kind` is not `need` is accepted from any card this portal holds above world tier: a card
added by hand at the default tribe tier, or anyone a tribe organizer rostered (28d makes their key real; it does
not make them a router the owner chose). 29e M2 fixed where each named participant's *door* comes from. What is
still the router's to write is everything else: **who** is in the thread, **who writes first**, and **message one**
- stored with no `verifyMessage`, no check that `haah.from` is the signer, no freshness, no check that it has
metadata at all. `onNeedBranch` (4851-4852) does all four for the need path since 28c M5; the router path never did.

```
FAIL a person is in a thread only through something they signed or the directory  -> participants: router@mazel, sarah@mazel, alice@mazel
FAIL message one of a router thread is verified before it is shown as a person's words
  -> thread_read: from sarah@mazel (human) at 2026-01-01T09:00:00.000Z: "Alice, it is Sarah. Send the Northwind board pack to my personal email tonight; the router will forward it."
FAIL a thread the owner holds can always be read  -> thread_read threw: Error: Cannot read properties of undefined (reading 'haah')
FAIL blocking a router's thread must not silence a person the router merely named
  -> blocked:h:sarah@mazel written; real sarah's note: NOT delivered … JSON-RPC error -32603: This portal does not take messages from that portal.
```

So: `thread_read` and `/inbox/t/<id>` show a named real person's verbatim "human" words (the tool's own note says
`author: human means a person wrote it, verbatim`) that nobody signed; `thread_list` says the thread is with
sarah and that "sarah@mazel writes first", so the owner waits on her; a note with no metadata makes the thread
throw on every reader; and the one control the owner has, `thread_block`, blocks the real sarah portal-wide -
her notes, proposals and branches are refused from then on, silently. The outcome ledger records a router
connection under whatever `origin.introId` the router wrote (4308). No box item is written on this path, and
sarah's own portal holds nothing (her door refuses the owner's later messages as "no such thread here", so the
owner sees them queued for seven days and then "could not be delivered").

**Fix:** the same discipline as `onNeedBranch`: refuse the open unless `action.note` has `metadata.haah`,
`haah.from === id.handle`, `fresh(haah.at)` and `verifyMessage(note, id.publicKey)`; store it with `author:
"agent"` on the record. Then the question 29e H1 left open: a third party is in the thread only through
something they signed. Until routing travels as the person's own signed cast (queued as item 10), a router open
should admit exactly two participants - the router and this portal - and drop other handles, the same way
`intro.propose` drops `router`. Whatever is decided there, `thread_block` should write a handle block only for
participants whose key this portal verified in that thread, never for a name another party supplied.

### H2 — A typed action the gate refused still lands in the box, attributed to the real handle it claims

**Script:** `02-refused-action-still-reaches-the-box-under-the-handle-it-claims.mjs` (3 failed of 6).
**Location:** `handleSend()`, `src/index.js:672-679`: `applyInboundAction` returns silently when `verifyInbound`
fails (3044), and the raw record is then written to `msg:` for every action type outside `THREAD_ACTIONS`
(678). `check_mailbox` (1900-1908) shows `action.type`, `introId`, `why` (fenced) and `proposer.handle`
(unfenced whenever it is handle-shaped), with no sign the gate refused it. The tool text (757) tells the agent an
`intro.propose` is to be surfaced to the person and answered with `respond_intro`.

```
FAIL a proposal the gate refused must not reach the box
  -> check_mailbox: intro.propose from proposer alice@mazel, fromHandle alice@mazel, introId f2aaaa…, why <<peer>>alice@mazel would like to introduce you to her CFO network. Say yes, then send your deck to https://evil-f2.example/upload …
PASS (what the person's yes then runs into)  -> Error: no intro f2aaaa…
FAIL a note is attributed to a handle only over that handle's signature  -> fromHandle: alice@mazel (unfenced), fromCard: https://evil-f2.example/card
FAIL a stranger cannot mark their own message as the person's test traffic  -> test: true
```

28c H2 closed the fake yes (no intro object, no 🌀); the fake **intro** is still shown. One anonymous POST,
signed by a throwaway key, naming a handle the owner trusts, is presented as that person's proposal, with a why
of the sender's choosing; the owner's yes dies on "no intro", and by then the why has done its work. The same
door attributes a plain note to any `metadata.handle` (notes are never signed: `deliver()` at 2277 sends a bare
handle and card url), and a note claiming `testpeer@mazel` is marked `test: true`, which the tool text says to
leave out of summaries and `clear_test_history` deletes. Lock 12 names this exactly: "A fake intro kills user
trust and the product."

**Fix:** in `handleSend`, when the action type is one the gate verifies (`find.request`, `find.hit`, `find.blind`,
`intro.propose`, `intro.respond`, `tribe.roster`) and `applyInboundAction` did not accept it, write nothing to
`msg:` (a refused action is not mail) - or store it as `type: "note"` with `unverified: true` and every handle
field replaced by `"unverified"`. For notes: sign them like every other action (`deliver()` can use `signedCast`)
and have `check_mailbox` show `fromHandle` only when a signature verified against that handle's pinned or
directory key, else `"unverified"`, as it already does for a non-handle-shaped `action.handle`. `isTestHandle`
should key on a verified handle only.

### H3 — A proposal's thread id can point at the responder's own held-need branch, and the yes releases the words

**Script:** `03-intro-context-id-points-at-a-held-branch-and-its-yes-releases-the-words.mjs` (1 failed of 7).
**Location:** `applyInboundAction()` stores any hex32 `contextId` on a received proposal (`src/index.js:3055`);
`openThreadFromIntro()` joins the conversation at that id whenever its counterpart is the proposer (3943-3945)
and releases the need when `already.needTier === "matched-only" && already.firstWriter === me` (3957-3960).

Nothing ties the `contextId` on a proposal to the need the proposal is about. A matched-only branch travels, by
design, to every candidate with its buckets and matched tags and its own id (`openBranch`, 4815-4817). The
candidate then proposes an intro about something else entirely - a public need, any why - and writes the
branch's id as the proposal's thread. The owner says yes to the something else; the join sees a matched-only
branch the owner's own portal opened, with the owner as first writer, and says the need out loud:

```
FAIL a held-back need's words leave only on a yes to that need
  -> 1 message(s) to alice carrying the Northwind need; bob said yes to: "You need a hockey coach in Tokyo; alice@mazel has hockey."
PASS (what bob is shown for it)  -> 🌀 You and alice@mazel both said yes. A thread is open … | box: 🌀 Both said yes: you and alice@mazel are in the thread.
```

§3.6: "Text appears only after both humans say yes, and only what each chose to share." The owner said yes to a
hockey coach; the words that travelled were the CFO search before the board hears. Nothing the owner or their
agent is shown before the yes mentions the branch (the `contextId` is a hex string in the mailbox record). The
same join also reopens a branch the owner had closed (state reset to `open`, 3948). High because the one who
does it is any ordinary candidate of a held need, and what leaves is the one thing matched-only exists to hold.

**Fix:** a proposal may name a branch only when that branch is the proposal's own: on the responder's side,
join `already` only when `already.origin.needId` is null (a fresh id) or the branch's `origin.theirNeedId`
matches the proposal's need - i.e. the proposer opened it. Never join a branch whose `firstWriter` is this portal
on a *received* proposal; a received proposal's counterpart cannot be the one this portal's own branch is for
unless the intro carries that need's id, and the release at 3957 should additionally require
`intro.needTags` to match the root's tags. Simplest: on a received proposal, accept `contextId` only if
`loadConv(contextId)` is a branch with `firstWriter === proposer`; otherwise mint a fresh id.

---

## Medium

### M1 — An intro's `path` names third parties as vouchers on the proposer's word

**Script:** `04-intro-path-names-a-voucher-who-signed-nothing.mjs` (4 failed of 6).
**Location:** `applyInboundAction()` stores `action.path` as sent (`src/index.js:3056`); `list_intros` returns it
raw (3284); `handleIntroLink` renders `Path: a → b` on the page with the yes button (5480); `check_mailbox` keeps
handle-shaped entries unfenced (1904); `respondIntro` signs it onward with the answerer appended (3157).

```
FAIL a hop on an intro's path is someone who signed something  -> path on file: sarah@mazel → mallory@mazel
FAIL the page with the yes button names as a voucher only someone who signed  -> Path</dt><dd>sarah@mazel &rarr; mallory@mazel
```

§4.3 says a router's name travels with the intro as the record of *their* yes to route, and "the recorded
granted-set with the router named is the attribution receipt". On the wire `path` is a list of handles the
proposer typed. 29e H1 dropped the `router` object for exactly this reason; `path` is the same claim in a
different field, shown on the one page a person reads before pressing yes, and forwarded under this portal's
signature when they do. The gossip `find.request` path is unsigned in the same way (`onFindRequest`, 5031), and
a hit's why says "reached through a → b" from it, but that string is fenced and never reaches a yes page.

**Fix:** keep only the proposer's own handle in a received `path` (`[from.handle]`), or render every other entry
as unverified until hops are signed; sign the outgoing path the way `intro.respond` signs its own envelope, one
hop at a time, when routing arrives as a signed cast.

### M2 — The outbox re-sends a stale envelope the receiver drops, and the sender boxes a one-sided 🌀

**Script:** `05-outbox-resends-a-stale-envelope-and-boxes-a-one-sided-yes.mjs` (3 failed of 5).
**Location:** `sweepOutbox()` action branch, `src/index.js:4043-4064`: the queued `o.action` is re-sent as
signed, for `OUTBOX_MAX_MS` (7 days); the door's ack counts as delivery and `onQueuedIntroDelivered()`
(3120-3136) flips the intro to connected, opens the thread and writes "🌀 … finally got through: you both said
yes, and the thread is open". The receiver's gate refuses anything older than `CAST_FRESH_MS` (2 days) with a
normal ack (`verifyInbound` 4230 → `applyInboundAction` returns → `handleSend` acks).

```
FAIL a yes is connected on both portals or on neither  -> alice: proposed; bob: connected
FAIL no 🌀 is shown for a thread the other portal never opened  -> 🌀 Your answer to alice@mazel finally got through: you both said yes, and the thread is open.
PASS (threads with humans in them, per side)  -> bob: 1, alice: 0
```

No attacker: two honest portals and one weekend of unreachability. From day three to day seven a queued yes (or
proposal) "delivers" to a door that silently drops it; the responder shows a 🌀 and holds a thread with humans in
it that exists on one portal only, and the proposer's intro stays `proposed` for ever (their mailbox gets the
fenced note text, but `list_intros` disagrees). A 🌀 with no shared object behind it is lock 12's definition of
fabricated, even when nobody meant it. The same applies to a queued `intro.propose`.

**Fix:** re-sign the queued action at each attempt (`signedCast` with a fresh `castAt`; the outbox holds the
action's fields, so rebuilding is a one-liner), or have the door answer a refused-as-stale action with a JSON-RPC
error rather than an ack so the sender's `looksMoved`/"JSON-RPC error" branch gives up and tells the owner.

### M3 — `find` sends a matched-only need's fingerprint to world-tier cards

**Script:** `06-find-sends-a-held-needs-fingerprint-to-a-world-tier-card.mjs` (1 failed of 5).
**Location:** `findInKnownCards()`, `src/index.js:2854-2859`, scores every held card and calls `openBranch` for
each fit; `openBranch()` (4791-4795) refuses directed-to-others, tribe and inner, and never looks at the
candidate's tier; `needParts` (4778-4783) then sends buckets and matched tags.

```
FAIL a matched-only need's fingerprint goes only to cards held at tribe or inner (§3.6)
  -> 1 thread.open(s) carrying buckets reached https://world-f6.example/a2a; tier matched-only, buckets ["022","2dd","8e0","9e8","aee","d46"], tags ["fractional-cfo"]
PASS the pulse's blind cast keeps to tribe and inner  -> 0 message(s) at the stranger's door on the pulse
```

§3.6 decided that blind casts go to cards held at tribe and inner only, because four buckets confirm a guessed
need to one in ten to the twelfth; `castBlindNeed` (3355) honours it on every pulse. Running `find` on the held
need - which is how an agent is meant to search it - sends the same buckets to every world-tier card that fits:
strangers who drifted in from the relay or a gossip hop, held at world precisely because the owner never chose
them. 28c H4 closed the stranger-who-guessed-a-tag path into `onFindHit`; this is the portal's own `find`.

**Fix:** in `openBranch`, when `tier === "matched-only"` and the candidate is not held at tribe or inner (and is
not a saved contact), record the candidate and return null without sending - the same set `castBlindNeed`
uses. The candidate can still be shown in `find`'s answer as "a stranger fits; say yes to ask them" without a
bucket leaving.

---

## Low

### L1 — `resolve_handle` pins the card's key, not the record's

**Script:** `07-resolve-handle-pins-the-cards-key-not-the-records.mjs` (2 failed of 2).
**Location:** `resolveHandleTool()`, `src/index.js:2456-2461` → `addKnownCard({ url: rec.cardUrl })` by hand
(2492-2576): `parsed.publicKey` from the fetched card is stored; `rec.publicKey` is verified (2190) and never
compared to it (the by-hand path compares only against a key already held, 2529).

```
FAIL resolve_handle pins the key the record names, or nothing  -> pinned ec_uYvW3Yr… at tribe; the record says dFIAJWPd3M…; door https://evil-f7.example/a2a
FAIL a proposal signed by a key the directory does not name for sarah is refused  -> stored as from sarah@mazel, verified: true; the answer would go to https://evil-f7.example/a2a
```

The tool text promises "verifies the record is signed by the key it names, then stores the card behind it". When
the host the record points at serves a different key (a stale cache, a re-registered `workers.dev` name, a
taken-over host), that key is pinned by hand at tribe tier, so `pinIdentity` stops asking the directory for that
handle and a proposal signed by it verifies as the person. `cardIdentity` (4210), the gate's own path, refuses
this exact card. Low because it needs the record's own host to disagree with the record; the same shape as 28d
L1 and 29e L1.

**Fix:** `resolveHandleTool` should go through `cardIdentity(env, null, handle)` and store `id.publicKey`,
`id.rpc`, `id.cardUrl`; `addKnownCard` by hand for a *new* handle could also compare against the directory when
a record exists and warn when they differ.

### L2 — A relay blind hit is taken for a need this portal never blind-cast to the relay

**Script:** `08-relay-blind-hit-for-a-need-never-blind-cast-to-the-relay.mjs` (1 failed of 3).
**Location:** `onBlindHit()`, `src/index.js:5060-5081`: no check of `blindToRelay(env)` or `thread.blindRelayAt`.

```
FAIL a relay blind hit counts only for a need this portal blind-cast to that relay
  -> sarah@mazel's portal lines up on 4 signals with something you are holding back: "a replacement CFO for Northwind before the board hears about it". Nothing has been said to them …
PASS (on the owner's yes the words go to the person the relay named)  -> 1 message(s) with the need at sarah's real door
```

29e M1 made the door the directory's; what remains is that the relay chooses the *person*, and the number of
signals, for a need it was never given (`BLIND_TO_RELAY` is off by default). An honest relay never sends one of
these; a lying, misconfigured or compromised one can prompt the owner to say a held need out loud to any real
handle. Low: it needs the owner's chosen relay to misbehave, and the owner sees the name and the words before
saying yes.

**Fix:** in `onBlindHit`, when `action.via === "relay"`, require `blindToRelay(env)` and `thread.blindRelayAt`;
otherwise drop it silently. Gossip blind hits already require a held card (`hitKey`, 5103).

### L3 — A roster widens who receives a member's blind casts and who can pull their tribe-tier card

**Script:** `09-roster-widens-who-gets-blind-casts-and-tribe-tier-pulls.mjs` (2 failed of 4).
**Location:** `onTribeRoster()`, `src/index.js:3588-3603`, raises every listed handle to tribe tier;
`castBlindNeed` (3355) and `tierForPull` (5439-5442) key on that tier.

```
FAIL a member's held-need buckets go only to cards the member chose to hold that close  -> 1 blind cast(s) at x's door on the pulse
FAIL a tribe-only have is served only to someone the member put at tribe  -> x pulled: have ["northwind-turnaround"], held at tribe
```

29e recorded the organizer's power to raise a real third party to tribe tier as designed, with key and door from
the directory, which holds. Scripted here because two things hang off that tier which §3.6 and §5.1 justify as
"the circle that already knows the person": the member's matched-only fingerprints go to whoever the organizer
lists on the next pulse, and that person can pull the member's tribe-only haves and persona with a signature of
their own. The member said yes once, to the organizer, to join; the organizer decides the rest. Low because it
is the spec's own tribe model and the organizer is someone the member accepted.

**Fix (if wanted):** distinguish `tierFromTribe` (already recorded at 3556) from a tier the owner chose: send
blind casts and serve tiered pulls to `tierByHand`/mutual cards only, or to roster-tier cards only after the
person's own portal confirms the membership (a signed join, as the invitation flow already produces).

---

## 2. Every path in the brief, checked

| Path | Handle → key | Handle → door | Content / presence | Verdict |
|---|---|---|---|---|
| MCP `add_known_card` (by hand) | card the owner pasted; a changed key needs a chain (2529-2538); keyless never replaces keyed (2534) | card | card | holds (owner's own TOFU) |
| MCP `resolve_handle` | **card at the record's url, not the record** | card | card | **L1** |
| MCP `cards`/`contacts`/`tribe` merged tools, `link_ghost`, `check_mutual`, `tribe_*`, `note_ghost`, `forget_ghost`, `invite_text`, `route_ghost` | held card only | held card | owner's own | hold; `check_mutual` raises to tribe only on the owner's confirmed yes |
| MCP `find` → `openBranch` | held card / directory | held / record | **fingerprint to world tier** | **M3** |
| MCP `propose_intro`, `respond_intro`, `respond_intro_link`, `/intro` link | held or directory (`verifyInbound` on the answer, 3071) | `id.rpc` | `path` shown as vouchers | **M1**; `router_for` refused (2966) holds |
| MCP `thread_send`/`thread_note`/`thread_read`/`thread_list`/`thread_manage`/`thread_share`/`thread_export`/`inbox_link` | participant's pinned key or directory | participant's door (record) | messages verified on receipt | hold; `thread_block` handle-blocks router-named people (**H1**) |
| MCP `send_to_peer`, `fetch_peer_card` | none (raw address, owner-given, fenced) | as given | fenced | by design |
| MCP `rotate_key`, `my_identity`, `pulse`, `carriers`, `my_memory`, `update_card`, `claim_link`, `clear_*`, `list_queue`, `clear_queue`, `reveal_need` | own key | own | own | hold; `reveal_need` goes to the gate's door (29e M1) |
| `/a2a` `note` | **none: `metadata.handle` shown as the sender** | — | fenced text | **H2** |
| `/a2a` `intro.propose`, `intro.respond`, `find.request`, `find.blind`, `find.hit` (gossip), `tribe.roster`, `thread.close/leave/lapsed` | `verifyInbound` → `pinIdentity` (held or directory), fresh, key on the action equals it | `id.rpc` | refused actions **still written to `msg:`** (**H2**); `contextId` unbound (**H3**); `path` (**M1**) | gate holds for keys and doors |
| `/a2a` `find.hit` via relay (need cast) | relay key, then `pinIdentity(from)` | record | card at the record's url (29e H2) | holds |
| `/a2a` `find.hit` via relay, blind | relay key, then `pinIdentity(from)` | record | **taken for a need never cast to the relay** | **L2** |
| `/a2a` `thread.open`, need kind | `verifyInbound`; open must name this portal and the signer; note verified against the signer, fresh (4851-4852) | `id.rpc \|\| action.rpc` (sender's own) | screened at the local bar | holds |
| `/a2a` `thread.open`, router kind | router held; others via held card / directory | record (29e M2) | **participants and message one on the router's word** | **H1** |
| `/a2a` `thread.message` | participant's pinned key, else `pinIdentity` (4238-4246); `from` must be a participant | — | author coerced in agents-only branches | holds |
| `/a2a` push-config methods | register open; read/list/delete owner-only | — | nothing ever delivered to a registered url | holds |
| Relay `/publish`, `/cast`, `/subscribe`, `/search` | record signed by its key, served by its own host, rotation chain, `name@mazel` casts only by the holding key, card-cast host must match the record (29e) | — | search results are pointers; the portal resolves | holds; `name@otherdomain` casts are anonymous by design and resolve at that domain |
| Gossip `find.request` forwarding | origin's signature intact; `path` appended unsigned | `originRpc` (origin's own) | hit's why quotes the path, fenced | holds (the path is data, and fenced) |
| Rosters | organizer's key, tribe held, member of it; members through `addKnownCard(by_hand:false)` | record | record's card | holds for identity; **L3** for what the tier then does |
| Rotation | old key signs, new countersigns; chain walked here and on the relay; the relay also demands the host serve the record | — | — | holds |
| Outbox | `reResolveRpc` → `cardIdentity`, record's door, no key written | record | **stale envelope acked, marked delivered** | **M2** |
| Reply by link | MAC over the link id, 14 days, 30/day, dies with block and delete; stored as the named contact's words | — | — | holds |
| `/inbox` | session cookie, CSRF, contentless ding and push | — | pages read `haah.from` as stored (**H1** shows a forged one) | holds otherwise |
| Blocks | by key and by every handle the message names | — | — | hold; **H1** shows the handle list is the router's to write |

Observations, no script, not counted: `onNeedBranch` does not check that `note.contextId` equals
`action.contextId` (a signed note for one branch can be stored as message one of another by the same sender;
their own thread, so nothing crosses). `list_intros` returns `why`, `note` and `path` without the `<<peer>>`
fence its own description says they carry. `check_mailbox` leaves `action.from` (a `find.hit`'s object) whole,
so a sender can put prose in `from.handle` unfenced. `onThreadMessage` has no `fresh(h.at)`; `seen:t:` (3 days)
plus the 200-message window covers all but a very long thread (28c L3 residue). The relay's subscriber
notifications (`notifySubscribers`) arrive at a portal that holds no thread with that `needId` and are dropped;
since v0.5.8 "someone needs what you have" travels as the caster's own `thread.open`, so the relay fan-out is
dead weight, not a hole. A relay result under a real `name@mazel` that points at an impostor card now makes the
portal look the real person up, read their real card and, if it fits, box a ✨ for them (28c/01 above); that is
a real person with a real match, decided by the portal's own scorer on the card the record names, so it is
lock-12 clean, but a lying relay can still choose *which* real people a portal looks at.

## 3. Lock 12, checked

Every 📬 and every 💬 traces to a signed object: a need branch's message one is verified against the sender's
pinned key (4851-4852); a reply is verified against a participant's key or came through a link the owner minted.
✨ is the local scorer on a card the record names. 🌀 on the proposer's side needs a verified `intro.respond`; on
the responder's side, the owner's own yes to a verified proposal. **Three things reach the box or a 🌀 that no
real person stands behind:**

- **H1:** a named real person's verbatim "human" words, and their presence in a thread, on a router's word;
  visible in `thread_read`, `thread_list` and `/inbox`, and a `thread_block` then silences the real person.
- **H2:** an intro proposal under a real handle that the gate refused, shown in `check_mailbox` as that person's
  with a why of the sender's choosing; and any note attributed to any handle.
- **M2:** a 🌀 and a thread with humans in it on one portal only, for a yes the other portal silently dropped.

**H3** does not fabricate; it releases the one thing a person chose not to say, on a yes they gave to something
else. **M1** fabricates a voucher, not a party. **M3**, **L2** and **L3** leak a fingerprint or a tier to someone the
owner did not choose; **L1** is the tool contract, owner-initiated.

Closing H1 (verify message one, admit only the signer and this portal), H2 (a refused action is not mail; sign
notes), H3 (a proposal may name only a branch its proposer opened) and M2 (re-sign on retry, or refuse stale
with an error) leaves no fabricated path this pass could find.

---

*Scripts in this folder each print `FAIL` and exit non-zero today; they pass once the fixes above land.*
