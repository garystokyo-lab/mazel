# v0.5.10-seed2: the procedure, so a stranger's agent can seed a portal unaided

Plan only. Nothing here is built. Spec §8.3b; the storage parts (items 1, 2, 3 and 6) shipped in
`v0.5.9-live`, and this version is the procedure that drives them.

The done condition is the whole design brief: **a fresh account on Claude and one on ChatGPT, no
code and no helper agents, each seed 100 or more people from real connectors within the first three
sessions.** Everything below exists to make that true for someone who is not Ariel and will not
read instructions.

## What is already true after v0.5.9-live

- An agent can send up to 50 people in one call and gets a refusal with the allowed count over that.
- An agent reports counts; the portal computes the edge and the heat. The counts are stored beside
  the score, so a retune needs no re-read of anyone's mail.
- A repeat pass finds the same person through a keyed hash of their main address, so the procedure
  can be interrupted and resumed without making duplicates. **This is the one thing that makes
  slicing safe**, and it is the reason the storage parts went first.
- The install script and both install pages tell the agent to seed, to send counts rather than
  message text, and to ask for the LinkedIn export on day one.

So the portal can already be filled. What it cannot do is **tell an agent what to read next**, and
that is the whole of this version.

## 1. A cursor per source, and one slice at a time

The portal keeps a cursor per source (`calendar`, `sent`, `crm`, `zip`) and answers the question
"what should I read next" with exactly one slice: one source, one month. A slice has to fit one chat
on a free plan, which is the binding constraint, not the portal's.

- New tool action, `contacts next` (no new listed tool: it joins the merged `contacts` tool, so the
  tool count does not move). It returns one instruction in plain words: the source, the window, and
  what to count. It does not return data and it reads nothing itself.
- `contacts note` advances the cursor for that source when the batch it carries names the slice it
  came from. Progress is saved per batch, so a session that dies loses at most fifty people.
- No schedule and no cron. The agent asks, reads, writes, asks again. A pulse never seeds.
- The first session's target is fixed: **the last 60 days of calendar and sent mail**, which is small,
  immediate, and enough for a first ✨.

## 2. Order by token cost, which is the user's money

§8.3b is explicit and the order is not negotiable:

| order | source | who pays | why it is in this position |
|---|---|---|---|
| a | 60 days of connectors | the user's own plan, per read | small and immediate, gets to a first ✨ |
| b | the LinkedIn zip | nobody, the portal reads it | the bulk, at zero tokens, which is why it is requested on day one |
| c | connector slices, deeper | the user's plan | only for people the zip or a match made relevant |

The agent does only what needs connector access or judgment. All counting, scoring and merging
happens in the portal. An agent that starts summarising mail is doing the wrong job and costing the
user money for it.

## 3. The upload path

The zip and a contacts file arrive through a signed upload link, the same shape as the reply link a
contact with no portal uses: one link, short-lived, scoped to one upload. The portal streams it,
counts, and keeps **nothing raw**. No file is persisted, no message text, no addresses: only the
contact records and the keyed hashes. This is the one part of this version that is not just a
procedure, and it is why the upload page was scoped beside the extractor interface in §12.3.

With neither a connector nor a file, the agent says seeding is empty and names the one connector that
would change that. The no-silent-first-session gate (§10.2b) then leans on the network's own contacts
for that user.

## 4. Title and company up front, detail at match time

Up front from mail signatures and the zip. A deeper lookup happens only when a need actually lands on
that person, on the open web and never on LinkedIn pages, with every fact saved beside its source,
which is lock 12. This keeps the seeding pass cheap and puts the expensive work where it pays.

## 5. The done condition, as a test rather than a hope

Two live runs, one on a fresh Claude account and one on a fresh ChatGPT account, each with the
connectors a normal person has, no scripts and no helper agents. Each must pass 100 contacts inside
three sessions. What the suite can check without a live account:

- a cursor advances, and only for the source the batch names;
- a slice is refused when its source has no cursor, rather than silently restarting from the top;
- a session interrupted mid-source resumes at the same place and makes no duplicates;
- the same person arriving from calendar and then from the zip stays one record, by key then by
  name and organization;
- the order is a, b, c: a portal with no zip yet is told to ask for it, not to read deeper slices;
- nothing raw survives an upload, asserted over the whole store after a zip has been read.

## Do items 1 to 4 of v0.5.9-live make this harder?

No, and three of them are load-bearing for it.

- **Evidence in, scores out** is what makes slicing possible at all. A slice carries counts for one
  month; counts add up and a score does not. If the agent had kept scoring, two slices of the same
  person would have fought, and the only fix would have been to re-read everything in one session,
  which is the thing that cannot be done on a free plan.
- **The keyed hash** is what makes a repeat pass safe. Without it, slicing would have produced a
  duplicate per slice per person, and 137 contacts would have become several hundred.
- **The batch of fifty** sets the slice size from below. A slice must not produce more than fifty
  people, so "one source, one month" has to be checked against a month that is busier than Ariel's.
  If a month overflows, the slice narrows to a fortnight rather than the call being refused. **This
  is the one piece of friction the earlier items introduce**, and it is a slice-sizing rule, not a
  rewrite.
- **The contact rules** (rest, back-off, never-ask) and the **matching bar** do not touch seeding.
  They sit between a match and a question, which is after everything here. One interaction worth
  naming: a seeding pass that adds 400 contacts at once raises the common-word share for every word,
  which makes the bar stricter on its own as a portal gets fuller. That is the intended direction.
- **Heat** is a per-source read, so it slices the same way the counts do. `cooled` stays the owner's
  and no slice may set it.

## One §8.3b item deliberately left out of v0.5.9-live

**Item 7, tiers of evidence:** a direct exchange is saved, and a person with no direct exchange waits
for a second source. It was not applied in `v0.5.9-live`, and the reason is about where the evidence
currently lives rather than about who the contacts are.

Ariel's portal on 2026-10-06, read live:

| | |
|---|---|
| contacts | 137 |
| witnessed by calendar / gmail / hubspot | 126 / 124 / 127 |
| witnessed by linkedin | 0 |
| carrying an `edge_signals` line | 136 |
| with at least one meeting, reply or deal in that line | 127 |
| with structured `facts` stored | 0 |

Every one of those contacts came from calendar, Gmail and HubSpot in a single pass on 2026-10-05, and
the evidence of a direct exchange is there: "14 meetings (14 small); 9 threads to them, 6 with a
reply". It is **text**, because the structured fields did not exist until `v0.5.9-live` shipped them
an hour ago.

So a rule that asked "does this contact have a direct exchange?" of the structured fields today would
answer no for all 137 and take the entire portal out of matching, while the evidence sits in plain
sight one field away. **An empty structured field is not an absence of exchange, and must never be
read as one.** That is the rule for whoever implements item 7, in this version or any other.

The sequence that makes it safe: deploy, then Claude re-saves the 137 through the batch call with
`meetings`, `small_meetings`, `threads_sent`, `threads_replied`, `deals`, `best_stage` and the dates
filled in, which is one pass over data the portal already holds. Item 7 can be applied after that,
when a missing count means missing and not merely unmigrated. Until then it waits, and a contact with
no structured facts is treated as unknown rather than as unexchanged.
