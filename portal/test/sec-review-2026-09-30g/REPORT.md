# Security review — Mazel v0.5.8-box, seventh pass (`sec-review-2026-09-30g`)

Fresh reviewer (Fable), no context from the build or the reduction. Commit `14c9ea1`, untagged. Read:
`portal/src/index.js` (5198 lines, all of it), `portal/test/a2a-helpers.mjs` (the `legacy()` wrapper),
`portal/test/RETIRED.md`, the 28/28b/28c/28d/29e/29f reports, and `MAZEL-SPEC.md` §3.6, §4.2, §4.3, §4.3b,
§4.3c, §6.4, §7.2–7.5, §11.4. Nothing under `src/`, `relay/` or in any existing test was changed; `git status`
shows only this folder. Every finding below has a standalone Node ESM script here that fails today. Run from
`portal/test`:

```
for f in sec-review-2026-09-30g/0*.mjs; do node "$f"; done
```

**Count by severity: 1 High, 3 Medium, 2 Low** (six defects, six scripts, plus `00-surface-check.mjs`, which
passes today and is the evidence for section 2).

The rule under review: everything about a handle (key, door, content, presence in a thread or the box) comes
only from that handle's owner's signature or the directory record. **It holds on every path I traced**: no
finding below lets one party write a fact about another. What the six findings share is the step before and
the step after the gate. Before it: two ceilings and one pin are keyed on what a message *claims*, not on what
the gate verified (M1, M3). After it: a verified sender is trusted for things the signature does not vouch for
- that a reveal follows a hit this portal sent (H1), that a card which wrote in once is one the owner chose
(M3), that a stored envelope field is data rather than prose (L1) - and a verified rotation is refused by the
one writer that should follow it (M2).

---

## 1. The six earlier passes: every script passes, or fails only on a precondition that no longer exists

`test/run.sh` is green: 16 suites `N passed, 0 failed` (sec 68, sec-thread 113, m15 17, crawl 54,
a2a-conformance 21, identity 16, relay 24, fly 6, install 86, seed 35, ghosts 54, tribe 46, thread 101, moved
32, box 43, cli 17), `live-peer` skipped (no `PEER_URL`), fixtures match the Worker. The eight retired scripts
are gone as `RETIRED.md` says; the 39 that remain were all re-run. As in 28d, 29e and 29f, an exploit script
"passes" when its exploit assertion no longer reproduces; every remaining `FAIL` line or throw is one of the
kinds below, none a live defect. Two are new since 29f and both are the reduction's own doing.

| Script | What prints `FAIL` / throws | Why it is not a defect |
|---|---|---|
| 28/01 | `A blocked B in this thread and filed a report` | Asserts one `blocked:` key; 28b M1 writes two (by key and by handle). The refusal assertions pass. |
| 28/05 | **new:** `before delete: outcome, tlink and the counterpart pulse-config all exist`; and `the outcome object … is left behind` | The precondition reads `pulse:<ctx>:` keys on the counterpart; push configs are answered and never stored since the reduction (`pulseCreate`, 4967-4976), so the key does not exist. The outcome row is kept on purpose (28 M5). |
| 28b/01, 28b/06, 28c/06-tribe | throws `directed at cal@mazel` / `holding back` / `held at tribe` | The fix's own refusal, thrown before the exploit step. |
| 28b/03 | three `FAIL`s: "could compute the id", "lands on the predicted id", `other party on bob's copy: []` | Ids are random (28b H4). The third line reads bob's `conv:` at the *predicted* id, which nothing is at, and falls back to `{participants: []}`. |
| 28b/04, 28c/03-box-item | `no branch` / `the need reached bob's box` (then `mine=undefined`) | A forged open opens nothing (28c M5); there is no branch or box item to inspect. |
| 28b/05, 28c/04-block-bypassed, 28c/04-message-one | throws `no intro …` / `no conversation …` | An unsigned proposal is no longer an intro (28c H2) and a forged open is no thread; nothing to block or read. |
| 28c/01-relay-impostor | `must not become a candidate → card https://victim.c1/…`; `no box item may name a real handle` | As 29f §1: the relay points at an impostor's copy, the portal resolves the *real* victim through the directory and reads the card at the record's address, which fits; a real person, the portal's own scorer. The script's "(impostor)" label is its own text. |
| 28c/08 | `it is shown as an agent's → human` | Reads the signed `haah.author`, kept intact by the L2 fix; the coerced label is in the record's `author`, which `thread_read` returns. "Must still verify" passes. |
| 28d/01 | `FAIL note: sarah did not become a candidate` | A note line; `1 passed, 0 failed`. The planted key is refused. |
| 29f/02 | **new:** `precondition: the door acks the POST → error -32603 Not accepted` | The 29f H2 fix: a refused action is answered with a JSON-RPC error, not an ack. The remaining five assertions pass (no intro, nothing in the box, note attributed to nobody, no test mark). |
| 29f/03 | **new:** `precondition: bob's portal holds a proposal … that points at the branch → contextId undefined` | The 29f H3 fix: a received proposal names a branch only when its proposer opened it; here the id is dropped. The six leak assertions pass. |

29e's four remaining scripts pass 5/5, 3/3, 4/4, 4/4; 29f's 04, 05, 06, 07, 09 pass 6/6, 5/5, 5/5, 2/2, 4/4.
The 29f fixes hold where I re-read them: a refused action is dropped with an error (683-686); the outbox
re-signs on each attempt (3968-3970); `path` is the signer alone (698); a proposal's `contextId` is taken only
for a branch its proposer opened (3025-3028); `find` sends a matched-only need's buckets only to `chosenClose`
cards (4658); `resolve_handle` pins the record's key (2384-2388); rosters and pulls no longer key on a tier a
roster conferred (`chosenClose`, 3292).

---

## 2. The reduction, checked

`00-surface-check.mjs` (11/11 today) is the evidence for the first, fourth and fifth rows.

| Claim | Verdict | Where |
|---|---|---|
| One inbound path: the gate in `handleSend` | **Holds.** `GATED` (678) covers `find.hit`, `find.blind`, `intro.propose`, `intro.respond`, `tribe.roster`, `thread.open`, and a `note` that carries a `sig`; `verifyInbound` runs once (682) and a refusal is a JSON-RPC error with nothing written (683-686). `thread.close` is verified inside `applyInboundAction` (2972-2975) and `thread.message` at `onThreadMessage` (4058-4060); neither writes mail. An unsigned note is stored as `fromHandle: "unverified"` (692). | 537-709 |
| One identity writer: `pinCard` | **Holds for identity.** Every `known:` put that binds a handle to a key, door or content is `pinCard` (2516). `recomputeTiers` (3490) also rewrites a `known:` record, but changes only `tier` and `tierFromTribe`; `clear_test_history` (3229), `remove_known_card` and `pinCard`'s own de-dup (2519) delete. Noted, not counted. | 2445-2523 |
| One door reader: `deliver` | **Holds.** `doorFor` (2163-2167) is the only read of a held card's `rpc` for sending; `deliver` (2177) and `deliverThread` (3932) call it, and `refreshDoor` goes through `cardIdentity` → `pinCard`. `postTo` and `postMessage` take the address they are given; the only other caller of `postTo` is `send_to_peer` with an owner-typed address. `sendRoster` and `castBlindNeed` read `c.rpc` only as a filter and then call `deliver`. | 2163-2237 |
| 27 tools | **Holds.** `tools/list` returns 19; `more_tools` names 8; 27 in all. Thirteen old or internal names (`list_known_cards`, `add_known_card`, `resolve_handle`, `my_identity`, `clear_messages`, `fetch_peer_card`, `check_mutual`, `route_ghost`, `carriers`, `thread_block`, `tribe_join`, `list_threads`, `note_ghost`) are `unknown tool` on the raw Worker; `INTERNAL_TOOLS` are reachable only through a merged tool's `action` (1345-1355). The `legacy()` wrapper exists only in `a2a-helpers.mjs`. Its comment still says "twenty-nine (nineteen listed, ten hidden)"; the Worker says 27 (19 + 8). | 1147-1184 |
| 9 wire types | **Holds.** `ACTION_TYPES` (2239) is nine; `parseAction` (2330-2336) turns anything else into `{type: "note", v: 1}` with no fields. `find.request`, `thread.leave`, `thread.lapsed` and a made-up type each land as an unverified note. |  |
| Gossip forwarding, relay fan-out, router-kind `thread.open`, `thread.leave`/`lapsed` on the wire, push-config storage removed | **Holds.** No handler for `find.request`; `onThreadOpen` has one kind and admits exactly the signer and this portal (4170-4177); `router_for` is refused (2913) and a wire `router` object is not in `ACTION_FIELDS`; lapse is each side's clock (4232-4236); `pulseCreate` answers and stores nothing, `pulseGet` says so (4967-4990). No `pulse:` key is ever written. The relay refuses `kind: "blind"` (`relay/src/index.js:216`). Stale text only: the file header (11) still lists `find.request`; `handleRoot` (5105) still says `message/send`. |  |

---

## High

### H1 — A "revealed" need is taken on two buckets from the public card, boxed unfenced, and rings the bell

**Script:** `01-revealed-need-puts-a-strangers-prose-in-the-box-unfenced.mjs` (4 failed of 7).
**Location:** `onNeedBranch()`, `src/index.js:4711-4716`; `boxItem()` 4752-4760 (`mine: true`); `check_mailbox`
1850 (`if (m.mine) continue`).

A `thread.open` whose need carries `revealed: true` is meant to be the owner's yes after a blind match: this
portal answered someone's buckets with a `find.hit`, they said the words. Nothing checks that. The bar on the
reveal path is `fpOverlap(fingerprint(need.text), fingerprint(my persona + public haves)) >= 2` - two buckets
out of 4096, both computable by anyone from the open card, since `fingerprint` is public and the inputs are
the card. No tag has to match (the public path needs `strongFit`, 4729), `MAX_TEXT` is not applied (4727 is
public-path only), and the sender's `need.text` is spliced whole into the 📬 text: "*stranger@mazel said what
they are holding back, after your portal lined up on 3 signals: <text>*" - a record written `mine: true`,
which `check_mailbox` never fences. `agentFound` rings the bell.

```
PASS the public bar holds: a need matching none of bob's tags opens nothing
FAIL a "revealed" need is held only after this portal answered that sender's blind cast  -> 1 branch(es) opened; bob never sent a find.hit: 0 on the wire
FAIL a stranger's words reach the box only inside the fence  -> mine: true, text: 📬 Someone needs what you have: stranger@mazel said what they are holding back, after your portal lined up on 3 signals: hospital boards finan…
FAIL a need below the tag bar never lands as 📬 (§4.3c: below the fit bar is silence)
FAIL (and the bell rang for it)  -> stranger@mazel
```

Any stranger with a directory record gets an unfenced paragraph of their choosing into the owner's agent under
"Someone needs what you have", inside the one record kind the fence skips, with a sentence the portal did not
earn ("after your portal lined up on 3 signals": it never answered anything). High because it is the 28c M4
hole re-opened on a path that also bypasses the fit bar, from any signed stranger, on the box's most-read line.
The sender is real; the match and the portal's own claim about itself are not.

**Fix:** in `onNeedBranch`, take `revealed` only when this portal holds a `find.hit` it sent to that sender for
that `needId` (record the hit in `onFindBlind` - `hit:<needId>:<handle>` - and check it here; `onBlindHit`
already keeps `blind:` on the other side); apply `MAX_TEXT`; and fence the reveal's words the way every other
box item avoids peer prose - box the tags and the count, leave the text in the thread, as the public path does
(4731: "their words stay in the thread, labelled as theirs").

---

## Medium

### M1 — The per-sender ceiling is keyed on the handle a message claims, and the outbox turns a ceiling into a refusal

**Script:** `02-sender-cap-keys-on-a-claimed-handle-and-kills-a-real-yes.mjs` (4 failed of 6).
**Location:** `handleSend()`, `src/index.js:670` (mailbox path) and 584 (thread path, same key prefix
`a2a:from:<handle>`), counted before the gate at 678-686; `sweepOutbox()` 3977-3981 treats any `JSON-RPC error`
as "their portal refused it" (29f M2's give-up rule).

```
PASS (the hundred unsigned notes are taken as mail from nobody)  -> 100 acked
FAIL a signed answer from the real alice is not refused because strangers claimed her name  -> … their portal could not be reached just now. It is queued …
FAIL bob's portal holds her yes  -> bob: proposed
FAIL alice's owner is not told bob refused an answer bob never saw  -> Your answer to an intro for bob@mazel could not be delivered: their portal refused it (door returned JSON-RPC error -32600: Too many messages under that handle today…)
FAIL the yes is not dropped from the outbox  -> alice's copy: state proposed, queued false
```

One IP, a hundred unsigned notes each claiming `handle: alice@mazel`, and alice's real, signed yes meets
`-32600` at bob's door for the rest of the day. Her outbox retries once, reads "JSON-RPC error", gives up, and
tells her "their portal refused it"; bob never learns an answer was sent and his intro stays `proposed` for
ever. Her thread messages to bob are refused the same way (584 keys on `haah.from` before the signature is
checked). The same shape with the other ceiling: 400 unsigned notes from two IPs over two days fill the mailbox
(666-667), and from then on every queued proposal or answer to that portal is "refused" at its first retry
until the owner clears. A false "refused" is a fact shown to a person that nobody stands behind.

**Fix:** count the sender cap after the gate, on `sender.handle` (verified) or on the IP alone for an unsigned
note; and in `sweepOutbox` give up only on `-32603` (the door's own "not accepted" / blocked), retrying `-32600`
(a ceiling) with backoff like an outage. `postMessage` already distinguishes `refused` by code (3947); the
action branch should too.

### M2 — A rotated key cannot be followed by anyone who holds the card by hand

**Script:** `06-a-rotated-key-cannot-be-followed-by-anyone-holding-the-card-by-hand.mjs` (4 failed of 7).
**Location:** `pinIdentity()`, `src/index.js:4137` (a card held above world answers before the directory is
asked); `pinCard()` identity path, 2467 (refuses any key that differs from the held one, with no chain walk);
`resolveHandleTool()` 2383-2388 calls `resolveHandle` (which *does* verify the chain, 2137-2141) and then
`addKnownCard(identity)`, which refuses.

```
FAIL a proposal signed with the rotated key is taken by a portal holding the old one  -> … their portal could not be reached just now. It is queued …
FAIL alice's owner is not told bob refused it  -> Your intro proposal for bob@mazel could not be delivered: their portal refused it (door returned JSON-RPC error -32603: Not accepted: this portal could not verify…)
FAIL cards add by handle follows a verified rotation chain  -> Resolved alice@mazel: record signed by key … (1 rotation(s) on file) … Not stored. The directory names a different key … and no signed rotation chain leads from the old key to it
FAIL the held key moved to the new one
PASS (re-pasting the url by hand is the one road that follows the chain)
```

`rotate_key` tells the person "peers that remember the old key re-resolve and follow the chain". They do not.
After a rotation, every portal that holds the person's card by hand - which is their tribe and inner circle,
the people who pasted their link - refuses everything they sign: proposals and answers die as "refused" in
their outbox, thread messages come back "not signed by that participant", and `cards add` by handle says no
chain exists in the same sentence that reports one rotation on file. Only re-pasting the card url by hand
recovers, one holder at a time, and nobody is told to. Fails closed, so no impostor gets in; Medium because the
tool a person is told to run "if the key may have leaked" silently cuts them off from exactly the people it
matters to, and reports it to everyone as a refusal.

**Fix:** in `pinCard`'s identity path, when `prev.publicKey !== identity.publicKey`, walk
`chainLinks(prev.publicKey, identity.publicKey, record.rotations)` (the record is in hand: pass it on the
identity, or re-resolve) and accept when it verifies; in `pinIdentity`, when a signed action's key differs from
the held one, fall through to `cardIdentity` and let the chain decide before refusing.

### M3 — One signed note makes a stranger a chosen card in `find`

**Script:** `03-one-signed-note-makes-a-stranger-a-chosen-card-in-find.mjs` (3 failed of 6).
**Location:** `handleSend()`, `src/index.js:690` pins every verified sender not already held, at world;
`findInKnownCards()` 2774 scores every held card with `score >= 2 && matched.length`, no tier, no
`strongFit`; `searchRelay()` 3377 applies `strongFit` to strangers for the reason in its comment (3348-3352).

```
PASS (the note made bob hold the stranger's card, at world)
FAIL a card that drifted in on a note is held to the stranger's bar (strongFit), not the chosen card's  -> rank 1, tier world, via known, matched ["podcast-guest"], score 2: You need a fractional CFO for a hospital group; stranger@mazel has podcast-guest ("hospital group finance stories")
FAIL the need's words do not go to a stranger the owner never chose  -> thread.open at the stranger's door carrying: Looking for: a fractional CFO for a hospital group…
FAIL no ✨ for a gloss-word fit with someone who merely wrote in  -> ✨ Found someone for "a fractional CFO for a hospital group": stranger@mazel, on podcast-guest
PASS (for contrast: the relay offering the same card to a portal that never heard from it is dropped by strongFit)  -> []
```

A stranger with a directory record and a gloss stuffed with common words ("hospital group finance stories"
on a `podcast-guest` have) sends one note to a portal. From then on they are scored like a card the owner
pasted: the next public need with two of those words in it makes them the rank-1 ✨, opens a branch, and sends
the need's words to their door - a fit the relay path drops on purpose. Lock 12's letter holds (a real person,
the local scorer) and §5.4's spirit does not: one note to a thousand doors puts a card into a thousand
`find`s at the chosen-card bar. The cost of the note is one directory record.

**Fix:** either pin at the door only what the reply needs (`handle`, key, door) with `via: "door"` and skip such
cards in `find` unless the owner raises them, or apply `strongFit` in `findInKnownCards` to every card whose
`tierByHand` is null and `mutualAt` unset - the same set `chosenClose` already draws.

---

## Low

### L1 — `check_mailbox` leaves sender-chosen envelope fields, `tribeName` and `ask.size` unfenced; two tools echo a `why` with no fence

**Script:** `04-check-mailbox-leaves-sender-chosen-fields-unfenced.mjs` (4 failed of 4).
**Location:** `check_mailbox`, `src/index.js:1845-1863`: fenced are `text`, `fromHandle`, `from` and `PROSE`;
narrowed are `handle`, `proposer`, tags and `path`. Raw: `fromCard`, `senderMessageId` (the wire's messageId,
128 chars), and on an unsigned note every field `ACTION_FIELDS.note` keeps - `publicKey`, `cardUrl`, `rpc`,
`kid`, `castAt` - which no signature ever checked; on a verified proposal `tribeName` and `ask.size`.
`respond_intro`'s not-confirmed reply (3108) and `list_intros` (3242) repeat the proposer's `why` bare.

```
FAIL nothing a stranger typed is shown to the agent outside the fence  -> unfenced: cardUrl, messageId, publicKey, action.cardUrl, rpc, kid, castAt
FAIL a proposer's prose fields are fenced like the why  -> unfenced: tribeName, ask.size, …
FAIL respond_intro's own reply fences the why it repeats  -> Not sent. This tells alice@mazel's agent "accepted" to: join my circle …
FAIL list_intros fences the why
```

28c: "the instruction simply moved to a field that was not wrapped." Seven such fields on an anonymous note.
Low because the tool text says every result is untrusted and the agent should already be reading these as data;
the fence exists because "a tool description the host may truncate" is not enough. The same class, no script:
`onBlindHit` (4846) puts `${action.overlap}` raw into a `mine: true` line (a held sender; `Number()` is applied
one line later for the record but not the text).

**Fix:** narrow the envelope on the way in - `publicKey`/`kid`/`sig` to base64url, `cardUrl`/`rpc` to https,
`castAt` to a date, `senderMessageId` to `[A-Za-z0-9._-]` - and drop them from the mailbox record for an
unsigned note (they proved nothing); add `tribeName` and `ask.size` to `PROSE`; fence `why` where the two
tools repeat it.

### L2 — Blocking a branch whose other side is a world-tier card blocks nothing

**Script:** `05-thread-block-on-a-branch-with-a-world-card-blocks-nothing.mjs` (2 failed of 5).
**Location:** `openBranch()`, `src/index.js:4665` takes the other participant's key only from a card held
above world; `thread_block` 1542 skips a participant with no key (29f H1's rule: never block a name somebody
else supplied).

```
PASS (a branch with them is open; their key in it is null)  -> [["bob@mazel",true],["stranger@mazel",false]]
PASS (the tool says the portal is blocked)
FAIL blocking a branch blocks the portal on the other side of it  -> blocked: keys written: 0; trust: 0
FAIL a note from the blocked portal is refused at the door  -> landed as fromHandle stranger@mazel
```

The world card *has* the record's key (`pinCard` stored it, 2495); the branch just does not carry it, so the
one control the owner has against a stranger who fits their public need - which is who world-tier candidates
are - writes `conv.blocked` and nothing else, while saying "Everything from that portal is refused from now on
- this thread, notes, proposals, needs". `report: true` records no trust entry either.

**Fix:** in `openBranch`, take `publicKey` from the held card whatever its tier (every world card now comes
through the gate or the directory, 2467/2478); in `thread_block`, when a participant has no key, resolve it
through `pinIdentity` before deciding there is nobody to block, and say so when there still is not.

---

## 3. Every path in the brief, checked against the handle rule

| Path | Handle → key | Handle → door | Content / presence | Verdict |
|---|---|---|---|---|
| MCP `cards add` by url | card the owner pasted; a changed key needs a chain (2481-2490); keyless never replaces keyed (2486) | card | card | holds (owner's TOFU) |
| MCP `cards add` by handle | record, then the card at the record's url (2384-2388) | record | record's card | holds; **M2** when a key is already held |
| MCP `contacts *`, `tribe *`, `thread_manage *`, `link_ghost` | held card only | held card | owner's own | hold |
| MCP `find` → `openBranch` | held card (above world) or null | held | scorer's own | holds; **M3** for who counts as held; **L2** for the null key |
| MCP `propose_intro`, `respond_intro`, `respond_intro_link`, `/intro` | held or directory | `doorFor` | `path` = signer | hold |
| MCP `thread_send`/`thread_note`/`thread_read`/`thread_list`/`thread_share`/`inbox_link` | participant's pinned key, else directory | `doorFor` | verified on receipt | hold |
| MCP `send_to_peer` | none (owner-typed address, fenced ack) | as typed | fenced | by design |
| MCP `rotate_key`, `my_card`, `pulse`, `my_memory`, `update_card`, `claim_link`, `clear_test_history`, `reveal_need` | own key | own | own | hold; `reveal_need` goes only to a held card that answered buckets (1790) |
| `/a2a` unsigned `note` | none: stored as `unverified` (692) | — | fenced; **L1** for the envelope fields | holds |
| `/a2a` signed `note`, `find.hit`, `find.blind`, `intro.propose`, `intro.respond`, `tribe.roster`, `thread.open` | `verifyInbound` (held above world, else directory + the card at the record's url), fresh, key on the action equals it | record's (pinned at 690) | proposer = signer; `path` = signer; `contextId` only a branch the signer opened; roster members through the directory | holds; **M1** counts before the gate; **M3** pins at the door |
| `/a2a` `thread.open` (the one kind) | gate; open must name this portal and the signer; note verified against the signer, fresh (4735) | sender's own | screened at the public bar | holds for public; **H1** for `revealed` |
| `/a2a` `thread.message` | participant's key or `pinIdentity` (4152-4160); `from` must be a participant | — | author coerced in agents-only branches | holds; no `fresh(h.at)` (29f residue: `seen:t:` 3 days + 200 window) |
| `/a2a` `thread.close` | `verifyInbound`, participant by key (4179-4189) | — | — | holds |
| `/a2a` push-config methods | answered; nothing stored | — | — | holds |
| Relay `/search` results | `pinIdentity` → directory + the record's card (3369-3373) | record | record's card, `strongFit` | holds |
| Rosters | organizer's key = entity's organizer, tribe held, member of it (3522-3530) | record | record's card (2472-2478); a by-hand card is never overwritten (2470) | holds for identity; the `member_of` edge is written for any handle the organizer lists even when its card cannot be pinned (3534), which only matters once that card is held (29f L3 territory) |
| Rotation | old key signs, new countersigns; chain walked in `resolveHandle` | — | — | holds on the wire; **M2** in the writer |
| Outbox | re-signed each attempt; `refreshDoor` → `cardIdentity` → `pinCard` (record's door, no key change) | record | — | holds; **M1** for what counts as a refusal |
| Reply by link | MAC, 14 days, 30/day, dies with block and delete; stored as the named contact's words | — | — | holds |
| `/inbox`, `/card?as=` | session cookie + CSRF; pull signed over `{as, e, at: origin}` against a `chosenClose` card | — | — | hold |
| Blocks | by key and by every handle the message names (641-652) | — | — | hold; **L2** for a participant with no key |

**Observations, no script, not counted.** `recomputeTiers` (3490) is a second writer of `known:` for tier only.
The door acks a verified `intro.respond` it then ignores (no such intro here, or already answered, 3024); the
responder's portal shows 🌀 and a thread while the proposer's does not - reachable only when the proposer's intro
is gone, which no honest path does today. A verified responder can name, as the thread of its yes, the
proposer's branch with it for a *different* need (the responder knows that id); `openThreadFromIntro` then
throws "branch of a different need" (3874) after the intro was written `connected` (3055), the door answers
500, and the intro is connected on the proposer's side with no thread - the counterpart's own doing, nobody
else's. `onNeedBranch` does not tie `note.contextId` to `action.contextId` (the same sender's own branches).
A card's handle is stored in the case its card spells it (`parseAgentCard`, 2364) while every lookup lowercases,
so a card that says `Sarah@mazel` is a dead candidate with no door; not a hole. `knownCards()` lists and reads
every `known:` key several times per inbound message (641, 646, 4137); with **M3** a stranger can grow that list.

## 4. Lock 12, checked

Every 📬, ✨, 💬 and 🌀 traces to an object on this portal: a need branch's message one is verified against
the signer's key and stored as the signer's agent's (4735-4741); ✨ is the local scorer on a held card
(4689); 💬 is a verified participant's message or a reply through a link the owner minted (4084, 4586); 🌀 on
the proposer's side needs a verified `intro.respond` against the exact counterpart's key (3025), on the
responder's side the owner's own yes to a verified proposal (3147). Two participants only, the signer and
this portal, everywhere (3908, 4170-4174). A refused action is an error, not mail (697-699).

**One thing reaches the box that the portal cannot stand behind:** **H1** - a 📬 saying "your portal lined
up on N signals" and "said what they are holding back" for a need this portal never answered and that clears
no bar, carrying a stranger's unfenced words. **M3** is a real person and a real score at the wrong bar: a ✨
the spec's own comment says a stranger should not get. **M1** fabricates a refusal, not a match: "their portal
refused it" for a yes the other portal never saw. **M2** fabricates the same refusal for an honest rotation.
**L1** and **L2** fabricate nothing.

Closing H1 (a reveal only after a hit this portal sent; fence or drop the text), M1 (count verified senders;
give up only on -32603) and M3 (`strongFit` for cards nobody chose) leaves no path this pass could find by
which a person sees a match, a yes, a message or a refusal that no real portal and no real event stands behind.

---

*Scripts in this folder each print `FAIL` and exit non-zero today (`00-surface-check.mjs` passes); they pass
once the fixes above land.*
