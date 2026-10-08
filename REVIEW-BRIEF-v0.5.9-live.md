# Reviewer brief: everything that changed since v0.5.8.2

## One paragraph

Since `v0.5.8.2` a portal's state has moved off Workers KV and into a per-portal Durable Object on
the SQLite backend, reached through a single seam (`storeFor`) so the 177 call sites above it did not
change, with one deliberate exception: the published public card stays in KV (`card:public`) so a
stranger fetching a card never wakes the object and a portal's public face survives an unreachable
one. Moving an existing portal is a separate, repeatable copy (`migrate_store`) that deletes nothing,
reports the key count on both sides and compares every value before anything is switched, and the
switch itself is one installer flag (`--store do`, with `--store kv` and a copy back as the
rollback). On top of that seam, a need now reaches people one hop further than a card match allows:
`need.offer` carries a need, signed by the caster and verified at the same door as everything else,
to the portals that already hold the caster's card, with no path and no hop count in the message and
no forwarding by the receiver, and a hit against the receiver's own contacts becomes exactly one
question for that receiver while the caster is told nothing on a pass or on silence. Four rules now
stand between a match and that question, all of them about the contact rather than the need: a
fourteen-day rest after a yes, a drop out of matching after two asks with nothing heard back, a
permanent never-ask flag, and an invitation that names who is asking and what for. Contacts
themselves are now seeded as part of install for every user, saved up to fifty at a time with an
all-or-nothing refusal over the limit, scored on the portal from counts the agent reports rather
than by the agent itself so two agents reading the same mailbox cannot disagree about a person, and
found again on a repeat pass by an HMAC of the person's main address under a secret generated on
that portal that never leaves it, so no address and no globally computable hash is ever stored. The
bar an arriving need must clear against a contact was tightened from "one shared word scores two" to
"an exact tag is worth two, an uncommon shared word one, and a word this portal's own contacts share
nothing", with at most three questions raised per arriving need and the rest kept against those
contacts. Finally, a need the owner states out loud now has to end somewhere: the first find for a
need the card does not carry returns one plain question about whether it is public or private, the
question rides on every later tool result until it is answered, and until then nothing about that
need leaves the portal in words at all, not to the relay, not to a held card, not as a branch, and
not on a pulse.

## Where data from another portal enters

Everything below is untrusted input. There is one door, and the gate runs once inside it.

| entry | what arrives | what screens it |
|---|---|---|
| `POST /a2a` -> `handleSend` | every signed action: `note`, `find.hit`, `find.blind`, `need.offer`, `intro.propose`, `intro.respond`, `tribe.roster`, `thread.message`, `thread.close`, `thread.open` | the gate: `cardIdentity` / `pinIdentity` / `verifyInbound` / `verifyInboundMessage`, run once here. A refused action is dropped and never written, never attributed, never boxed |
| `onNeedOffer` | a need offered one hop by a card this portal holds | sender must be held; replay killed by `seen-offer:`; 20 a day per sender; text length capped; matched-only arrives as a fingerprint with no tags |
| `onBlindHit` | a hit on a need this portal cast blind | must match a need this portal actually sent |
| `onThreadOpen` | a branch opened by another portal | the gate, plus the rule that a revealed thread cannot be opened by the other side |
| `addCandidates` / `searchRelay` | handles, cards and why-lines from the relay | the relay is never trusted for a door or a key: a handle resolves through the record the portal serves for itself; a world-tier card is held to the stranger's bar |
| `pinCard` (`cards add`) | a card fetched by URL or handle | the card's own signature and the directory's record for that handle, never another party's say-so |
| `GET /card`, `/.well-known/agent-card.json`, `/.well-known/mazel/<handle>.json` | nothing inbound; these are read | served from the published KV copy for the public tier; a tiered pull needs a signature that matches the card this portal holds for that person |
| `POST /mcp` | the owner's own agent | the connector key. Everything here is the owner's, and peer-written strings are fenced in `<<peer>>` markers with a rule telling the agent not to follow them |
| `POST /claim`, `/intro`, `/inbox/clear` | a person clicking a signed link | the link's own signature, scoped to one action |
| `GET /memory`, `/inbox` | nothing inbound | the connector key |

Two rules to hold the review against. Nothing fabricated reaches a person (lock 12), which is why
`find`, `contacts`, `list_ghosts` and `note_ghost` now carry a record-only rule in the description
and in the result. And everything about a handle comes from something that handle's owner signed, or
from the directory's record for it, never from another party's message.

## First on the list

The offer path and the keyed hash per person, then the core-loop question, in that order.
