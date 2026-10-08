# Mazel changelog

## v0.5.9-live

**Security review `sec-review-2026-10-07a`** (fresh reviewer, no build context): 2 High, 3 Medium,
6 Low, all fixed.

- **H1, a repeat save wiped the owner's answers about a person.** `saveGhost` rebuilt the record from
  what the reader sent and carried forward only some fields, so `asked`, `heard`, `lastAskedAt`,
  `lastHeardAt` and `neverAsk` were undefined after any re-save. A seeding pass re-saves everyone in
  every slice, so the thing the agent does most often undid three of the four contact rules:
  never-ask stopped being permanent, a contact asked yesterday was asked again today, and a contact
  two asks into silence came back into matching. The owner's answers are now carried forward.
- **H2, the migration copied one page and called it complete.** KV answers a list with at most 1,000
  keys and a cursor for the rest. With 1,204 keys it wrote 1,000, counted both sides from the same
  truncated listing and reported `equal: true`; the owner, told to read the counts back, would have
  switched and lost the 204 newest. One helper now follows the cursor, used by the migration and by
  `kvList`, which had the same blind spot for every prefix and now matters because seeding aims at
  hundreds of contacts. A paged stub with 1,205 keys holds it.
- **M1, an offer was bound to its signer and not to a recipient.** A signature says who wrote an
  offer and nothing about who was meant to read it, so a portal inside the caster's circle could
  post the bytes at a portal the caster never chose, and that portal would score it and raise a
  question; for a need held back, the fingerprint reached outside the circle the owner drew by hand.
  Each offer is now signed per recipient with `to` inside the signed body, so it cannot be stripped
  or rewritten, and an offer naming someone else is refused at the door.
- **M2, one arriving offer wrote a record for every contact that fitted.** Sixty fits cost 77 writes,
  each record carrying the caster's full text, so twenty offers a day from one held card spent a KV
  portal's entire daily allowance. One arriving need is now one document holding the questions
  raised and the matches kept, and one offer is one thing in the box and one ring of the doorbell
  rather than three. **77 writes to 10**, with the receiver's side added to lock 13.
- **M3, the caster's words reached the agent unfenced** through the contacts list, the one slot that
  did not fence them. Fenced.
- **L1**, `propose_intro` sent an unplaced need's words; it now returns the question instead.
  **L2**, the first find after a private answer opened a branch carrying the need's own tag beside
  its fingerprint, which the release path refuses to send; a need held back now opens no branch from
  the caster's side and the side that matches the buckets opens it. **L3**, `invite_text` ignored
  never-ask and did not count as an ask; it refuses, and handing the words over starts the rest.
  **L4**, the migration copied keys without an expiry, so a mailbox that cleared itself stopped
  doing so; a prefix table gives each copied key a life. **L5**, two people with one name and no
  organisation became one record and the later save replaced the earlier one's tags; a name match
  now needs an organisation both sides agree on or a witness they share, and a free id. **L6**, the
  changelog ships in the friend zip and named a real person; scrubbed, and the zip build now refuses
  rather than warns.

**Nothing that ships names a real person.** The worker is deployed to every user's own account, so
one person's name, company and contacts were in a file every stranger installs. Removed from the
worker, the installer copy, every shipped test and fixture, the user-facing documents and this
changelog; decision attributions keep their date and lose the name; the friend-zip build refuses if
a name reappears.


A portal's state moves off KV and into a Durable Object with the SQLite backend, which runs on
Workers Free, so the install promise stays a free Cloudflare account. On top of that seam: a need
reaches people through the portals that hold a card for the caster, a contact hit becomes one
question for the owner, and the people a person already knows are seeded as part of install.

**One storage seam.** Every read and write goes through `storeFor(env)`, which answers from the
object when `STORE=do` and the binding is there, and from KV exactly as before when it is not. The
object is one `Portal` class over a single SQLite table, honouring expiry on read and on list. KV's
free plan allows 1,000 writes a day; SQLite allows 100,000 rows written, and 2 MB a value against
KV's 128 KiB. `known:` moved in with everything else, so there is one writer.

**One thing stays in KV: the published record.** `card:public` holds the public card and the handle
record a stranger reads. The gate makes every portal fetch a card before it believes anything, and
those reads have no business waking the object. A pulse that changed nothing writes nothing, because
the comparison ignores the timestamp and the signature. A portal's public face also survives an
object that cannot be reached: the card still answers when the portal can take no mail.

**A need is offered to the cards this portal holds.** `need.offer`: one hop, signed by the caster,
verified at the door like everything else, with no path and no hop count in it, and no forwarding by
the receiver. An owner may not do revenue cycle but know somebody who does; without this the need
never reaches him, because a need travels only to a card that itself fits. A public need travels as
its words, a need the owner is holding back travels as a fingerprint and is scored that way, and a
need held at tribe or inner never travels at all. Ceilings: 200 portals for one need, 20 offers
accepted from one sender a day, and 40 subrequests a run against the free plan's fifty.

**A contact hit is one question for the owner, and nothing goes back.** The caster is told nothing
on a pass and nothing on silence, which is what makes it safe to look; a receiver learns nothing
about the caster's other recipients, because the message carries none. A replay of the same signed
offer changes nothing.

**A person you know is not a queue.** Four rules stand between a match and a question: a contact
rests for `CONTACT_REST_DAYS` (14) after a yes, a contact asked twice with nothing heard back drops
out of matching until a reply is recorded, a never-ask flag is permanent until the owner lifts it,
and the invitation names who is asking and the specific need. A resting match is kept against that
contact in the contacts list, where the owner can still ask anyway.

**The bar an arriving need has to clear.** Before this, one shared word scored two, so a need about
revenue matched every contact with revenue anywhere on them, and forty contacts matched one need. Now
an exact tag is worth two, an uncommon shared word one, and a word this portal's own contacts share
nothing: both a fixed stop-list and whatever the portal's own counts show, at a fifth of the
contacts or more. One arriving need raises at most `CONTACT_HITS_PER_NEED` (3) questions, strongest
by fit then by how well the owner knows them. The rest are kept against those contacts and raise no
📬. Someone the owner barely deals with is a match worth keeping and not a question worth asking,
the same floor their own search uses.

**Seeding is part of install, for everyone (spec §8.3b).** The first real pass, on 2026-10-05, read 1,623
calendar events, 1,275 sent threads and 168 deals, and took his portal from 16 contacts to 137. That
pass needed scripts; the product version runs in a plain chat. Three storage parts ship here:
- **Evidence in, scores out.** An agent reports what it counted per person and per source: meetings,
  small meetings, threads sent and replied, deals and best stage, referrer count, the dates each way
  and the unanswered count. The portal computes the edge with one formula, in one place, so two
  agents reading the same mailbox cannot disagree about a person and the weights can be retuned with
  no re-read of anyone's mail. The counts are kept beside the score. An agent's own number is still
  taken when it has nothing to count, and marked as the agent's.
- **A batch of fifty.** One `contacts` call carries up to 50 people. Fifty-one is refused with the
  number allowed and nothing partial is written.
- **A private key per person.** The portal stores an HMAC of the person's main address under a secret
  generated on that portal that never leaves it, 32 hex characters. No address is stored, no unkeyed
  hash exists to look up, and nothing about it goes on a wire. All it does is find the same person on
  a repeat pass and attach a second address to the record already there.

**How warm a contact is, stored now and read by nothing yet.** Dates each way, the unanswered count,
and a state: active, owner went quiet, they went quiet, cooled, unknown. **Cooled is the owner's own
word and is never inferred**; an owner-set state is never overwritten by an inferred one. Tone is a
reader's label limited to warm or businesslike, with one line of reason, because a machine must not
be able to write down that a person is cold or difficult and hand it to someone who knows them. No
message text is stored anywhere against a contact, and no label in the product says a relationship
ended or went badly.

**The witnesses map now matches the card** (reported from a live portal, 2026-10-06). Three faults, one
symptom. `my_card` filters have and need to the public tier and lists held tags separately, but
handed back the whole witnesses map, so a have parked at tribe and a matched-only need appeared as
bare keys with nothing on the card to explain them, which reads exactly like a tag that was removed
and did not quite go. `add_need` ignored the witnesses argument, so every need had an empty entry
while haves had real ones. And `remove_have` / `remove_need` left the tag's witnesses, last-seen
date, tier and gloss behind in the call that removed it, which the next read happened to rebuild
clean. Now the map is keyed on the tags the card carries at every tier and nothing else, a need
records where it was read from the way a have does, and a removed tag takes its entries with it
unless it is still on the card at another tier.

**Lock 13 covers the fan-out** (`kv-budget-test`, 27 checks): one cast touches at most 50 portals
whatever the number held, the rest are kept on the need and carried on by later pulses, the whole run
costs the thread record and nothing per recipient, and once every need has reached every card a pulse
is quiet again. Two real bugs came out of writing it: the pulse was dropping the fan-out progress on
its re-read, so the same forty portals would have been offered the same need for ever; and six open
needs each took a full batch, which was 235 subrequests in one pulse against a ceiling of fifty. The
allowance is now the run's, shared by every open need.

**The migration, and the bug it caught.** `migrate_store` is a hidden tool that copies a portal's
state between KV and its object. It is a copy and never a move: it deletes nothing, so running it
twice is running it once, and it reports the key count on both sides plus a value-by-value
comparison before anything is switched. `--store do` on the installer is the only thing that moves a
portal over, and `--store kv` brings it back.

Two faults came out of running it for real rather than against a stub:

- **The tool was copying the object onto itself.** Inside a request `env.MAILBOX` is already
  whichever store is in effect, so on a migrated portal it was the object and the real namespace was
  on `env.kv`. It would have reported a clean migration that never happened. It now resolves the
  namespace explicitly, whichever way round the env is.
- **The object stub was cached on `env` across requests.** A worker reuses the same env object in an
  isolate, so the stub belonged to the request that made it and the next request died with "Cannot
  perform I/O on behalf of a different request". The first real mailbox read on the test peer hit it
  immediately; no stubbed object in a test could have shown it. A stub is now made per request and
  nothing is kept on env. Three checks in `do-store-test` hold it there.

**The test peer is migrated** (mazel@mazel.ai). Its KV was exported to a file first: 706 keys, 706
values, no empties. After the copy both sides held 706 keys with zero mismatched values, and KV was
untouched by it. With `STORE=do` the portal answers my_card, check_mailbox, thread_list and contacts
from the object, and the public card is still served out of KV. The rollback is `migrate_store` with
direction `to-kv`, then a deploy with `--store kv`: KV still holds everything it held, and the copy
back is what carries whatever arrived in between.

**The installer binds the storage object.** Every portal now deploys with a `PORTAL` binding and
the `Portal` class declared as a new SQLite class, which is what makes it free: 100,000 rows written
a day against KV's 1,000 writes, and 2 MB a value against 128 KiB. A deploy that is handed a
migration tag the script already has is refused by Cloudflare, so the refusal is caught and the
upload goes again without it. The KV namespace stays bound on every portal, because the published
public card lives there and because an unmigrated portal still reads and writes KV.

A **new** portal gets `STORE=do` and starts in the object, since it has nothing to migrate. An
**update** never sets it: a portal still on KV stays on KV, and one already migrated keeps `STORE`
by inheriting it. Moving an existing portal is its own step, with an export and a verify in front of
it. The `Deploy to Cloudflare` path gets the same binding through `wrangler.json`. Four checks in
`cli-test` cover it, including that an update leaves storage where it is.

**A stated need ends somewhere** (decided 2026-10-06, needed for the first outside installs). Saying "mazel, I need X"
searched, opened a thread and left the card untouched, so the need existed only as a thread the
person could not see, and the owner had to ask whether it had been added at all. Now the first find for a
need the card does not carry comes back with one sentence to put to the person, word for word: "Put
this on your card for everyone, or keep it private? Private reaches fewer people." No tiers, no
visibility, no matched-only; the agent is told in as many words not to offer that vocabulary. The
answer is written with `update_card`, public or held at matched-only, and the agent is handed the
line to say back in the person's own words.

The question does not get lost. It lives in one document, every tool result carries whatever is
still unsettled, and it keeps coming back until the need is written. A turn cannot end with a need
the person stated stored nowhere and nobody asking about it.

**Nothing goes to strangers until they have answered.** Writing the test for this caught a hole in
the first version: the find cast the need to the relay before the person had chosen, so "private"
would have been theatre, and gating only the find left the pulse to cast it half an hour later with
the question still open. Both paths now wait. An unsettled need is still matched against the cards
this portal already holds, which is what the person asked for by saying it out loud, and answering
releases it at once rather than at the next pulse.

**Lock 12 at the point an agent breaks it.** Seen live: a contact's record named a system they support, and
benefits support" and the agent told the person "he owns the system open enrollment runs through",
which nobody had written anywhere. `find`, `contacts`, `list_ghosts` and `note_ghost` now carry a
record-only rule in the description, and `find` and the contacts list carry it in the result as
well: say what the record holds, never what the person owns, runs, decides or is senior enough to
do, and if the record does not answer, say so.

**Correction, 2026-10-06.** An earlier note in this section and in the `v0.5.10-seed2` plan said 109
of a live portal's 137 contacts came from LinkedIn with no direct exchange. That number came from the ghosts
test fixture, not from his portal, and was wrong. His portal holds 137 contacts read from calendar,
Gmail and HubSpot on 2026-10-05, none from LinkedIn, and 127 of them carry a meeting, a reply or a
deal in `edge_signals` as text. The structured fields were empty only because they did not exist
until this version. An empty structured field is not an absence of exchange and is never to be read
as one.

Suites: 123 checks on contacts, 27 on the budget, 27 on the object store, 901 across the whole run,
all green. Install page, install text and the install script in the Worker all carry the seeding
step; the tool descriptions say to report counts rather than scores.

## v0.5.8.2

The company account hit the free plan's ceiling of 1,000 KV **list** operations a day on
2026-10-05. Lists, not writes: v0.5.8.1 fixed what the portals wrote, and left what the relay reads.

- **A search scanned the namespace to answer.** `kvList("cast:")` listed every cached cast on every
  search, then read each one. One list per search at best, one per thousand keys at worst. The keys
  now live in one index, `idx:casts`, written when a cast is written and read when a search is
  answered: **one list per search becomes zero**. A cache that predates the index builds it once,
  from the only list left in the relay, and never lists again.
- **The deployed relay was still `v0.5.2`**, four versions behind, and that version also listed its
  subscriptions on **every cast and every subscribe** for a fan-out the reduction deleted in
  `v0.5.8-box`. With portals on `v0.5.7` subscribing and casting on every half-hourly pulse, that
  alone was hundreds of lists a day. Deploying the current relay removes those paths entirely.
- **A card was re-cast to the relay every half hour**, though a cast lives a week, which cost the
  relay a write and an index write each time. The portal now casts its card when the card has
  changed or the cached copy is near lapsing, the same rule `v0.5.8.1` gave needs.
- **The relay has no cron**, so "a cron never lists" holds by construction, and the budget test
  asserts it stays that way.
- **Lock 13 now covers the relay** (`kv-budget-test`, 20 checks): a search lists nothing, ten
  searches list nothing, a cast lists nothing, a directory lookup lists nothing, and the relay
  exports no scheduled handler. The first-pulse write budget goes from 1 to 2, for the stamp that
  stops the card being re-cast.
- **Before and after**, forty cards in the cache: **search 1 list to 0** (41 gets), **cast 0 lists
  either way**, directory lookup 0 either way. On the deployed `v0.5.2` the before was worse: a list
  per cast and a list per subscribe as well.
- The two install pages had drifted apart since the page rewrite; `install.html` now carries the same
  copy as the Squarespace block, which is what the install-file rule asks for.

## v0.5.8.1

A portal was spending its day's KV budget on a timer. Found on 2026-10-03, when both portal accounts
hit Cloudflare's free-plan ceiling of 1,000 KV writes a day while the relay's account, which pulses
nothing, did not.

- **The pulse stamped every open need, every half hour, with a time nothing read.** `lastPulse` was
  written once per open need per pulse: at nineteen open needs, 912 writes a day before anyone said a
  word. The field is gone, and a need is written only when something about it actually changed.
- **A need was re-cast to the relay every half hour**, though a cast lives a week in the cache. That
  was 336 casts for one sentence's week - it spent the relay's own allowance for that key, which is
  why needs read as "waiting for the relay's day to turn over" - and each answer wrote the need back
  to KV for a timestamp. A need is cast when it is new, when the relay's cap left it pending, or when
  the cached copy is within a day of lapsing.
- **The card list was read once per call site, twenty-five of them.** One inbound message cost five KV
  lists plus a get per card. It is read once per request now, cleared as each request and each pulse
  begins and whenever a card is written.
- **New suite, `kv-budget` (12):** it counts what each operation writes, by key prefix, and holds each
  to a budget - a pulse, an inbound message, a retry against a dead address, a reply - and names the
  hottest single key, because KV allows one write per second per key. A change that writes on a timer,
  in a loop, or on every retry of a dead address fails here.
- **Before and after**, five open needs in the harness: a quiet pulse **5 writes → 0**; a retry against
  a dead address **6 → 1**; lists per inbound message **5 → 2**. On a live portal, nineteen open
  needs: **912 writes a day → 0**. An inbound message still costs 4 writes, which is proportional to
  real traffic and not a timer.
- **Still true, and not fixed here:** the daily counters `cap:a2a:ip:<address>` and
  `cap:a2a:from:<handle>` are one key written on every message, so a burst from one address meets
  KV's one-write-per-second rule. Live state moves to a Durable Object in `v0.5.9-live`, where a
  counter is a variable rather than a key.

## v0.5.8-box (built, reviewed by four fresh sessions, untagged pending release)

One need, one thread; the box; the listed surface; and, after the reviews, one inbound gate.

- **One need, one thread.** A need is a root; a branch — a conversation with its own random `contextId` — opens per candidate the moment a real one answers: a held card that fits, a gossip or relay hit, a saved contact. Candidate A never sees candidate B. The receiving portal screens the need against its own card at its own fit bar before holding a copy. In a branch the agents talk first, as agents; on 🌀 the people join that same branch with its history, and the agents' summary is the intro note. `list_threads` survives as the roots.
- **Tier rides on the branch** (§3.6). A matched-only need travels as a fingerprint and its matched tags — no why line, no words in the proposal — and its words are released into the branch only after both people say yes. A tribe- or inner-held need goes only to someone held that close. A directed need opens only with the person it names (`need_to`, kept on the memory file) and cannot be proposed to anyone else.
- **The box.** Four kinds, each a message in a thread and each an object on this portal: someone needs what you have; found someone for your need; a reply; both said yes. `check_mailbox` and `/inbox` show the same box. `DOORBELL_DAILY_CAP` (default 3) for agent-found items, the rest waiting and named in the next ring; replies and 🌀 ring at once; one item per thread until read; no peer prose in a box sentence, ever.
- **The ring offer is held** behind `RING_OFFER` (default off) while §12.5 is open: no button, no permission prompt; the iPhone guide no longer mentions ringing.
- **Outcomes per branch**, `outcome:<contextId>`, passes included, holding the need and the intro.
- **The listed surface: 52 tools → 19.** The loop, four merged tools (`contacts`, `tribe`, `cards`, `thread_manage`), `more_tools` for what is hidden, and `claim_link` / `respond_intro_link` kept listed for ChatGPT Plus and Pro.
- **The inbound gate** (reviews 28b and 28c: 5 + 4 high, 4 + 5 medium, 1 + 3 low; every one reproduced, every high and medium fixed). The per-path identity checks are gone; one rule stands for everything that arrives claiming to be from somebody: the action is signed and fresh; the handle resolves to a key — a card the person holds by hand, or the card at the address given, for that handle, whose key the directory's signed record names; the signature verifies against that key. A card is a person only that way, relay answers included. Proposals and answers are signed on the wire. Every id a stranger could otherwise compute — a need, a branch, a thread, the thread at 🌀 — is random. Reply-by-link is the one door with no handle behind it, gated by its MAC, expiry and cap.
- **Review 28d (a fresh session; 1 high, 1 medium, 1 low), one rule:** every path that binds a handle to a key or a door goes through the directory step, with continuity. A card not added by hand — a tribe roster, a pull — is stored only if the directory's record for its handle names its key, and its door and address are the record's, never the fetched card's. A card held by hand is never overwritten by such a path and never lowered. On every path a handle already held changes key only through a signed rotation chain; a pasted link with a different key is refused in words, and the card you hold stays. `cardIdentity` returns the door from the directory record, so a card the sender never signed for cannot choose where a handle's mail goes.
- **Review 29e (a fresh Fable session; 2 high, 2 medium, 2 low; all 23 earlier fixes held), one rule:** everything about a handle - its key, its door, what its card says, whether it is in a thread - comes only from something that handle's owner signed, or from the directory's record for it. Nothing about a person is taken from another party's message: not a router's proposal, not a tribe roster, not a relay result, not a blind hit, not a card hosted at another address. So: a handle's card is the card at the address its record names, fetched from there, and a card anywhere else is at most a pointer (`cardIdentity` resolves the handle first and reads the record's card; a roster or pull stores content only from there; the relay refuses a card-cast whose card is not on the caster's own host). A third party enters a thread only through something they signed: `router_for` is refused in words, a `router` object on the wire is dropped and the proposal stands as an ordinary one, the 🌀 line names only the one person whose yes this portal holds, and routing returns as a signed cast of the person's own in a later batch. A blind hit's door is the directory's, the question names the handle, and a hit whose handle does not resolve is nothing. On a router's `thread.open` every participant's door is the directory's, never the action's. The outbox re-resolve stores the record's door and never writes a key. A missing key is a changed key: a card with no key never replaces one that has one. Security suite 68 + **98**; thread 103.
- **Review 29f (a fresh Fable session; 3 high, 3 medium, 3 low; all 38 earlier scripts held), fixed as one:** a typed action the gate refuses is dropped at the door - no mailbox record, no attribution, no `test: true`, only a day's counter and a JSON-RPC error so an honest sender's outbox knows (the gate now runs once in `handleSend`, and every note travels signed; an unsigned note is mail from nobody in particular, `fromHandle: unverified`). A router-kind `thread.open` is refused outright until routing arrives as the person's own signed cast (item 11); a block names only a handle whose key this portal verified. A proposal may name only a thread its proposer opened; a matched-only branch's words leave only through the proposal about that need, from the portal that holds it. The path on a received proposal is the one who signed it. The outbox re-signs a fresh envelope on every retry. A matched-only need's buckets go only to the circle the owner drew by hand or on their own yes, on `find` as on the pulse, and a tiered pull is served only to that circle; a roster-conferred tier matches and nothing more. `resolve_handle` pins the record's key or nothing, in words. A relay blind hit counts only for a need this portal blind-cast to that relay. Security suite 68 + **115**.
- **The reduction (2026-09-30, approved in `REDUCTION-PLAN-2026-09-29.md`), the batch's last step:** one path in, one place identities are pinned, one place doors are read, one writer of `known:`. Gone: gossip forwarding (`find.request`, the hops and the path, the ghost-ask on a hop), the relay's fan-out and blind-to-relay (`/subscribe`, `notifySubscribers`, `notifyBlind`, `BLIND_TO_RELAY`, the relay's signing of hits), the router remnants (`kind` and `firstWriter` on `thread.open`, `thread.leave`, the offer to step out, `collision`), `thread.lapsed` on the wire (each side lapses on its own clock), push-config storage (the four methods answer, nothing is kept), `check_mutual` and the pull it made, `carriers`, `fetch_peer_card`, `my_identity` (now on `my_card`), `resolve_handle` (now `cards` add by handle), `clear_messages` (now `check_mailbox` with `clear`), `list_queue`/`clear_queue` (now `tribe` queue actions), `route_ghost`, and the twenty-one old names of the merged tools' parts. `deliver(handle)` looks the door up on the card this portal holds and, on a move, through the directory and the one writer; participants, intro parties, candidates, blind matches and the outbox refer to a person by handle and key and carry no door. The gate holds a verified stranger at world tier through that one writer. A held-back need revealed on the owner's yes travels as the branch it already had. The relay is a cache a portal asks and nothing more. Portal 5 583 → **5 198** lines (189 → 183 functions), relay 426 → 303, Rust smaller by the shapes that left; 58 → **27 tools** (19 listed, 8 hidden, none by the old names); eight review scripts retired (`portal/test/RETIRED.md`) and the suites that tested gossip, subscriptions, routers and lapses on the wire rewritten to the model that stands.
- **Review 30g (a fresh Fable session on the reduced code; 1 high, 3 medium, 2 low; the rule and the reduction hold), fixed as one:** a revealed need is taken only from a sender whose buckets this portal answered (the hit it sent is on file), at the tag bar and size limit, its words fenced in the box item like any peer prose. The per-sender ceiling counts the sender the gate verified; unsigned traffic counts against its address alone; a ceiling or a full mailbox is a wait for the sender's outbox, never "refused" (only a door's own -32603 is). A verified rotation chain moves the held key in `pinCard` - at the gate, in a thread and in `cards add` by handle - so a rotated peer keeps talking to everyone who holds them with no re-paste, and a key with no chain is still refused. A stranger pinned from a note is held at world and cleared in `find` only by a have that answers the need (`strongFit`), the relay's bar. Every sender-chosen field is fenced or narrowed before the agent reads it (envelope fields to their shape, `tribeName` and `ask.size` fenced, an unsigned note's envelope dropped, `respond_intro` and `list_intros` fencing the why they repeat). A branch carries the held card's key whatever its tier, and a block resolves a missing one from the held card, so blocking a world-tier branch blocks the portal. Security suite 68 + **132**.
- **What the gate costs, plainly:** a stranger is a person only while the directory can be asked. With the relay down, a portal you do not hold by hand cannot be verified, so gossip between strangers waits until it is back. Nothing stored is lost; reach is.
- **Install file updated in the same batch**, as the rule now requires: install pages, onboarding description, welcome page.
- Suites: **box 43** (new), security 68 + **80**, thread 108, install 87; seventeen suites green; cargo green.

## v0.5.7.2-sec

The fresh review of `v0.5.7` (2026-09-28, no context from the building session; report under `portal/test/sec-review-2026-09-28/`): 1 high, 4 medium, 2 low. M3 was raised to high and M5 to urgent. All fixed, each with a test in the security suite's second file.

- **H1 — a block is portal-wide.** The door reads it before anything else, by signing key or named handle: a blocked portal's notes, needs, proposals and thread messages in any thread are refused, silently.
- **M3, raised to high — a participant's key comes only from the card in the intro or the thread at open**, never a world card, and only if the directory's signed record names the same key. A router's proposal carries the routed-for person's card and door.
- **M5, urgent — delete leaves nothing of the thread's**: the reply link (address dead), the counterpart's subscription, the dedupe keys, any report made from inside it; and it says what stays — the content-free outcome record, for the ledger.
- **M2 — fresh timestamps on thread actions**; a lapse only on an unwritten thread, and only when the receiver's own clock agrees.
- **M4 — thread traffic under the per-sender cap**; one ring per thread per ten minutes; nothing into a full mailbox.
- **L1 — one page for a forged, unknown or expired reply link.** L2 mitigated by M4.
- Security suite 68 + 29.

## v0.5.7.1-use

Four fixes from the first real use of `v0.5.7`, each with a test. The version constant stays 0.5.7; the tag carries the .1.

- **The fit bar holds for the world.** A stranger from the relay or a gossip hop gets in only on a have that answers the need — the tag, or a word of the need's own tags — weighted by rarity; a gossip hit is judged on the stranger's card as fetched, never on the tags it claims.
- **A portal that moved.** A failed send resolves the handle through the directory, reads the card behind it, saves the new door, and tries once more; only then the outbox, retried with backoff for seven days before the owner hears. Proposals and answers both; a queued answer that lands completes as a live one would, 🌀 and thread included.
- **Test traffic is marked and clearable** (`TEST_HANDLES`, default `testpeer@mazel`; `clear_test_history`).
- **Names and the why, never ids**, in what the person reads.
- Suite: moved 32 (new).

## v0.5.7-thread

Mazel is the messaging layer between connected people. After 🌀 a thread opens between the two portals, built out of A2A's own parts, and the conversation lives on those two portals and nowhere else.

- **The thread is its own object**: one `contextId`, a record per portal, every message under its own key so a long relationship is never a wall. States `open → sent → replied → met`, or `lapsed`, or `closed`. An intro reaching `connected` opens one with the §4.5 note as message one, carrying `ask {kind, size}`.
- **Messages are A2A `Message`s** with text, file and data parts; under `metadata.haah`: `author: human | agent`, who, when, an Ed25519 signature, and `envelope: null` reserved for `v0.5.8-seal`. A person's words pass verbatim.
- **Delivery is portal to portal**; on open each side registers an A2A push notification config on the other with **no bearer token** — the signature is the authentication. Unreachable: an outbox retried with backoff for seven days, then the owner told once.
- **Who writes first** (§4.3b): direct, the side with the need; collision, the finder; router, a three-party thread with an offer to step out after the first reply; tribe, as direct.
- **`/inbox`**, an installable app: `inbox_link` mints a ten-minute single-use link that sets an `HttpOnly; Secure; SameSite=Lax` cookie scoped to `/inbox`; sessions last thirty days, rotate after seven, die with the inbox token; CSRF on replies; everything inline. iPhone users get the Home Screen guide once.
- **The doorbell**: web push with an empty body — nothing to encrypt, nothing carried; the service worker asks the portal, over the session, who wrote. Cloudflare email needs a zone; a scheduled task in the AI app is the documented alternative; the badge line is the floor.
- **Reply by link** for a contact with no portal: fourteen days, renewable at the same address, thirty replies a day, plain pages when it cannot be used.
- **Edge behaviour** on the pulse, config defaults 3 / 14 / 5 days; close, block (report counts against trust), delete (only this copy), export.
- **Outcome objects, from day one, backfilled**: every intro gets `outcome:<introId>` the day it is proposed, with origin, carrier, tier, router, matched tags, contextId, and a timestamped history. Never a word of content.
- **The old thread tools stay** (`list_threads` etc. are need threads); eleven new `thread_*` tools plus `inbox_link`.
- Suites: thread 105 (new), a2a-conformance 14 → 21.

## v0.5.6-queue

- **At the ceiling, the rest queues.** `invite_text` and `tribe_invite` no longer refuse past their daily ceiling: what the person already said yes to waits, and the pulse releases it as each day's room appears, oldest first. `list_queue`, `clear_queue`; a fortnight's lapse. Proved with a 300-member tribe seeded from one approval, finishing across two days.
- **A relay cap is a wait, not an error.** Over the relay's daily allowance the cast stays pending, the first pulse after the day turns over sends it, and the person sees the need as `waiting`.
- **A blind cast is re-cast before it lapses**, while the need is open; the two halves carry their own clocks.
- **The pulse says everything it did**, not only new arrivals.
- **The deploy guard reasons from a local wrangler login**, not from CI variable names, so a rename by Cloudflare cannot break the install button; a test proves it.
- Fixed a flaky signature test (`'x' + rest` was a no-op one run in sixty-four).

## v0.5.5-guard

- **`tribe_invite` has its own ceiling, 200 a day** — a loop-catcher that never touches a real seed.
- **The installer template refuses to be an update path.** `wrangler deploy` from a clone provisions a new empty mailbox and strands the old one; a build-command guard stops that and names `create-mazel`. Found the hard way on a live account.
- **The `/mcp` token works as an `Authorization: Bearer` header** as well as `?token=`; it always did, and now has a test.
- **"Load ALL of them, not a sample"** in the onboarding description.

## v0.5.4-rank

Found by the live test on a real portal, with six contacts read out of HubSpot and Calendar, plus the guard for a mistake made in this session. `find` returned the right two people; everything else here is what it got wrong on the way.

- **Rank by how much of the need someone answers, then by closeness.** It was the other way round, so the one person who matched both halves of the ask sat below three who matched one.
- **Weak tags count for less.** Each matched tag is weighted by how rare it is across the cards and contacts this portal holds: a tag nearly everyone shares adds almost nothing, a tag one person has carries the match. Local by construction — the relay has no contacts to count, so this never travels.
- **The headline leads with the people who fit.** Two people the person already knew fit the need, and the answer opened with "nothing fits" because neither had a portal. Someone who fits is the answer whether or not they are on Mazel yet.
- **`SUGGEST_MIN_EDGE`, default 50.** Contacts below the bar still match and still count; they are just not suggested as someone to go and write to. The answer says how many were held back, and `find(who_else: true)` brings them out. The same bar applies to a stranger's need reaching the person's contacts.
- **Every invitation is for something.** `invite_text` now requires the thread of a need that was actually cast, or the tribe someone is being invited into. Without that it is a mail merge.
- **A ceiling of 50 drafts a day, per portal.** Not a ration — the person decides who gets an invitation, and one yes can cover a batch. It is there to catch something calling `invite_text` in a cycle, and it says so when it trips. Redrafting words already drafted costs nothing. No tool takes a list of people.
- **`tribe_invite` has its own ceiling, 200 a day.** Seeding a tribe is one call per member document and a real one runs to hundreds, so the ceiling sits far above an afternoon of real work and only a cycle reaches it. Same approximate counter, its own bucket.
- **The installer template refuses to be an update path.** `wrangler deploy` from a clone provisions a new empty mailbox and binds your portal to it, leaving your card, contacts, mail and key in a namespace nothing points at. A build-command guard now stops that and names `create-mazel` instead; Deploy to Cloudflare runs in CI, where it passes. Found the hard way, on a live portal.
- **The `/mcp` token works as an `Authorization: Bearer` header** as well as `?token=`, so it can go under request headers instead of sitting in the URL. It always did; there is now a test saying so.
- **"Load ALL of them, not a sample."** The onboarding description told the agent to read the person's CRM and mail; it did not say to page through the whole thing. A portal holding twenty contacts finds nobody, and nobody can tell in advance which contact a need will want.
- Suite: ghosts 36 → 58, install 55 → 61, tribe 36 → 38.

## v0.5.3-tribe

A tribe works before anyone installs, and joining is built out of the same parts as everything else: a membership is an edge, an invitation is an intro, and the tier two members end up at is computed rather than chosen.

- **Entities and edges.** A registry on the portal: Organization by domain, Skill by slug, Tribe by organizer key plus slug; edges `works_at`, `knows`, `has_skill`, `sold_to`, `met_at`, `based_in`, `member_of`, each witnessed and tiered. An edge is never deleted, only ended with a date. The scorer reads them after the text match and re-ranks: a shared tribe counts for more than a matching word, two shared tribes for more than one, and a recorded employer, skill or city for something the text would miss. Entities live on the portal alone — the relay holds no code that can read one, and the whole suite greps every outbound body to prove nothing crosses.
- **Tribes.** `tribe_create`, `tribe_invite`, `tribe_join`, `tribe_leave`, `tribe_remove`, `tribe_status`. Flat by construction: a smaller group inside a larger one is another tribe with its own organizer, and overlap does the work.
- **The growth phase, organizer-first.** The organizer reads forty member documents into saved contacts and invites each one; forty people are members with nothing installed. Needs arrive the ordinary way, match across the tribe, and come back as words the organizer sends by hand. The first 🌀 happens with zero installs. When a member does install, their contact converts to a card and the membership comes with them.
- **The invitation is an intro and the yes is the join.** `origin: tribe`, the same unanimous-yes rule as any intro, the organizer as router on whatever comes of it. Accepting writes the membership before it answers, so the roster that comes back lands on a portal that is already a member.
- **A tribe wires itself together.** When someone joins, the organizer sends the new member the other members' handles and addresses, and sends each of them the new one. Signed by the organizer's key, accepted only for a tribe the receiving portal is actually in, and carrying handles and addresses only: what anyone needs or has is still theirs to say. Day one, a member's agent holds the tribe.
- **The tier is derived.** Sharing a live tribe puts a pair at tribe tier and recomputes on every membership change; a card someone added by hand keeps the tier they chose and is never lowered below it.
- **Leaving is silent.** Nobody approves it and nobody is told. The edge keeps its row with an end date, tiers fall back, past intros and outcomes stay exactly as they are, and anything this portal proposed on that tribe's behalf that is still unanswered is cancelled here and left to lapse, because there is no way to un-deliver a proposal. Removal by the organizer is the same, except the person's agent tells them once, since it is a crossing.
- **Visibility.** A membership carries a tier like any card field, default tribe; an unlisted tribe cannot hold a public membership. Said plainly: no card publishes memberships yet, so today fellow members see them either way. The setting is what will be published when a tribe gets its own card.
- **The organizer sees counts.** Members, how many have portals, needs cast, matches, 🌀. Never who needs what, never whose card is whose.
- **Write-back on every 🌀.** The tools that produce one tell the agent, in their own description, to log the crossing on the person's own record in whatever CRM it is connected to. The portal writes nothing itself.
- **Mutual edges.** `check_mutual` asks the other portal, through a signed pull, at what tier it holds this person; on a yes from each side the pair sits at tribe tier. Their answer stays theirs to give.
- **Words.** Everything a person reads says "someone you already know". "Ghost" survives only in tool names, where changing it would break portals already installed.
- **Found by the live test:** a saved contact now comes back with its id. Seeding is `note_ghost` then `tribe_invite`, once per member document, and without the id the agent had to list contacts in between — which on real KV waits about a minute, forty times over.
- **Also found live:** an invitation to a member matched on a need said "someone I know is looking for this" when it could say which group it came out of. It names the tribe now, and never an unlisted one.
- Suite: tribe 36, all twelve suites green.

## v0.5.2-sec

The second fresh-reviewer round, against `v0.5.1-ghosts`, scoped to ghost-set probing, bucket resolution, the blind-cast path and the `/a2a` caps gap. Fifteen findings; every high and medium fixed, each with a test. Security suite 52 → 68.

**Two claims we had written down turned out to be false, and both are now corrected rather than defended.**

- **The email bucket is gone.** Published as k-anonymous; measured against a twelve-address shortlist for one named person, exactly one survived — the right one. That is a membership test on a guessed address, and no salt fixes it because the salt has to be public to be usable. Nothing identifying an owner's address is published and no address hash is stored on a ghost. A contact resolves to a card only when a person says so: `link_ghost` with a handle or card URL the portal already holds, or the ghost takes their invitation and sends their card link. Automatic matching waits for private set intersection (§6.5).
- **The blind fingerprint does not keep a need secret from whoever holds the cast.** It is unkeyed and deterministic: four buckets out of 4096 confirm a guessed four-word need to about one in a trillion, and the same need fingerprints identically forever. So a blind cast now goes only to cards the person already holds at tribe or inner; `BLIND_TO_RELAY` (default off) opts into the relay. Blind casts expire in a day, not a week. §3.6 says all of this plainly.

**And the leaks the review found:**

- **Every tribe- and inner-tier have, with its gloss, was on the anonymous card** through the A2A `skills` array, which was built from raw `card.have` instead of the projection. One unauthenticated GET defeated the whole tier system. The seeding tests missed it because they only checked the HAAH params.
- **An unauthenticated `find.request` was scored against every tier**, so a stranger with a throwaway keypair extracted held haves one guessed tag at a time, answered to a URL of their choosing. It is scored against the public projection now.
- **Pulse push-configs were anyone's to read, list and delete**, and the record held a subscriber's bearer token and handed it back. Reads need the owner's token; the bearer is dropped on arrival and never stored or returned, in the Rust type too.
- **`peerFence` could be closed by the sender**, putting instructions outside the fence and next to a ghost's name in the same record. Markers are stripped before wrapping; prose is fenced and structured fields are narrowed to their own shape instead; a stranger's words and a ghost's name never share a string.
- **`/a2a` had no ceiling on how much arrives.** A hard mailbox cap checked against a listing, per-IP and per-sender daily counters, and a bounded newest-first page for the owner's read, which was one KV get per message.
- **Relay-delivered `find.hit`s had been dropped since Fly** — the relay signed `at`, the portal required `castAt` — so the subscribe fan-out was pure cost. Blind hits now get the replay check too.
- Pull signatures are bound to one portal and ten minutes; relay casts are capped per key per day; find-requests are capped per caller so one stranger cannot spend the day's budget; the memory file cannot be injected through a persona or a gloss; and a have with no witness is genuinely witness-free, a rule that had been unreachable because every save granted one.

## v0.5.1-ghosts

On day one the agent already holds the people the person knows, so the first cast has somewhere to land. MDP is the zero-question install plus this.

- **Ghosts.** A person known from a witness who has no card yet: display name, organization domain, inferred haves and role, an edge strength the agent computes, an email bucket, and the witnesses it was read from. Held at tribe, to the owner alone. `note_ghost`, `list_ghosts`, `forget_ghost`, and tool descriptions that tell the agent to build them from every witness it can read on the owner's own side.
- **Sealed, not filtered.** Ghosts are the one thing in a portal that is somebody else's data, so they are not known cards: never cast, never forwarded, never projected onto a card at any tier, never named to anyone but the owner. A suite assertion greps every outbound body in the whole run for ghost names.
- **A ghost match is an invitation, never an intro.** `find` and the pulse return `invites` separately from `candidates`; on a yes, `invite_text` produces words the person sends themselves. Nothing crosses a wire, because there is no portal on the other side.
- **Gossip reaches ghosts, and only the owner routes.** A stranger's `find.request` is scored against the ghosts on the portal it lands at. A hit never auto-answers: it becomes one mailbox question carrying the why and the edge strength, and the asker is told nothing until the owner says yes. No is silent. `route_ghost` gives the owner the invitation, or points at an ordinary intro if the ghost has since resolved to a card, with the owner as router.
- **Resolution through a bucket, opt-in and local.** A directory record may carry a three-character prefix of a hash of the owner's email, never the address. A ghost in the same bucket becomes a witnessed edge on the owner's portal only. No lookup service, no query anyone else can run. The honest limit is in §6.5 next to the one in §3.6.
- **The witness check.** `my_card` returns which sources the ghosts came from, how many each contributed, which haves nobody but the person vouches for, and asks the agent to name what it is connected to that is missing.
- **Projection by evidence.** The public card shows the best-attested haves — witness count, then recency — capped by `PUBLIC_HAVES_MAX` (config, default 6). The rest stay on the file.
- **Aging on what happens, not the calendar.** A need goes quiet after three passes in a row, or sixty days with nothing touching it at all; an accepted intro is a sign of life. A quiet need asks once when something finally fits, then stays quiet. A have with no witness activity slides a tier at twelve months and again at twenty-four; nothing is deleted.
- **Fixed:** `remove_need` and `add_need` for the same tag in one call lost the add. Removes now run before adds, for needs and haves both.
- Suite: ghosts 34.

## v0.5.0-seed

The card writes itself from what the agent already knows. Typing is the fallback.

- **The memory file is the source.** `memory:card.md` in KV, markdown, hand-editable, served owner-only at `GET /memory` and through `my_memory`. One line per field: tier in brackets, witnesses named, a malformed line preserved verbatim rather than dropped. The A2A card is a projection of it and never a source; an existing portal migrates its card into the file on first read; edits that bypass the file are overwritten by the next projection.
- **Five tiers on every field:** public, tribe, inner, matched-only, directed. An open `GET /card` can only ever be the public projection. A peer gets the richer one by **signing for it**: they sign `as` and an expiry with the key on their own card, the portal verifies against the known card it holds, and answers at the tier the person put them at. A stranger, a world-tier contact, or a bad signature gets nothing.
- **Witnesses.** Every have records what corroborates it. The person is one: an `owner` witness, the weakest kind, recorded when they confirm it. Owner-attested haves stay public and reach the relay for now; `RELAY_REQUIRES_WITNESS=1` (default off, flips in `v0.6.0-trust`) holds owner-only haves back from the relay while leaving them on the card for people who already hold it. A have with no witness at all stays inside the portal.
- **Silent needs.** A matched-only need never travels as words. It casts as buckets — short prefixes of token hashes — and the relay matches them against a subscriber's own have-fingerprint. A portal that lines up produces one private question in the owner's mailbox with a count and nothing else; `reveal_need` with an explicit yes is the only thing that ever says the words. The honest limits are written where the constants are: this defeats bulk harvesting and casual reading, not a targeted attacker with a dictionary. Real private set intersection later.
- **The onboarding script tells the agent where to look:** CRM, calendar, email, documents, and what it already remembers, recording the witnesses for each have and confirming before publishing anything.
- Suite: seed 22.

## v0.4.2-sec

An adversarial review by a reviewer with no context on the build, against the public repo at `v0.4.1-install`. Thirteen findings; every high and medium fixed, each with a test that failed before its fix. Security suite 20 -> 43.

- **A cast belongs to a key, not to a handle string.** It was keyed by handle and verified against a key the message carried, so one anonymous POST replaced the cached card of a handle it did not own.
- **A card from a cache never overwrites one the person added.** With the two together, a single request silently repointed every later message and intro for a trusted contact at the attacker.
- **The welcome page shows a setup key, not the mailbox key,** and the claim retires it and hands over the real connector link. It used to print the permanent credential to anonymous `GET /`, and claiming did not rotate it.
- **A directory name must be backed by a portal that serves the same record under the same key.** Names are ASCII and separator lookalikes fold onto one entry.
- **A find.hit is verified against a key the portal already trusted** — its own relay, a card it holds, or the card the hit points at — and its rank and why line are computed locally instead of read off the wire. It could previously name the relay it was checked against.
- **A subscription must be backed by the portal that holds the name,** is capped per key, keeps no push token, and one cast can no longer fan out without limit.
- **The door caps body and text size, stores only fields the protocol defines, verifies before it writes anything,** and caps what it will do for strangers in a day.
- **Only the side an intro went to may answer it,** and the answer is signed. A guessed intro id used to flip one to "connected".
- **Casts carry a signed `castAt`** and are refused once stale, so a captured cast is not a permanent bearer object.
- **Key continuity is enforced:** a new key for a handle needs a signed rotation chain. The code to walk one existed and was never called.
- **Stranger text is fenced as `<<peer>>` where the agent reads it,** and every tool that carries it says so.
- **The relay caps glosses and tags, bounds request bodies, and follows its list cursor** instead of stopping at the first page.
- **The installer's endpoint overrides are pinned to loopback.** They exist for the suite; unpinned, anything that could set one environment variable could redirect a live Cloudflare token.
- **A remembered card merges instead of clobbering,** and a card the world degraded climbs back out when the person adds it by hand. Found by the live peer suite while fixing the above: a need-cast carries no haves, so remembering someone from one blanked the card they already had and every later find missed them.

Not fixed, deliberately: signed links remain 30-minute bearer URLs (inherent to a link, bounded by expiry); the installer still ships no checksum for the Worker it uploads (§11.4 lock 1 wants signed releases, which is its own piece of work).

## v0.4.1-install

The install asks nothing. Everything personal happens in the first conversation.

- **`npx create-mazel` signs in with Cloudflare's OAuth flow** (PKCE, one browser round trip, the same public client `wrangler login` uses — the consent screen says Wrangler and the CLI says so before opening it). No API token to mint, nothing written to disk. `--token` stays, undocumented, for CI.
- **No questions at all.** No handle, persona, need, have or key prompts. A new portal deploys with no card; an update inherits every binding the portal already carries, so portals set up the old way keep theirs.
- **The claim.** A portal belongs to nobody until its first `update_card`. Until then `GET /` is a welcome page with the one link to paste, for 60 minutes; after that the page says how to get a fresh one. The moment the card is written, `/` is the public card page and the link is never shown again.
- **The first conversation.** `my_card` on an unclaimed portal returns the setup script instead of a card: ask one question (the handle), draft the persona and tags from what the agent already knows, show it in plain words, write it on a yes. The canonical card prompt (§3.3) travels inside the portal now. `update_card` takes a handle once, and lists of tags, so the whole card is one call.
- **Quiet by default.** The tool descriptions carry the rule: the agent speaks at three moments only — ✨ a hit with its why, 🌀 a yes, and once when a new need is about to travel to strangers.
- **One-click path.** [github.com/mazelai/portal](https://github.com/mazelai/portal) is public (MIT) with a Deploy to Cloudflare button; `wrangler.json` declares the mailbox and the pulse so both auto-provision. A portal that cannot be given a secret derives its key from its own signing key, and learns its own address from the first request so the scheduled pulse still runs. This reverses the git-deploy park (§11.4) for the no-shell path only.
- **Fixed on the way:** the installer could exit while piped output was unflushed (the last lines of a successful install vanished under `npx`); it printed the sign-in URL before its callback server was listening; and the callback connection kept the process alive after a successful sign-in.
- **Signed links, for connectors that cannot write.** ChatGPT gives individual plans read-only custom connectors, which would strand a GPT user at the claim. `claim_link` and `respond_intro_link` are genuine reads that return one link to the person's own portal; `GET` shows what the agent drafted, one button writes it. HMAC'd from the portal's signing key, payload inline, 30-minute expiry, never shows the mailbox key. A link from another portal, a tampered draft and an aged-out link are all refused. Proven live: a real intro answered through the link, both sides `connected`. (The npm package went to 0.4.2 for this: 0.4.1 was published earlier in the batch and its bundled Worker predates the links.)
- Suites: install 50, cli 15 (the whole shell path against a fake Cloudflare, PKCE and all).

## v0.4.0-fly

_Post-tag fixes (2026-09-27):_ relay stores handle records verbatim (rewriting the handle broke the signature); unit suites never touch the network; three-account rule (Appendix B); test peer moved to its own account (`mazel.mazel-testpeer.workers.dev`); `carriers`/pulse warn when the relay shares the portal's account (1042); card reports 0.4.0.
 — 2026-09-27

**A need you cast now reaches strangers.** Three carriers, all on: the cards you hold, the Mazel relay, and one-hop gossip through people you know. Nobody owns the network; the relay is a cache that can be deleted without losing anything any portal holds.

### How to update (one command)

```
npx create-mazel
```

Your card, mailbox, key and connector survive. The update also sets your portal's **pulse** (a check every 30 minutes) and points it at the relay. Everyone you trade cards with should update: a v0.3 portal cannot answer gossip or read a hit.

### What to try

- **Cast something real.** "mazel me a sailing coach in Lisbon." Your portal searches your cards, casts the need to the relay, and asks the people you know to pass it on once. Strangers who fit come back marked 🌍. Pick one; the intro goes portal to portal as before.
- **Give your handle out instead of a link.** "add gary@mazel to my mazel" resolves the name through the directory; any domain can be a directory by serving `/.well-known/mazel/name.json`.
- **Lose nothing on a key rotation.** "rotate my mazel key" makes a new key with a signed hand-off record; your threads, intros and cards are untouched and everyone follows.
- **Ask how you reach the world.** "how does my mazel reach strangers" lists the carriers.

### New this release

- Identity: every portal has an Ed25519 key. Cards, casts and hits are signed; tampered records are refused.
- Relay (`relay/`): `POST /cast`, `GET /search`, `POST /subscribe`, the `name@mazel` directory. Signature is the only auth; TTL on every record.
- Gossip: `find.request` forwarded at most twice, deduped by need id, origin signature intact; answers arrive as `find.hit` with the path they came through.
- Pulse: cron every 30 minutes plus a manual `pulse` tool; one badge line when something lands, silence otherwise.
- World tier: strangers land as 🌍 cards; the intro flow is unchanged.
- Nostr: a fourth carrier as a flag only, no implementation yet.

### Known limits

- Gossip needs a mutual acquaintance; with two portals only the relay can find you.
- One hop of gossip (two forwards). Multi-hop routing with a hop budget is the next stage.

## v0.3.0-a2a — 2026-09-27

**Your portal now speaks the official A2A protocol, v1.0.** Any A2A agent can read your card and knock on your door; Mazel's own fields ride in one declared extension. Nothing you do day to day changes.

### How to update (one command)

```
npx create-mazel
```

This one is not optional: v0.3.0 is a clean break on the wire. A portal on v0.2 cannot talk to a portal on v0.3, and the update tells the other side so in plain words. Everyone you trade cards with should update too. Your card, mailbox, key and connector all survive.

### What changed underneath

- Your card is a standard A2A v1.0 Agent Card at `/.well-known/agent-card.json` (`/card` still works). Handle, need, have and glosses live in the HAAH extension (`https://mazel.ai/ext/haah/v1`, not required); your door is `supportedInterfaces[0]`.
- Messages use the A2A `SendMessage` method with `{text}` parts and carry the HAAH extension URI. The Mazel action (`note`, `find.request`, `intro.propose`, `intro.respond`) is unchanged, in message metadata.
- Pulse subscriptions: other agents can register an A2A push-notification config on your portal. Registered only; nothing is delivered yet.
- Streaming is stubbed behind a flag, off by default.
- Function words ("has", "not", "own"…) no longer count toward a match.
- Conformance is tested in CI with the official A2A JavaScript client and round-tripped through the Rust core.

### Known limits

- Same as v0.2: you can only find people whose card you hold; one hop. That is the next release.

## v0.2.0-friends — 2026-09-22

**Your mazel can find people now.** Until this release a portal could receive and reply. Now it can search the cards you hold, propose an intro with the reason it matched, and keep track of what came of it.

### How to update (one command)

```
npx create-mazel
```

Run it on the portal you already have. It redeploys the new code and keeps everything: your card, your mailbox, your key, your connector. Nothing to re-paste, no dashboard. (First time on a machine, it asks for a Cloudflare API token; the installer tells you exactly where to get one.)

If you would rather not use a terminal, the dashboard path still works: your AI has it as the fallback at the end of MAZEL.md.

### Then do this

**Send your card link to whoever invited you** (`https://mazel.YOURNAME.workers.dev/card`) and ask for theirs, which ends in `/card`. Nobody can find you until someone holds your card, and you cannot find them until you hold theirs. Say to your AI: "add this to my mazel" and paste the link.

### What to try

- **"mazel me someone who's crossed the Atlantic by sailboat."** Your AI turns the sentence into tags, your portal searches the cards you hold and ranks up to five, each with one line saying why it matched. If nothing fits it says so and shows the closest partial.
- **Pick one.** Your AI proposes the intro to that person's portal, carrying the why and the path (who it came through). It asks you before sending.
- **Answer one.** When an intro arrives for you, your AI shows who, why, and the path; you say yes or pass; the answer travels back and both sides record it.
- **"add to my mazel: I'm looking for X."** Your card changes as you talk, no redeploy. Add a one-line description to any tag ("gloss") so other people's agents can match it properly.
- **"who's in my mazel?"** Lists the cards you hold. "Drop X" forgets one.

### New this release

- Known cards: hold other people's cards and search them. Each carries a trust tier (inner, tribe, world) for later routing; it defaults and you are never asked.
- Find: deterministic matching on tags, their glosses, and the persona. Fit bar, ranked, capped at five, one line of why each.
- Threads: each need you cast is a thread for 30 days. Casting the same need again reuses it; closed or expired ones reopen when you cast again.
- Intros: proposed, accepted, declined travel on the wire. What became of an intro is recorded, never inferred, and nobody is rated.
- Typed messages: every message carries an action type (`note`, `find.request`, `intro.propose`, `intro.respond`) and a version, so new kinds slot in without breaking old portals.
- One-command install and update (`npx create-mazel`).
- Your AI now uses "mazel" as the word that routes to these tools, so "check my mailbox" never reaches your Mazel portal by accident.

### Fixed

- Delivery is confirmed, never assumed: a message counts as sent only when the other door answers properly. A failed reply keeps the message until a retry succeeds, and retries never duplicate.
- Your portal's home page never shows your key. (If you set your portal up before this, rotate the key: your AI has the steps.)
- Someone who moves their portal updates in place instead of appearing twice in your results.
- Portals behind a proxy now publish the right address for their door.
- An intro that was already answered cannot be re-proposed over the top of its outcome.
- Incoming messages are treated as untrusted content: your AI reads them as data, never as instructions.

### Known limits

- You can only find people whose card you hold. There is no directory and no lookup by handle yet; that is the next stage.
- One hop: your AI searches your cards, not your friends' cards.
- Your AI checks your mailbox on a schedule (hourly by default), so an answer can take a little while.
