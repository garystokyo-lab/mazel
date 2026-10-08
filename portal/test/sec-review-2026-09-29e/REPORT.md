# Security review — Mazel v0.5.8-box, fifth pass (`sec-review-2026-09-29e`)

Fresh reviewer (Fable), no context from the build. Commit `478ae88`, untagged. Read: `portal/src/index.js`
(5543 lines), `relay/src/index.js`, the suites in `portal/test/`, the 28b, 28c and 28d reports and scripts, and
`MAZEL-SPEC.md` §4.3, §4.3b, §4.3c, §6.4, §6.5, §7.3, §11.4. Nothing under `src/`, `relay/`, or in any existing
test was changed. Every finding below has a standalone Node ESM script in this folder that fails today. Run from
`portal/test`:

```
for f in sec-review-2026-09-29e/0*.mjs; do node "$f"; done
```

**Count by severity: 2 High, 2 Medium, 2 Low** (seven scripts: H2 has two instances).

## 1. The 28b, 28c and 28d scripts: all pass

`test/run.sh` is green: 16 suites `N passed, 0 failed`, `live-peer` skipped (no `PEER_URL`), fixtures match the
Worker. Every 28b/28c/28d script was re-run. As in 28d, an exploit script "passes" when its exploit assertion no
longer reproduces; the remaining `FAIL` lines are all of one of three kinds, and none is a live defect:

| Script | What prints `FAIL` | Why it is not a defect |
|---|---|---|
| 28b/03, 28c/02-gossip, 28c/05 | "mallory could compute the id", "thread id is a pure function of the tag", "bob's copy at the predicted id" | Ids are random now (28b H4 / 28c H3,H4); the prediction the script relies on no longer exists, and its "need must reach bob at all" assertion passes. |
| 28b/04 | "message one must be labelled agent -> no branch" | Precondition: the forged open no longer produces a branch at all. |
| 28b/08 | "nothing may be sent to an address the relay made up -> [`…/card`]" | The one hit at the attacker's host is the gate's own `GET` of the card to check it (cardIdentity); no send reached it (the script's other three assertions pass). |
| 28c/03-box-item | "the need reached bob's box" | Precondition false: the injected need no longer reaches a box; 28d already recorded this. |
| 28c/08 | `haah.author === "agent"` | The signed field is kept intact by design; the coerced label lives in the record's `author` (28d note); "must still verify" passes. |
| 28d/01 | `FAIL note: sarah did not become a candidate` | A note, 1 passed 0 failed: the planted key is refused; there is nothing left to drive to a 🌀. |

28d's three fixes hold: rosters and pulls clear the directory step with continuity (`addKnownCard` at 2509–2520),
`cardIdentity` returns the record's door (4227), and a by-hand `add_known_card` refuses a changed key without a
chain (2522). 28c/01 and 28c/02 still refuse a wrong key from the relay and from gossip.

## 2. What is still bound without the directory, and what is fabricated

The gate is doing its job for **keys**: every signed action and thread message is verified against a key that
either the owner pinned by hand or the directory's signed record names. Nothing below defeats a signature. All
six findings are the same two shapes the earlier passes kept finding, on paths they did not reach:

- a **door or a card's content** taken from someone other than the handle's owner, after the key check gave cover;
- a **person named on the wire** by a party who is not that person, with nothing the person signed behind them.

---

## High

### H1 — A router puts a third party into a thread, and a 🌀, on nothing but its own word

**Script:** `01-router-names-a-third-party-who-never-asked.mjs` (3 failed of 6).
**Location:** `applyInboundAction()` stores `action.router` as sent (`src/index.js:3043`); `openThreadFromIntro()`
pushes `{ handle: intro.router.for, cardUrl: intro.router.cardUrl, rpc: intro.router.rpc }` into the thread at
`3946` (the branch case) and `3984` (the fresh case); the box line at `3958` names every non-me participant.

An `intro.propose` may carry `router: { handle, for, cardUrl, rpc }`. The proposer signs it, so the *router* is a
real portal. The *third party* signed nothing: not a need, not a yes, not their card. The responding portal stores
the router object as-is, and on the responder's yes adds `router.for` to the thread with the card and door the
router wrote, then boxes:

```
FAIL no 🌀 may name a person who never asked and never said yes
  -> "🌀 Both said yes: you and router@mazel, alice@mazel are in the thread."
FAIL a third party joins a thread only through something they signed
  -> alice@mazel is a participant of 762618dc on the router's word, door https://evil-e1.example/a2a
PASS alice's own portal was never told  -> 0 conv(s) on alice's portal
FAIL a person's message to a named participant must not go to a door the router chose
  -> 1 message(s) at the router's door; text present: true
```

So a real handle is shown as a party to a 🌀 they never took part in (lock 12), the responder's first human
message "to alice" is delivered to an address the router picked and marked delivered, and the real alice's portal
holds nothing (it accepts a router's `thread.open` only from a router it holds, which is right; the damage is on
the responder's side). The spec's router shape (§4.3, §6.5) is: the caster asked by casting, the router's yes is
the yes to route. The code has the second half and not the first: nothing ties `router.for` to a signed cast by
that person. `propose_intro(router_for)` works from any thread the router typed on its own portal, and the wire
form is just a JSON object anyone can write.

**Fix:** a third party enters a thread only through an object they signed: the router's proposal carries the
person's own signed `find.request` (the need, as it reached the router), verified through the gate as that
handle's, and its `needId` is what the thread's origin records. Their door and card come from `pinIdentity`
(held card or directory), never from the router. Until that exists, refuse `router.for` outright and let a
routed intro be two ordinary intros; and the 🌀 line names only handles whose yes this portal holds.

### H2 — A card's content is trusted from any address that carries the right key: a real person gets haves they never claimed

**Scripts:** `02-relay-result-points-at-a-copy-of-a-real-card.mjs` (3 failed of 5, through the real relay code
in-process), `02b-tribe-roster-points-at-a-copy-of-a-members-card.mjs` (2 failed of 3).
**Location:** `cardIdentity()` returns `card: parsed`, the card at the *caller's* address (`4227`), and
`searchRelay()` scores and stores it (`3429`); `addKnownCard(by_hand:false)` takes the door from the record but
`need/have/glosses/description` from the card at the organizer's url (`2537`).

28d fixed *where the mail goes*; *what the person has* still comes from a card nobody at that handle serves. A
public key is public, so a copy of sarah's card with an extra have passes the key check anywhere it is hosted.

Script 02 runs the relay's own `cast()`/`search()`: mallory, with any key, casts a card-cast under
`sarah@contoso-e2.test` pointing at her copy. The relay takes it, because its cast-under-a-held-name check only
covers names in *its* directory, and a company directory (§6.4, first-class) is not it. Alice's `find`:

```
FAIL a real handle must not become a candidate on the strength of a card nobody at that handle serves
  -> candidate: You need a fractional cfo for a hospital group; sarah@contoso-e2.test has fractional-cfo ("twenty years a CFO").
FAIL no ✨ may land in the box for a match the person's own card does not make
  -> ✨ Found someone for "a fractional cfo for a hospital group": sarah@contoso-e2.test, on fractional-cfo.
FAIL a card held under a real handle carries only what that handle's own card says
  -> stored have: fractional-cfo; key matches directory: true
PASS the need must not travel to sarah as a branch ... -> 0 branch(es) on the real sarah's portal
```

That is a fabricated ✨ in the box under a real handle (lock 12), and the world-tier card alice now holds for
sarah says she does something she does not; alice's proposal, if she makes one, reaches the real sarah with a why
that is false. The one thing that held is sarah's own fit bar: the branch went to her real door (28d's fix) and her
portal screened it out silently. For a `name@mazel` handle the relay's cast check does block an anonymous caster,
so there the same result needs a lying or misconfigured relay. Script 02b is the second instance: an organizer
lists a real member at a copy with invented haves and the member lands at **tribe** tier with them
(`tribe: You need …; sarah@mazel has fractional-cfo … And you are both in Health Systems Circle.`), which also
lets tribe-held needs travel to them on tags the organizer wrote.

**Fix:** after the directory step, the card that describes a handle is the card at `rec.cardUrl`, fetched from
there; a card at any other address is at most a pointer. Concretely: `cardIdentity` fetches `rec.cardUrl` when
it differs from the given url and returns that one as `card`; `addKnownCard(by_hand:false)` reads content from
`rec.cardUrl` too. (For the relay, additionally refuse a card-cast whose `cardUrl` host differs from the caster's
own record's host, as `subscribe` already does; that is a belt to the portal's braces, not a substitute.)

---

## Medium

### M1 — A blind hit's door is the relay's word, and the held-back need's words go there on the owner's yes

**Script:** `03-blind-hit-reveals-a-held-need-to-a-relay-chosen-door.mjs` (3 failed of 5).
**Location:** `onBlindHit()` stores `who.rpc` (`~5077`); `reveal_need` delivers to `b.rpc` (`1844`).

A relay-signed blind hit names `from: { handle, cardUrl, rpc }`. The hit's *signature* is the relay's, so the
relay is naming a door for somebody else, which is exactly what 28d M1 stopped `cardIdentity` from accepting.
This path never calls it: the door is stored, the owner is told "a portal lines up on 4 signals" with no name, and
on their yes the matched-only need's text is signed and delivered there:

```
FAIL the door on file for a real handle must be the one the directory names -> https://evil-e3.example/a2a
FAIL a held-back need's words must not go to a door the relay chose -> 1 message(s) at the relay-chosen door; need words present: true
FAIL the words go to the real sarah, or nowhere -> real sarah's mailbox: 0
```

Medium: it needs a lying or misconfigured relay (an honest one names the door its own `subscribe` check verified),
but what leaks is the one thing matched-only exists to protect (§3.6), and nothing the owner is shown could catch it.
Gossip blind hits are not affected: there the sender signs and names only their own door.

**Fix:** in `onBlindHit`, `pinIdentity(who.handle, who.cardUrl)` and store `id.rpc`; refuse a hit whose handle
does not resolve. Say the handle in the question.

### M2 — On a router's `thread.open`, the third party's key comes from the directory but their door from the router

**Script:** `04-router-names-a-third-partys-door-on-thread-open.mjs` (2 failed of 4).
**Location:** `onThreadOpen()` `4300–4301`: `publicKey = … || keyFromCard(cardUrl, handle)`, then
`rpc: k.rpc || p.rpc`; `keyFromCard` (`4257`) drops the `rpc` that `cardIdentity` just computed from the record.
Same shape one branch earlier at `4287` ("a router may supply an address this copy lacks").

```
PASS a participant's key is pinned through the directory -> key ok: true
FAIL a participant's door is the directory's, not the router's -> door on file: https://evil-e4.example/a2a (directory: https://sarah-e4.test/a2a)
FAIL a person's message to a named participant must not go to a door the router chose -> 1 message(s) at the router's door
```

This is H1 seen from the third party's own portal: the key check makes it read as safe while the router chooses
where this person's words to the other party go. A router is in the thread and reads everything while present; the
harm is after `thread.leave`, when it keeps receiving both sides' human words and the named person receives
none while the sender sees "delivered".

**Fix:** use `cardIdentity` directly there and take `rpc` and `cardUrl` from it (`id.rpc`, `id.cardUrl`); a
participant's door on the action is used only when the directory names none. Same at `4287`.

---

## Low

### L1 — The outbox re-resolve stores the card's key and door, not the record's, on cards held by hand

**Script:** `05-outbox-re-resolve-takes-the-cards-key-and-door-over-the-records.mjs` (3 failed of 4).
**Location:** `reResolveRpc()` `2223` and `2226`.

The moved-portal path resolves the handle correctly (signed record, continuity against the held key), then
fetches `rec.cardUrl` and writes `publicKey: parsed.publicKey || held.publicKey` and `rpc: parsed.rpc` from the
**card**, on the held card and on every thread participant with that handle: no compare of the card's key to
`rec.publicKey`, no check of the card's handle, and `rec.rpc` discarded. The continuity check is against the
record; what is stored is the card. It runs inside a failed send, where the owner sees nothing:

```
FAIL a held key changes only through a signed rotation chain, ... -> held key is now the card's unproven key
FAIL a moved portal is followed to the record's door, not the card's -> rpc now https://evil-e5.example/a2a (record says https://sarah-e5.test/a2a)
FAIL nothing is delivered to a door the record does not name -> 2 message(s) at https://evil-e5.example
```

Low because it needs the person's own card host to serve something their signed record does not say (a stale or
poisoned cache, a taken-over host). But it is the one remaining path that writes a key the directory does not
name, and it rebinds a card held **by hand**, which `addKnownCard` now refuses to do for anyone.

**Fix:** require `parsed.publicKey === rec.publicKey` and `parsed.handle` to match, store `rec.rpc`/`rec.cardUrl`,
and never touch `publicKey` there (a key changes only through `resolveHandle`'s chain).

### L2 — A keyless card named after a held handle replaces the held key with none, and the door with the stranger's

**Script:** `06-add-known-card-keyless-copy-drops-a-held-key.mjs` (2 failed of 3).
**Location:** `addKnownCard()` `2522`: the guard is `prev.publicKey && parsed.publicKey && prev.publicKey !== parsed.publicKey`.

A plain A2A card (no Mazel extension, no key) whose `name` is `sarah@mazel` skips the continuity guard, and
`add_known_card(url)` writes `publicKey: null` and the stranger's rpc over a card the owner holds at inner tier,
saying "Refreshed known card sarah@mazel". The gate then falls back to the directory for sarah's key, so nothing
fabricated verifies; but every reader of the held card's door (`propose_intro`, `openThreadFromIntro`,
`tierForPull`, rosters) now has the stranger's, at the tier the owner chose, and the haves are wiped. One pasted
link ("here is Sarah's new card") does it. Owner-initiated, hence Low; the same class as 28d L1.

**Fix:** a missing key is a different key: keep the guard when `parsed.publicKey` is null and `prev.publicKey`
is not, and never let a HAAH-less card refresh a HAAH card.

---

## 3. Checked and holding

Every path the brief named, with where the binding happens:

| Path | Handle → key | Handle → door | Verdict |
|---|---|---|---|
| `add_known_card` (by hand) | card; refuses a changed key without a chain (2522) | card (owner pasted) | holds, except L2 |
| `add_known_card` via roster / pull (`by_hand:false`) | directory, continuity | record | holds for key and door; content is H2b |
| `resolve_handle` | directory, continuity | record | holds |
| `tribe_invite`, `tribe_join`, `tribe_remove`, `link_ghost`, `check_mutual` | held card only | held card | hold; `tribeId` on an invitation is the inviter's and only creates an entity that does not exist |
| `send_to_peer(rpc)`, `fetch_peer_card(url)` | none (raw address, owner-given, fenced) | as given | by design |
| `/a2a intro.propose`, `intro.respond`, `find.request`, `find.blind`, `find.hit` (gossip), `thread.*` | `verifyInbound` → `pinIdentity` (held or directory) | `id.rpc` (held or record) | hold; the router object inside `intro.propose` is H1 |
| `/a2a find.hit` via relay (need cast) | relay key, then `pinIdentity(from)` | record (28d) | holds for key and door; `real = fetch(who.cardUrl)` is H2 when the caster is not the handle |
| `/a2a find.hit` blind, via relay | relay key only | `who.rpc` from the relay | M1 |
| `/a2a tribe.roster` | organizer's key, tribe held; members through `addKnownCard(by_hand:false)` | record | holds (28d H1 closed); content is H2b |
| `/a2a thread.open`, router kind | router held; third parties via `keyFromCard` | router's action | M2 |
| Relay search results | `pinIdentity` | record (28d) | key and door hold; content is H2 |
| Rotation records | old signs, new countersigns, chain walked in the portal and the relay; the relay also demands the portal serve its own record | — | holds; a rotation's `handle` is not checked but a link needs the old key's signature, so it cannot be borrowed |
| Outbox re-resolve (`reResolveRpc`) | record for continuity, **card for what is stored** | card | L1 |
| Reply by link | none by design: MAC over the link id, 14-day expiry, per-day cap, dies with a block or a delete; stored as the named contact's words, never a portal's | — | holds |
| Pulse subscriptions (`CreateTaskPushNotificationConfig`) | unauthenticated register; read/list/delete owner-only | — | nothing is ever delivered to a registered url (`pulse:` keys are only listed and deleted); holds |
| Blocks | by key and by every handle the message names | — | holds |

Not findings, noted: `cardIdentity` compares the card's handle exactly, so a card saying `sarah@mazel.ai` does not
match a result for `sarah@mazel` (functional, not security). A tribe organizer can raise a real third party to
tribe tier on a member's portal by listing them (the edge is saved even when the card fetch fails); that is the
roster's designed power and the party's key and door still come from the directory.

## 4. Lock 12, checked

Every 📬, 💬 and 🌀 traces to a signed object: a need branch's message one is verified against the sender's pinned
key; a reply is verified or came through a link the owner minted; a 🌀 needs a verified `intro.respond` or the
owner's own yes to a verified proposal. **Two things still reach the box that no real person stands behind:**

- **H1:** a 🌀 naming a person who never asked and never said yes, on a router's word; the responder's human
  words to that person go to a door the router chose.
- **H2:** a ✨ ("Found someone for your need: sarah, on X") built from a copy of a real person's card that the
  person never served, and a held card that now says they do X. Reachable anonymously for any handle whose
  directory is not the relay, and by a lying relay or a tribe organizer for anyone.

Neither fabricates a signature; both fabricate what a real, verified key is said to have done or to have. Closing
H1 (a third party only through their own signed cast, door through the directory) and H2 (content only from the
card the record names) leaves no fabricated path this pass could find. M1, M2 and L1 misroute real people rather
than invent them; L2 is owner-initiated.

---

*Scripts in this folder each print `FAIL` and exit non-zero today; they pass once the fixes above land.*
