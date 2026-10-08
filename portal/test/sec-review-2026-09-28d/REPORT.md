# Security review — Mazel v0.5.8-box, fourth pass (`sec-review-2026-09-28d`)

Fresh reviewer (Fable), no context from the build. Commit `ba7e6d1` ("one inbound gate, random ids
everywhere, the 28c review folded in"), untagged. Read: `portal/src/index.js` (5518 lines), the
suites in `portal/test/`, the 28b and 28c reports, and `MAZEL-SPEC.md` §3.6, §6.4, §6.5, §7.5,
§11.4 lock 12. Nothing under `src/` or in any existing test was changed. Every finding below has a
standalone Node ESM script in this folder that fails today. Run from `portal/test`:

```
for f in sec-review-2026-09-28d/0*.mjs; do node "$f"; done
```

**Count by severity: 1 High, 1 Medium, 1 Low.**

The one inbound gate holds where it was aimed. `verifyInbound`/`verifyInboundMessage` bind every
signed action and thread message to a key, fresh, and refuse a key the directory does not name;
random ids close the squat/collision/replay paths the earlier passes found. All three findings here
are the same shape: a path that pins an identity **without** going through `pinIdentity`'s directory
step (2), or that trusts a field the directory step never covers. The key check is doing real work,
which is why two of these leave the key correct and still fail — they route or rebind around it.

---

## High

### H1 — A tribe organizer plants any key for a third party's handle, and a fabricated 🌀 follows

**Script:** `01-tribe-roster-plants-a-third-party-key.mjs` (drives it to the 🌀).
**Location:** `onTribeRoster()` (`src/index.js:3556`) → `addKnownCard()` (`2492`); the short-circuit
in `pinIdentity()` (`4205`) that trusts a held non-world card without the directory.

The gate's own rule (the comment at `4155`) is that a card is a person only through step (2): the
card at the address, whose handle is that handle, and whose key **the directory's signed record for
that handle names**. `pinIdentity` skips (2) whenever the portal already holds a non-world card for
the handle — correct for cards the owner added by hand. But `onTribeRoster`, on a roster signed by a
tribe's organizer, calls `addKnownCard({ url: m.cardUrl, tier: "tribe", by_hand: false })` for every
member the organizer lists, and `addKnownCard` stores `parsed.publicKey` from whatever card sits at
that url with **no directory check and no continuity check**. So the organizer can list a third
party's handle (`sarah@mazel`) pointed at a card the organizer controls, carrying a key of the
organizer's choosing. That card lands as a tribe-tier held card; from then on `pinIdentity("sarah@
mazel")` returns the planted key and never consults the directory.

The organizer is a party the owner cleared only by accepting a tribe invitation. Having done so, the
organizer can now impersonate anyone: the script joins the tribe the ordinary way, the organizer
rosters `sarah@mazel` at an impostor card, `sarah` surfaces as a `fractional-cfo` candidate, the
owner proposes, and an `intro.respond` signed by the planted key verifies as sarah's yes —

```
FAIL a roster must not plant a key for a handle the directory never vouched for
  -> alice now holds sarah@mazel at tribe tier with the impostor's key, rpc https://evil-d1.example/a2a
FAIL an intro.respond signed by a planted key must not connect as the real person -> intro state connected
FAIL no 🌀 may be boxed for a person who never said yes
  -> "🌀 Both said yes: you and sarah@mazel are in the thread."
```

That is lock 12: a 🌀 the owner is shown for a person who never said a word, with a real handle on it.
The same planted key also lets the organizer open branches and send thread messages "as sarah". A
roster can even overwrite and downgrade a card the owner holds by hand at inner tier, since
`addKnownCard` replaces `publicKey` and takes `tier: "tribe"` unconditionally.

**Fix:** roster-added cards (`by_hand: false`) must clear step (2) before their key is trusted —
resolve the handle and require the card's key to equal the directory record's, exactly as
`keyFromCard`/`cardIdentity` already do for `thread.open` third parties. A roster names *where* a
member's card is; it must not be allowed to name *who a handle's key is*. Fold the continuity guard
(H3 below) into `addKnownCard` so no path rebinds a handle's key without a rotation chain.

---

## Medium

### M1 — A lying or misconfigured relay reroutes a real handle's door; the key check gives false cover

**Script:** `02-relay-swaps-a-real-handles-door.mjs`
**Location:** `cardIdentity()` (`src/index.js:4189`), reached from `searchRelay()` (`3393`) via
`pinIdentity`.

Step (2) authenticates the **key** against the directory but takes the **rpc and cardUrl** from the
card the relay named. `cardIdentity` fetches `r.cardUrl`, checks the card's handle and that its key
equals the directory record's key, then returns `{ publicKey, rpc: parsed.rpc, cardUrl }` — the rpc
being whatever that card advertises. The authentic door is right there in the record it just
verified (`rec.rpc`, `rec.cardUrl`) and is discarded. A public key is public, so an attacker serves a
card carrying sarah's real key but the attacker's own door. The key check passes; `rememberStranger`
stores `sarah@mazel` pointed at the attacker's rpc, `openBranch` delivers the public need's words
there at once, and the owner's intro proposal follows —

```
FAIL a real handle must be stored at the door the directory names, not the one the relay named
  -> stored rpc is https://evil-d2.example/a2a (directory says https://sarah-d2.test/a2a)
FAIL the public need's words must not travel to a door the relay chose  -> need words present: true
FAIL an intro proposal for a real handle must reach that person, not an attacker
  -> reached real sarah: false; reached attacker: 2
```

The real sarah hears nothing; the attacker reads the need text and the proposal, and (relaying the
proposal on so sarah's own yes reaches the owner directly) can sit as a silent man in the middle on
every later thread message, since messages go to the rpc the portal holds. §7.5 says the cache "never
decides a match a portal could not decide alone" — choosing a real person's delivery door is exactly
that. It is Medium rather than High because it needs a lying or misconfigured relay (no person or yes
is fabricated), but the key authentication makes it read as safe when it is not. Gossip and signed
paths are not affected: there the sender proves the key, so they are only naming their own door.

**Fix:** in `cardIdentity`, return `rpc` and `cardUrl` from the directory record (`rec.rpc`,
`rec.cardUrl`), not from the fetched card; a card the sender did not sign for must not choose where a
handle's mail goes.

---

## Low

### L1 — `add_known_card` replaces a held handle's key with no continuity check

**Script:** `03-add-known-card-replaces-a-key-without-continuity.mjs`
**Location:** `addKnownCard()` (`src/index.js:2492`).

`resolveHandle` (`2205`) enforces continuity: if the portal already holds a key for a handle and the
directory shows a different one, it refuses unless a signed rotation chain leads old→new. Plain
`add_known_card(url)` does not — it stores `parsed.publicKey` and, for an existing handle, overwrites
the key with no compare to the previous one and no directory lookup —

```
FAIL add_known_card must not silently replace a held key without a rotation chain
  -> pinned key is now the new (unproven) key
```

So a second `add_known_card` for a handle the owner already holds — a url an attacker talked them
into, or a card whose host was swapped — silently repoints the pinned identity, and every later intro
and thread message verifies against the new key. Owner-initiated, hence Low, but it is the mechanism
behind H1 and the one place the "key is the identity, changing it needs a rotation" rule is skipped.

**Fix:** run the same continuity check `resolveHandle` uses on every path that rebinds a handle's
key — `add_known_card`, `resolve_handle`, and the roster.

---

## The eight 28b and the twelve 28c fixes: confirmed

The full portal suite is green (`test/run.sh`: every suite `N passed, 0 failed`, fixtures match the
Worker). The prior exploit scripts were re-run; each earlier defect is closed. As before, an exploit
script "passing" means its exploit assertion no longer reproduces — it either throws the fix's own
refusal or prints `FAIL` on a precondition that is no longer true.

| Pass | What still holds today |
|---|---|
| 28b H1 directed-need leak | `propose_intro` throws "that need is directed at …"; `10-…-under-variation` all 14 green |
| 28b H2 thread.open bound | `02-…` 5/5; a replay after close/delete does not reopen (`07`, `08` green) |
| 28b H3 relay verified | `01-relay-impostor` 5/5, `02-stranger` 5/5 — a wrong key is refused (M1 above is the wrong *door*, not key) |
| 28b H4 / 28c H3,H4 random ids | branch, thread, intro, need ids all random; the "id is derivable" assertions now fail by design (`28c/02`,`05`) |
| 28b H5 / 28c L2 author | agents-only branch shows message one as agent; the coerced label lives in the record's `author` field and `thread_read` surfaces it, while the signed bytes are left intact (see note below) |
| 28b M1 / 28c M2 block | portal-wide, by key or by any named handle (`28c/04`,`07` green) |
| 28b M2 / 28c M4 box prose | `invite_text` refuses held needs; box `why` lines carry tags only, never peer prose (`28c/06` green) |
| 28c H1 impostor | relay and gossip both refuse a card whose key the directory does not name |
| 28c H2 unsigned propose | `01-unsigned…` 6/6 — a proposal is nothing without a verified signature |
| 28c M3 reply link | dies with a block and a delete (`05` green) |

**Two 28c scripts print `FAIL` but the property they guard holds** — each asserts on an internal
detail the fix implemented differently, verified independently here:

- `28c/08-coerced-author…` checks `message.metadata.haah.author === "agent"`. The L2 fix deliberately
  does **not** rewrite that signed field (rewriting it broke the signature at rest, which was the
  finding); it keeps `haah.author` as signed and records the coerced label in the record's top-level
  `author`, which `thread_read` returns and the stored message still verifies. The script's own
  "must still verify" assertion passes.
- `28c/03-box-item-carries-peer-prose…` asserts the injected need reaches the box. It no longer does:
  a branch's message one must be signed (`onNeedBranch`), and the box `why` for a public need is
  `you have <tags>`, so no peer prose reaches a box item regardless.

## Lock 12, checked

Sound except H1. Every candidate, ✨, 📬 and 🌀 traces to a signed object whose key cleared the gate —
**unless** a tribe roster planted that key (H1), in which case a fabricated candidate, its yes, and
its 🌀 all reach the owner under a real handle. M1 does not fabricate a person or a yes; it misroutes a
real one. Fixing H1 (route roster keys through the directory) closes the one fabricated path found in
this pass.

---

*Scripts in this folder each print `FAIL` and exit non-zero today; they pass once the fixes above land.*
