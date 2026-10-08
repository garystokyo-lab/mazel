# v0.5.9-live — scope only. Build waits.

**Decision (Ariel, 2026-10-03, settled 2026-10-04):** Mazel is a messenger first. The portal's state
moves into a **Durable Object with the SQLite storage backend**, one per portal, holding everything
the owner touches: mailbox, threads, outbox, counters, known cards, memory file, keys. **KV keeps one
record** — a published copy of the public card, rewritten whenever the card changes. Mazel never
hosts portals; the object runs on the owner's own account, and because the SQLite-backed kind runs on
**Workers Free**, the install promise is unchanged: a free Cloudflare account is enough. The two-tier
plan and the upgrade button are cancelled.

**Build waits until Gary and Dylan have installed on the KV version** (`v0.5.8.1`). Their portals are
part of the migration this batch has to handle.

Written against `v0.5.8.1`: portal 5,275 lines, 177 references to the KV binding, 27 key prefixes.
Numbers marked *est.* are my estimate, not a measurement.

Platform facts this rests on, from Cloudflare's own docs:
[pricing](https://developers.cloudflare.com/durable-objects/platform/pricing/) and
[limits](https://developers.cloudflare.com/durable-objects/platform/limits/) —
SQLite-backed objects on Workers Free: **100,000 rows written a day** (KV's limit is 1,000 writes),
5M rows read, 100,000 requests, 5 GB per account and 1 GB per object; **2 MB** for a key and value
together, against the KV-backed object's 128 KiB.

---

## 1. The shape

```
            stranger's fetch                         owner's agent, peers' messages
                   |                                              |
                   v                                              v
        KV: card:public  (one key)                    Durable Object "portal"
        the A2A AgentCard and the signed              SQLite storage, one per portal
        handle record, as published                   everything the owner touches
                   ^                                              |
                   |______________ republished on card change ____|
```

**Everything in the object:** `msg:` the mailbox · `conv:` `convm:` threads and messages · `thread:`
`branchof:` `needsig:` needs and their indexes · `intro:` · `outbox:` · `cap:` `refused:` counters ·
`seen:` `seen:t:` `seen-need:` dedupe · `bell:` the doorbell · `blocked:` `trust:` · `blind:` `hit:` ·
`queue:` · `session:` `push:` the `/inbox` side · `tlink:` `deleted:` · `known:` the cards this portal
holds · `outcome:` the ledger · `ghost:` `ghostask:` saved contacts · `edge:` `entity:` tribes ·
`config:` the card, the memory file, the signing key, the inbox token, the remembered origin.

**In KV, one key.** The published record: the public-tier AgentCard exactly as `/card` and
`/.well-known/agent-card.json` serve it, plus — and this is a recommendation, not something your
decision settled — **the signed handle record** that `/.well-known/mazel/<name>.json` serves. Both are
public, both are signed, and both are fetched by strangers constantly: every gate check anywhere in
the network reads one of them. If the handle record is not published alongside the card, every handle
resolution in the world wakes this object. Publishing both costs one extra field in one key.

**Why this split and not a purer one.** A portal's public face is read far more often than it is
written, by people who have no business waking the object: the gate makes every portal fetch a card
before it will believe anything. Those reads are the one thing that genuinely wants KV's edge cache.
Everything else — every read the owner or a correspondent makes — wants to be exact, and that is the
object.

**Naming the object.** `idFromName("portal")`, one per Worker, **not** the handle: a portal is
deployed before it is claimed, and a handle can be set after the first request. Naming it by handle
would strand the state of any portal that was ever touched before being claimed.

---

## 2. What this buys

- **Ordered threads.** `seq` is assigned inside the object, single-threaded. Today two messages
  arriving in the same moment can both read `seq: 7`, and the loser is overwritten.
- **Instant delivery.** `/inbox` holds a socket open to the object and is told, instead of polling.
  The doorbell stays for a phone that is not looking.
- **The read lag is gone, entirely.** §12.4's "KV read lag drives 60-second waits in tests" ends: the
  object is read-after-write consistent. With `known:` inside it, the last survivor goes too —
  `cards add` loses "may take about a minute to become searchable", and a `find` straight after
  adding a card sees it.
- **Counters stop being hot keys.** `cap:a2a:ip:<address>` is one KV key written on every message,
  which meets KV's one-write-per-second-per-key rule under any burst. In the object it is a row, and
  the serialization is the object's own.
- **The mailbox ceiling stops being a list.** Today every inbound message lists every message to
  count them. In the object it is a count.
- **Headroom.** The burn that caused this was 912 writes a day against 1,000. The same portal in the
  object has 100,000 rows a day, and `v0.5.8.1` already took the timer writes to zero.

---

## 3. Migration, with no data loss

Three portals exist that matter — Ariel's (~140 keys), the test peer (~700), and whatever Gary and
Dylan install on `v0.5.8.1` before this ships — plus anyone else by then.

1. **Nothing is deleted while it runs.** The object copies; KV keys stay. A later version deletes
   them, leaving the one published record, after the object has been serving for a grace period.
2. **Resumable and idempotent.** The object keeps a cursor and a per-prefix done-flag in its own
   storage. A request that runs out of CPU resumes on the next one; running it twice changes nothing;
   the copier never overwrites a key the object already holds.
3. **Reads fall back while it runs.** A prefix not yet marked done is read from KV; writes go to the
   object from the first moment. The portal answers normally throughout.
4. **Order:** `config:` first (the card and the key, so the portal can sign), then `conv:`/`convm:`
   (the messenger), then `msg:`, then the rest. A half-migrated portal can still read its threads.
5. **Then it publishes** the KV record from the card now in the object, and from then on republishes
   on every card change.
6. **It says what it did**, once, in the pulse line: how many threads, messages, intros and cards
   came across, and that the KV copies are still there.
7. **Rollback is a flag.** Clear it and the portal reads KV again, for as long as the copies live.
8. **The risk worth naming:** a portal near `MAX_MAILBOX` (400) with large messages, copied under a
   request's CPU limit. That is why it is resumable rather than one pass, and why the test peer —
   the biggest, at ~700 keys — migrates first.

---

## 4. Install, welcome, relay, peer

- **The install promise is unchanged.** A free Cloudflare account is enough. No plan check, no price,
  no upgrade button. `site/install.html` and `site/install-squarespace.html` change only by a line
  about where a conversation lives.
- **The wrangler config** gains a Durable Object binding and a migration tag, and the tag must say
  **`new_sqlite_classes`**. That one word is the difference between a portal that installs on a free
  account and one that does not; `install-test` should fail if the template ever says `new_classes`.
  The one-click Deploy-to-Cloudflare template needs the same.
- **An existing portal is never bricked.** If the binding is absent the portal runs on KV exactly as
  today and says so once in the pulse.
- **A portal whose object is unreachable still serves its public face** from the published KV record:
  a stranger fetching the card never fails, even when the portal can take no mail. Worth keeping.
- **The relay: nothing.** It holds casts and the directory, it is asked rather than asking, it pushes
  nothing, and it stays on KV on the company account.
- **The test peer takes the same upgrade and stays on Workers Free permanently** (rule 2), which the
  SQLite backend allows. It is the canary: at ~300 messages a day it uses about 1% of the free
  object's write budget, so a regression that multiplies writes shows up there long before it reaches
  anyone. Downgrade mazel@mazel.ai to Free when the paid cycle ends.

---

## 5. Effect on the suites

- Every suite builds a portal with `mkKV()`. They need **one shared `test/do-stub.mjs`** with the
  object's storage shape — mechanical, but it touches all 17 files.
- `kv-budget-test` becomes **`storage-budget-test`** and keeps lock 13: a quiet pulse still writes
  zero, the budgets are restated in rows rather than KV writes, and one new check asserts the hot-key
  problem is gone — the counters are no longer a key written on every message.
- The waits that exist only for KV lag come out (`thread-test`, `crawl-test`, `moved-test`), and a new
  check asserts the opposite: a card added is findable in the same breath.
- `a2a-conformance` is untouched; no wire shape changes.
- `install-test` grows the binding, the `new_sqlite_classes` tag, and the published-record path.
- **New: `migrate-test`** (est. 25 checks) — every moving prefix populated, migrated, every assertion
  from the other suites still true; resumable mid-way; idempotent; readable while it runs; rollback;
  and the published record correct afterwards.
- **New: `published-card-test`** (est. 8) — the KV record matches what the object holds, is rewritten
  on a card change, is what `/card` and `/.well-known/` serve, and a tiered pull (`/card?as=`) goes to
  the object instead, since the published copy is public-tier only.
- est. of ~740 checks today: **45 rewritten, 70 new**, none lost.

---

## 6. Estimated size

| Piece | est. lines |
|---|---|
| The object: fetch router, alarms, SQLite storage helpers | +280 |
| Migration: copier, cursor, fallback reads, rollback | +180 |
| A `store(env)` facade so the 177 call sites change shape, not logic | +80 / ~177 touched |
| The published KV record: writer, republish-on-change, the public read paths | +70 |
| Pulse work moving to object alarms | ~60 changed |
| `/inbox` live socket | +90 |
| Installer: binding and the `new_sqlite_classes` tag | +60 |
| Test stub, `migrate-test`, `published-card-test` | +320 |
| Install pages, welcome page, README, §12.4 | ~60 changed |
| **Total** | **est. +1,080 / −200, with ~300 lines touched in place** |

Three batches, each green before the next:

1. **The facade and the object** — everything behind `store(env)`, threads and the mailbox living in
   the object, the published record written. No migration yet; new portals only.
2. **The migration** — the test peer first, Ariel's portal second, then Gary's and Dylan's, each with
   the KV copies left in place.
3. **Instant delivery** — the `/inbox` socket, alarms replacing most of the pulse, and the deletion of
   the KV copies once the grace period has passed.

---

## 7. Open, and not blocking the build

- **The signed handle record in the published key** (§1). My recommendation; it stops every handle
  resolution in the network from waking the object. Say no and it reads from the object instead.
- **How long the grace period is** before batch 3 deletes the KV copies. A week of the object serving
  without a fallback read is enough to know.
- **Whether the cron survives at all.** Alarms cover the sweeps; something still has to cast to the
  relay and republish the directory record, which are outbound HTTP rather than state. A much smaller
  cron, kept.
