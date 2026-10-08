# MAZEL-SPEC.md
**This is a personal project for Ariel Jalali.**
**Owner:** Ariel Jalali. **Kept by:** Claude (PM). **Rebalanced:** 2026-09-27, from the 2026-09-14 comprehensive spec and every decision through 2026-09-27.
**Authority:** the copy in the repo (`~/mazel-work/MAZEL-SPEC.md`) is the single source. The project doc and Ariel's downloads are copies.
**How to read:** sections 1 through 12 are current truth. Appendix A is the use-case list (WIP). Appendix B is assets and accounts. Appendix C is history: superseded plans, names, and contracts, kept so nothing is lost and nothing is mistaken for current.
**Rules for this document:** every decision carries a date and an owner. Parked items live in §12.5 only. New ideas are checked against §2, §10, §11, and §12.5 before they go in, and the section they touch is named.

---

## 1. Thesis and pitch

**Mazel is an opportunity engine.** It finds you the people that opportunities come through. Connection is the mechanism; opportunity is the point; a rapidly changing world is the why. When the ground moves monthly, a static network (LinkedIn, an old Rolodex) loses value and live opportunity-finding gains it. Mazel turns needs and haves into live signals that travel and collide, refreshing constantly, instead of a stale directory of who knows whom. (2026-09-18)

**Your AI is the interface. Mazel is what finds people through it.** Mazel has no interface of its own worth building. You talk to the AI you already use; inside that conversation, Mazel notices what you need and who you know, and a person shows up with the reason they fit and the path they came through. Nobody "uses Mazel." The lab wins the interface; Mazel owns the layer underneath, a fight the labs are not in.

**The Waze principle.** Cars already driving were the sensors; the driving was the report. People are already talking to their AI all day; that conversation is the road. Needs, haves, who you mention, who you meet, all arrive as byproduct. The card is a readout of what the agent observed, never a form. Trust is noticed from costly acts, never imported. Needs are overheard, not cast. One rule Waze never needed, because conversations are private where roads are public: **the sensor listens locally, and only what you would want found leaves, with your say-so.**

**The pitch line (Ariel, 2026-09-27).** Your AI knows everything about you and it's telling no one. Everything you've connected to it sits in one agent, useful only to you. Mazel is how that knowledge finds the people who have what you need, without any of it leaving your agent.

**Sovereignty, standing.** Mazel is a tool for AI sovereignty. You own your brain and context outside any lab, and you own your handle, your graph, and your ability to reach people. A lab AI is a brain you use, never the landlord of who you can reach. Agents are the path. Humans are the destination.

**Targets.** Long term: replace LinkedIn and human trust networks as the way people find opportunity. Near term: the first tribe live, ten 🌀 (§9, §12).

---

## 2. Vocabulary

One spoken vocabulary everywhere, internal docs included. Superseded names live only in Appendix C. Machine identifiers humans never see (KV bindings, code ids) are a separate, harmless layer.

| Term | Meaning |
|---|---|
| Mazel (verb) | "Mazel me a CTO." Also the **magic word**: the sole spoken trigger that routes a need to the network, said on purpose, and it is the user's consent. Ambient sensing may later notice and suggest; nothing casts until the person says the word. |
| Agent | The **harness** that acts for a person: holds tools, picks models per job, manages memory and permissions. Model-agnostic. What Mazel integrates with, through its tool interface. |
| Model | A component the harness uses, LLM or otherwise. Mazel never addresses a model directly. |
| Portal | A person's always-on endpoint plus mailbox, on their own account. Where other agents reach yours. Today a Cloudflare Worker; never defined by it. |
| Card | The person, as far as the agent world is concerned (§3). Public projection of the memory file, served on A2A. |
| Memory file | The card's inside: markdown on the portal, owner-readable, holding personas, needs, haves, each with a tier and its witnesses. Source of truth; the card is derived. |
| Handle | `name@domain`, a label pointing at a key (§6.4). `name@mazel` is shorthand for `name@mazel.ai`. |
| Key | Ed25519 signing key per portal. The identity. Handles and hosts can change; the key and its threads survive. |
| Need / Have | What a person is looking for from someone; what someone would be glad to reach them for. Each carries a tier and, for haves, witnesses. |
| Tier | Visibility of a field or the trust on a contact: **public, tribe, inner, matched-only, directed** (§3.2). |
| Inner / tribe / world | The three trust tiers on every known contact (§5.1). Mental model, never product words: jacuzzi, pool, ocean. |
| Witness | Any connector the person has given their agent (calendar, email, CRM, documents, chat memory). Witnesses corroborate haves, make ghosts real, and set edge strength. Reach follows witnesses. |
| Ghost | A person the agent knows about from a witness who has no card yet, held on the owner's portal at tribe tier to the owner only. Internal word only (Ariel, 2026-09-27): product copy and the agent say "someone you already know" or "your contacts," never ghost. |
| Witnessed edge | A connector shows the owner knows someone who has a card. Written into the owner's local routing table; never published. |
| Known cards | The cards a person holds, with a tier each. Their slice of the graph, and their alpha. |
| Cast | A need leaving the portal to look for a have. |
| Match | A collision: a need and a have fit. Fires an intro proposal. |
| Intro | The proposal: "these two should meet," with the mutual why and the path. Carries `origin: cast | collision | tribe`. States: proposed, connected, declined. |
| Connect | Every named human said yes; a thread opens with the intro note as message one (§4.3b). The install step is "Add Mazel," never "connect Mazel." |
| Thread | One need and everything it sets off (Ariel, 2026-09-28). The need is message one; each candidate gets a private branch (its own A2A `contextId`) where the agents talk first and the humans join on 🌀. Stored only on the participants' portals (§4.3b). User copy says "conversation" or "message." |
| The box | The owner's Mazel inbox: every new branch, candidate, reply, and 🌀 lands here as a message. The variable reward (§4.3c). |
| Outcome | What happened after an intro, as a behavioral state (met, met-continued, met-referred, went-quiet, declined), never a rating. |
| Vouch | One person staking reputation on another. A vouch that leads to a bad outcome lowers the voucher's weight. |
| Pulse | The portal's periodic check-in: a Cron Trigger every 30 minutes, one cast per open need, one score pass, one badge line, quiet when nothing hits. Never "heartbeat" (that names OpenClaw's agent-side file). |
| Relay | A Mazel-run cache of signed public casts and cards. Deleting it loses nothing any portal holds. |
| Directory | Handle resolution via signed records at `/.well-known/mazel/name.json` on any domain; mazel.ai's is a cache. |
| Room | Retired word; the thread (above) is the room, realized on A2A (2026-09-28). |
| Pass | An agent-level polite no, carried as a normal reply. |
| Intro note | The context that travels on connect (schema §4.5). "Warm note" is the short text inside it. |
| The mutual why | Both sides of a match shown: found someone you need; someone needed what you have. |
| Mailbox | The portal's inbox for agent messages and thread messages; `/inbox` is also the owner's phone-friendly page for reading and replying. **Email** is the person's own inbox, read by their agent. |
| Doorbell | A contentless notification to the human that something arrived ("New message from Sarah"), linking back to the thread. |
| Wings 🪽 | The badge mark. On a message line: closeness (parties minus one). On the owner's own portal: level (§5.3). |
| ✨ / 🌀 / 📬 📭 | The magic worked; a crossing; mailbox flag up or down (§8). |
| HAAH | Human, Agent, Agent, Human. The pull shape, and the name of Mazel's A2A extension. |
| A2A | The open agent-to-agent protocol (Linux Foundation, v1.0). Mazel's wire. |
| Opportunity | The unit of value: a match that could change something for someone. Measure the product in opportunities surfaced and taken. |
| Tribe (noun) | A bounded group that already trusts each other, seeded by an organizer (§9.2). Also a trust tier. |

---

## 3. The card

### 3.1 What a card is (2026-09-27, decided)
A LinkedIn profile is a document about a person. A Mazel card is the person, as far as the agent world is concerned:
- **Signed.** It is someone. The portal's key signs it.
- **Tiered.** A different face for a stranger, a peer, a friend, from one memory file.
- **Living.** It says what the person needs this week and drops it when handled.
- **Corroborated.** Haves carry witnesses, and reach follows witnesses.
- **Answerable.** Another agent can ask it something and get a yes or no from a human.
Everything else in the protocol exists to move cards toward each other: relay, directory, pulse, intro. First line of the protocol page: a card is a person you can ask. This is the one-way door guarded hardest.

### 3.2 Memory file, tiers, projection (2026-09-26 parked, 2026-09-27 decided, ships `v0.5.0-seed`)
The memory file (`memory:card.md` in KV, served owner-only at `GET /memory`) is markdown, hand-editable: one line per field, tier in brackets, witnesses named. A malformed line is preserved verbatim and reported, never dropped. The A2A card (`config:card`) is a projection built from it; the first read of an existing portal migrates its card into the file; edits that bypass the file are overwritten by the next projection (one-way).

Five tiers, one list, applying to every field (needs, haves, persona, history):
- **public**: on `/card`, anyone can read. Broad, evergreen, no signal risk.
- **tribe**: served to known cards at tribe or inner, through a signed pull (the peer signs a request with the key on their card; the portal verifies against the known card it holds and answers at that peer's tier).
- **inner**: served to inner only, same mechanism.
- **matched-only**: held on the portal, travels only as a fingerprint (§3.6), released as text only after both humans say yes. The sensitive ask that leaks by its nature (a hire, an expansion, a client).
- **directed**: one recipient, named by the owner. No discovery.
Needs travel at any tier. Witnesses on a have (§8.2) include `owner`, the weakest kind: the person confirmed it themselves. Decision 2026-09-27 (Ariel, lenient early): owner-attested haves stay public and reach the relay while thresholds are permissive; a config flag `RELAY_REQUIRES_WITNESS` (default off) excludes owner-only haves from the relay when on, and flips in `v0.6.0-trust` from what the first tribe shows. Agent-inferred haves with no witness are inner and tribe only. Public haves are capped at six (`MAX_TAGS`), matching the card prompt; the owner picks; the rest stay on the file.

### 3.3 Card authoring is a conversation (2026-09-14, Ariel; 2026-09-27 rule)
A person never hand-types their need and have into a field. Typing is the fallback, never the primary path. Three standing ways:
- **Spoken cast:** "put out that I'm looking for X"; the agent writes it.
- **Proposed from context:** the agent drafts from what it knows and its witnesses (§7.3) and offers a yes or an edit.
- **Kept current:** the living card (§3.4).
Leak guard: the draft checks what each tag reveals, not only whether it is secret; prefer the general skill over the specific vendor, client, or platform unless the person says the association is public. Human review before publish catches the rest. Confirm-before-public on every write to a public field.

Canonical card-drafting prompt (2026-09-14; lives in the onboarding tool description):

> Draft my Mazel Agent Card, the Need and Have that go on it.
>
> What these are: a Have is something another person would be genuinely glad to reach me for, a capability, access, knowledge, or resource, not my title but the useful thing behind it. A Need is something I'm looking for from another person right now, where the bottleneck is finding the right someone.
>
> Think about me from everything you know: what people already come to me for, what I'm stuck hunting for, what recurs in my work. If I wear more than one hat, ask which one this card is for, or scope it to that hat. Draft up to 6 tags each side, fewer is fine, short, lowercase, hyphenated, naming the thing itself not how I'd get it, each with a one-line plain gloss a stranger's agent could understand. Mark any Need that's active-now-and-expires versus an ongoing stream.
>
> Quality bar: for each Have, a specific real person should be glad to be connected to me for it; for each Need, a specific person could plausibly have it. Too vague to picture who's on the other side means sharpen or cut. No resume or status language (expert, thought-leader, founder). This card is public, so never put confidential client names, private deals, or anything I wouldn't want a stranger's agent to read.
>
> Then show me the card and close with exactly this: "Is anything here something you wouldn't want strangers' agents reaching you about, and is there something real you'd be glad to be found for that I missed?" If I don't want changes, it stands as drafted.

Onboarding addition (2026-09-27): "Draft this person's card from every tool you can read: CRM, calendar, email, documents, and what you remember. Confirm before publishing anything."

### 3.4 Living card, low touch (2026-09-27, decided, ships `v0.5.0-seed`)
The agent updates the memory file as it goes (`note_need`, `close_need`, `note_have`, all confirm-before-public): a need opens when the person says it, closes when they say it's handled, a have appears when they keep doing something for people. The pulse casts whatever is open. Consent: a public-tier need travels only after the person said "mazel" or confirmed once.

The agent speaks at three moments only: ✨ a hit with its why; 🌀 a yes; and once, when a new need is about to travel to strangers for the first time. Everything else is silent and visible only when the person asks to see their card. Investment is never homework (§8.3).

**Aging, action-based (Ariel, 2026-09-27; ships with `v0.5.1-ghosts`).** A need stays open while it shows signs of life: the owner mentions it again in any conversation; the owner engages a candidate (asks for the why, says yes); a witness still shows it (the CRM deal it came from is open, the calendar has meetings on it). A need goes quiet on signs of death: the owner passes on three candidates in a row; the witness closes (the deal is won or lost, the hire is made, the calendar goes silent on it); the owner says it is handled; a 🌀 leads to met-continued. Quiet means it stops casting, stays on the file, nothing is said; a hit arriving for a quiet need makes the agent ask once, "still looking for X?", yes reopens it, no closes it (inside the three moments, since a hit is one). Time is the fallback only where no signals exist: a need with no witness and no engagement either way goes quiet after 60 days; stream needs (podcast guests, partner intros) have no window. Haves are already action-based: witness recency is action (deals, meetings, emails) and outcomes move them (§5.4); a have with no witness activity for 12 months drops one tier, 24 months two, a fresh witness restores it, nothing is asked. Owner-attested haves stay where the owner put them until `RELAY_REQUIRES_WITNESS` is on, then sit at tribe until a witness appears. The witness check (§8.2) is where the owner sees what is aging and why. Nothing is deleted by aging: things go quiet or drop a tier and the memory file keeps them. Same rule as everywhere in this spec: what people do, never a timer where evidence exists.

### 3.5 Personas and moments (direction, Ariel, 2026-09-27)
Needs are a function of persona and moment; the person is the key that signs them. A person has several personas (the channel partner, the parent, the sailor). Personas are lenses over one memory, never partitions (Ariel, 2026-09-27): the person is whole on the memory file, witnesses land in one corpus (the Sensay snowball), matching runs on the whole file, and a persona is a projection rule: which fields show, at which tier, to whom, under which handle. Consent is per persona; matching is across them, so a cross-persona hit (the hockey player and the CFO) still surfaces to the owner, who decides. Segmenting too tightly kills the cross-persona hit, which is the most magical kind. Today's card is one lens and the memory file holds many. A need belongs to a persona at a moment ("security partner for a 200-seat Azure move, this month"), never to the person forever. Matching is persona × moment against persona × moment: two people who never match as people match as "founder raising in October" and "angel deploying in Q4." A persona card can travel pseudonymously, signed by the same key, revealed only on a yes. The relay learns that a whole tribe needs the same thing in the same month without knowing who anyone is: flows, not people. Reshapes the memory file (personas as a layer) and the fingerprint (one vector per persona). Lands with those; costs nothing now. **Why labs cannot do this (Ariel, 2026-09-28):** each lab sees only the slice of a person they bring to it (Claude for work, ChatGPT for home, Muse for friends), and a lab cannot use one user's private data to connect them to another without breaking its privacy promise. One portal connected from every AI a person uses assembles the whole person, and cross-persona matching lives there. The same holds for contacts: phone, CRM, Gmail, and LinkedIn each hold a piece of who a person knows, no lab holds them together, and no lab can route one user's need through another user's contacts; the portal holds the whole rolodex as "people you already know," and a tribe's reach is the sum of its members' rolodexes with each owner's yes (§6.5). Product consequence: connecting a second AI to the same portal is one URL, and onboarding offers it.

### 3.6 Silent needs and the fingerprint (2026-09-27, decided; fingerprint layers parked with seeding)
The agent reads the person's own email, chats, and CRM on their side and writes needs and haves to the memory file at matched-only. They never appear on any card. A matched-only need travels as a fingerprint only; the relay and other portals score on nearness and read nothing. Only a high-probability hit triggers anything, and it goes to the owner first, privately: "I think someone fits something you mentioned to Dave last week. Want me to ask?" No is silent. Text appears only after both humans say yes, and only what each chose to share.

Fingerprint, three layers, only the fingerprint ever leaves the agent:
- **Prose:** a few hundred words, the card summary and the memory file, readable and correctable.
- **Hashed set (now, `v0.5.0`, corrected `v0.5.2-sec`):** needs and haves as short hash-prefix buckets (4096 buckets, `FP_PREFIX = 3`, match on `FP_MATCH_MIN = 2`). Honest limit, measured by the security reviewer: four buckets identify a need's word set to about one in ten to the twelfth, so anyone holding a blind cast can confirm a guessed need with a definitive yes; unkeyed fingerprints cannot avoid that and decoys do not help. Therefore blind casts go to known cards at tribe and inner only by default; `BLIND_TO_RELAY` is a config flag, default off, and blind TTL is 24 hours. Silent needs stay silent inside the circle that already knows the person; strangers wait for real private set intersection.
- **Vector (later):** the same text through one open embedding model every portal ships with (Cloudflare has them on the Worker), so fingerprints from different agents compare, and "sailing the Atlantic" sits near "ocean crossing." One vector per persona.

### 3.7 Recovery and deletion (gap named 2026-09-27, decide before the first tribe)
Recovery: losing the Mac, the Cloudflare account, or the connector URL must not lose the graph. Candidate: the memory file and known cards export as one signed archive on request; a new portal imports it and publishes a rotation record. Deletion: deleting the portal removes the memory file, known cards, mailbox, and threads. It does not reach ghosts of the person on other people's portals, signed casts in relay caches until TTL, or outcome objects on the other side of a connect. The privacy policy states what deletion reaches. Third-party data: ghosts are built from other people's contact lists; the defenses are that ghosts never leave the owner's portal, travel only as fingerprints, and produce contact only after the owner says yes. Write the principle before the tribe seed, since organizers will ask.

---

## 4. Ontology and consent

### 4.1 Objects (§25.2 of the 2026-09-18 architecture, extended 2026-09-27)
Seven object types in the Rust core: **Person, Need, Have, Match, Intro, Outcome, Vouch.** Plus two generic types with a registry (2026-09-27):
- **Entity**: `kind`, `key`, fields, witnesses. Kinds registered first: Organization (key: domain, which every witness supplies for free), Skill (key: canonical slug), Tribe (key: organizer key plus slug); then Place, Product, Event, Topic as needed. A new kind registers a key rule and a display name, no schema migration.
- **Edge**: `from`, `to`, `type`, strength, dates, witnesses. Types: works_at, knows, has_skill, sold_to, met_at, based_in.
Person, Need, Have, and the rest reference any Entity by kind and key ("Skill: azure-security, witnessed by three deals at Organization: contoso.com"). Resolution across portals is kind plus key, deterministic and public, so two portals mean the same Contoso with no central registry. Entities live on portals only, never on the relay, since a domain-keyed object cached centrally is an index. Ships in `v0.5.1-ghosts` with Organization and Skill.

Links carry the value: an Outcome writes back into the Have's verification, the Vouch's weight, the relationship's tier, and the routing policy that produced the Match. Shared truth between two people (a Match, an Intro, an Outcome) exists as two agreeing copies, one per portal, reconciled, never one central record. Leave Mazel and you take your ontology with you. CRDTs keep two copies coherent (walk). Network intelligence is learned federated: portals share learnings, never data.

### 4.2 Intro states and origin
The Intro carries consent state per named party and `origin: cast | collision`. States: proposed → connected (unanimous yes; the proposer said yes by proposing, the other side by accepting) | declined. Answering twice is refused; a re-propose over an answered intro is refused. Both portals apply the same rule to the same wire event and assert agreement on state, decision, and `connected_at`. Connect is Intro's success state; Outcome is what follows it. After connected (2026-09-28), the thread carries its own states: open (thread created, intro note is message one) → sent (first human message) → replied (the other side answered) → met (a meeting with that person happened) → the outcome; or lapsed (§4.3b edge behavior). The headline metric is 🌀 to replied within 7 days.

### 4.3 Consent (2026-09-14, amended 2026-09-27)
Consent is a unanimous yes from every human named in the intro. The rule is written N-wide so nothing rebuilds later. Two applications:
- **The route.** When a need passes through a person (a second-hop ghost's owner, a witnessed edge's owner, a clarifying hop), that person is asked first and their yes is the yes to route. Their name and why travel with the intro; they are on the outcome object as a router. This is the introducer's yes from the 2026-09-14 model and the attribution receipt: referral credit hangs off the recorded granted-set with the router named.
- **The meeting.** Ask every human who has not already asked. The caster asked by casting, so a HAAH intro notes only the other side; an AAHH collision notes both at once with the same note. Soft-no (pass) is first class and leaves no note; a later yes still works. Offline peer waits; timeout clears; retry after timeout works. Revoke mid-join drops humans, keeps agents, clears the note.

### 4.3b The thread: how humans connect (Ariel, 2026-09-28, decided; ships `v0.5.7-thread`)
The gap: until 2026-09-28 the spec said "the humans are in contact" and never said how. A first draft (routes revealed on yes, first email from the owner's inbox, agents step out) was withdrawn the same night. Decision: **Mazel is the messaging layer between connected people, built A2A-native, and the conversation lives only on the participants' portals.** Reasons: strangers talk without exposing email or phone; private needs stay private; the agent keeps the why, schedules, and reads outcomes without reading anyone's inbox; the thread history, router credit, and outcome ledger live in Mazel; and a thread independent of intros keeps the sovereign-messaging pivot open (§12.5).

**Built on A2A primitives, HAAH adds people and consent.**
| Need | A2A | HAAH adds |
|---|---|---|
| A thread | `contextId`, one per connected intro | Opens only on 🌀 |
| A message | `Message` with text, file, or data parts | `author: human | agent`; human words pass verbatim, agent notes labeled |
| Share an artifact | `Artifact` or a file part | Tier check on what is shared |
| Ask the other agent to do something | `Task` and its states | Owner confirms anything that commits the owner (a meeting, a document) |
| Subscribe | Push notification config to the other portal, streaming for live replies | Signed with the portal's Ed25519 key |
| Persistence | Each portal's own storage | Thread content never feeds matching, cards, or sensing (§7.5) |

**Rules.**
- One need, one thread (Ariel, 2026-09-28). The need is message one. A branch opens per candidate the moment a real candidate answers (a `find.hit`, a relay hit, a contact match); candidate A never sees candidate B. Agents talk first in the branch, labeled as agent messages; on 🌀 the humans join the same branch with the whole history in view. The intro note (§4.5), including the ask and its size, is the agents' summary posted into the branch at 🌀. A thread with no need (a direct message after a past connection) is allowed; thread code never assumes a need or an intro exists.
- Who writes first: in a direct match, the side with the need; in a collision, the side whose agent found it; in a router match, the router's agent opens a three-party thread and the router leaves after the first reply; in a tribe match, as direct (the organizer stays out unless their agent made the match). On 🌀 the agent drafts the first message with two or three times from its owner's calendar; the owner sends with one tap.
- Contact details are never required. Either person can share email, phone, or a calendar link inside the thread whenever they choose. Mazel offers no "move to email" button; the conversation's home is the thread.
- The agent never rewrites a human message on the way out.
- A saved contact with no portal replies by link: the sender's portal serves a signed page scoped to one thread; the reply lands on the sender's portal; the page offers "get your own agent to handle these." Mazel hosts nothing.
- Delivery is portal to portal. If the other portal is unreachable, the sender's portal queues and retries with backoff for 7 days, then tells its owner. The relay never carries message content.
- The doorbell: a contentless notification to the owner ("New message from Sarah") linking to `/inbox`, the owner's phone-friendly thread page. The pulse remains a backup sweep.
- Either side can close a thread (ends it for both, history kept by each) or block (the other portal's messages are refused; a report lowers that portal's trust level).
- Each person can export or delete their own copy. Deleting yours leaves the other person's copy on their portal.

### 4.3c The box: the variable reward (Ariel, 2026-09-28)
Mazel putting a new message in your box is the reward. Four kinds land there, each as a message in a thread:
- **Someone needs what you have**: a stranger's or contact's need reached a branch with you, screened by your agent. 📬
- **Found someone for your need**: a candidate and the why. ✨
- **A reply** from a person you are connected with.
- **Both said yes**: the humans are in the branch. 🌀
Rules: uneven by nature, never fabricated (a message that is not a real person or a real need is the slot machine, the Sensay scar). The agent screens before anything lands: below the fit bar is silence. Doorbell rings immediately for replies and 🌀; agent-found items ring once each up to a daily cap (config, default 3), the rest wait in the box and are named in the next ring. The box is `/inbox` on the phone and "check my mazel" in the AI. Day one must not be empty: contact matches and the relay feed the first message (§8.3 bootstrap). The north-star metric counts messages in the box that led to 🌀.

**Edge behavior (defaults in config).** First message unsent: one reminder to the owner at day 3; at day 14 the thread lapses and the other agent is told quietly, no human notice. No reply: one drafted follow-up offered at day 5, then the agent stops. No-show: one reschedule offer, then "didn't meet." Reply-by-link expiry: 14 days, renewable by the sender with one tap. Router thread: if the router never leaves, nothing breaks; the router's agent offers to leave after the first reply.

**Next on the thread, not in `v0.5.7`:** encryption between portals (the envelope carries a ciphertext field from day one so this lands without a wire change), agent-to-agent scheduling as a `schedule.propose` task (three slots each, owner confirms, one invite), CRM logging of the connection's facts (who, when, why, outcome; never message content).

### 4.4 Outcomes without ratings (2026-09-18)
Ratings fail because they ask out of context after the deal. Outcomes are inferred from the next action and overheard sentiment, never solicited: a follow-up scheduled is a strong positive; an onward intro is very strong (a vouch by behavior); never mentioned again is weak; explicitly avoided is negative. Sentiment said to the agent right after ("that went well") closes the loop from a sentence already being said, locally. Behavioral states, not scores. Both portals cross-check. Explicit confirm only for the weighty outcomes. Outcome objects are created from day one, before the models that use them exist, because every closed loop is training data. Verification of a Have is shown per match to the counterparty, never posted publicly. Vouches cost the voucher, are weighted recursively by the voucher's own verification (a ring of fresh accounts has no weight to give), and graph density exposes rings. Self-report and uploads remain "curious," never verified. No coins, no ratings, no public scores, ever (Ariel, 2026-09-27).

**The closed loop, analysis half (Ariel, 2026-09-27).** Outcome ledger per portal: every intro gets an outcome object, including "nothing yet"; the owner can ask how their intros are going and get their own ledger (nine proposed, five met, three continued, one referred on), never a score. Write-back, Palantir-style: an outcome writes to the objects it touches (the Have's verification, the Vouch's weight, the Edge's strength, the persona's tier defaults, the routing policy that produced the Match), which is what makes the ontology live instead of a log. Federated aggregates: a portal can opt to publish signed, anonymized outcome summaries to the relay (counts by facet combination, by origin cast or collision, by carrier, by tier; never who); the relay computes network rates the scorer's weights learn from; any portal can read them; delete the relay and the ledgers remain. Analysis runs locally first, network-level only from aggregates: everyone contributes counts, nobody contributes people. Questions it answers: which facet pairs produce met-continued; which carriers produce quiet; how long a need takes to land by tier; whether the three-moment rule is too quiet or too loud, measured by 🌀 per ✨. The north-star metric (§10.1) reads straight from this ledger. Ledger and write-back ship with `v0.6.0-trust`; aggregates after the first tribe.

### 4.5 Intro note schema (single-sourced from DESIGN)
sessionId, createdAt, expiresAt; parties[{role: seeker|offerer|peer, human{displayName}, agentCardUrl}]; opportunity{type: intro|hire|invest|collab|other, summary, freshness, whyNow}; mutualInterest{evidence[], consent{per named human: pending|granted|denied}}; artifacts[{title, uri, sensitivity: public|redacted}]; openQuestions[]; suggestedOpener; redactions[]; returnToAgent{allowed, notes}. The recorded granted-set with the router named is the attribution receipt.

---
## 5. Trust and reach

### 5.1 Tiers: inner, tribe, world (2026-09-18, clarified 2026-09-27)
Three tiers on every known contact. Defaulted to tribe at crawl, never asked; inferred from costly acts at walk. Costly acts are the signal because they measure what people staked: calendar (time committed together), vouches (reputation staked), witnessed intros and meetings that Mazel produced. Email is second order: it sets edge strength for routing (threads, recency, who initiates, reply speed) and gives the owner a closeness readout when asked to route; it moves nobody's tier by itself. LinkedIn seeds ghosts and a known-since date and contributes nothing to trust. Movement between tiers is the growth mechanic: a vouched intro moves someone from world into tribe; sustained trust into inner. Trust (how much I trust this person) and verification (how sure we are a claim is real) are separate.

### 5.2 Matching rules stay fluid early (Ariel, 2026-09-27)
Every threshold in one config, default permissive. Anything that produces a real intro with a why is allowed. The levels and noise defenses tighten from what the first tribe shows. Network thickness first, then rules.

### 5.3 Levels (owner-visible reach, 2026-09-27)
Needs travel everywhere from install. Levels gate how far haves are visible, never what a person can look for.
- 🪽 live: needs reach everyone; haves reach inner and tribe.
- 🪽🪽 corroborated haves: haves reach the relay.
- 🪽🪽🪽 three 🌀, or a vouch from a 🪽🪽🪽: two gossip hops; vouches carry weight.
- 🌍 ten 🌀 with met-continued: haves rank first on the relay.
The owner sees their wings, what unlocked them, and what unlocks the next. A stranger sees the why and whether a 🌍 is present, never a count. Spruce-ups (§8.3) hang off levels. Casting works at 🪽; collisions start at 🪽🪽.

### 5.4 Noise defenses (2026-09-27, pre-Muse)
The moment strangers can be reached, cards get packed. Six structural defenses, none a rating:
1. A have carries its corroboration; a have with no witness beyond the owner is excluded from the relay once `RELAY_REQUIRES_WITNESS` is on (§3.2).
2. The scorer penalizes breadth: thirty haves each score below five.
3. Six public haves, owner picks; the rest stay on the memory file.
4. Outcomes move reach: declined and went-quiet lower it, 🌀 raises it, all from the wire.
5. A vouch stakes the voucher's own reach.
6. The relay ranks corroborated first, and its TTL forces padded cards to keep re-casting to exist.
Relay ranking and the public cap shipped in Fly; the rest ride on seeding.

### 5.5 Decisions: do not assume the LLM (2026-09-18)
Mazel is a set of distinct decisions, each made by the right model. Sensing is language (a small tuned local model beats a frontier model at that narrow task and keeps the sensor sovereign). Trust inference is a graph problem. Routing is a learned policy trained on outcomes. Matching is deterministic factors first (fit, heat, fresh; same inputs, same score; weights in code), entities as well as text, a small learned ranker later; never elasticsearch, BM25, or chat-similarity wildcards in the match pool (the Sensay scar). The LLM is the narrator: it explains the mutual why and writes the intro note.

**Facet routing (Ariel, 2026-09-27; the special sauce).** The matching socket decides two things per pair: which facets of two whole people to compare (work to work, hobby to hobby, hobby to work), and which facet leads the why. Crawl: hand rules, professional fit first, one shared personal facet as the opener when both hold it at a tier the other can see. Walk: learned from outcomes ("governance fit plus both ride" produced met-continued three times; "governance fit alone" went quiet twice). The training data, which facet combinations led to 🌀 and met-continued across whole people, exists only on portals that witnessed it; LinkedIn has one facet, Facebook has the others and no outcomes. Federated learning improves the policy across portals without any corpus leaving. Rule: matching runs on everything; a personal facet appears in a why only if its owner holds it at a tier the other side can see. Crawl uses the LLM for nearly everything because there is no outcome data yet; the crawl-era investment is hoarding outcomes.

---

## 6. Discovery: how needs travel

### 6.1 The invention (2026-09-18)
Needs and haves travel as messages. A match is a collision at a shared node. The path is the trust. Searching what you already collected is a filing cabinet; the need leaves the portal and goes looking.

### 6.2 Carriers (Fly, `v0.4.0-fly`, live 2026-09-27)
All on at once, none owning anything:
- **Known cards.** The portal scores a cast against every card it holds. One hop.
- **Gossip.** A `find.request` arriving with `hops < 2` is forwarded once to the receiver's public-tier known cards and (from `v0.5.1`) scored against the receiver's ghosts; origin signature intact; answers route to the origin's door as `find.hit`; dedupe by need id; a portal never answers a request it has already seen.
- **Relay.** A Worker on the company account, single file, same scorer as the portal (one source, inlined at build, a test asserts the copies match). `POST /cast` (signed public need or card, 7-day TTL), `GET /search?q=`, `POST /subscribe` (A2A push config; on a matching new cast the relay POSTs a signed `find.hit` to the subscriber's door). No accounts; signature is the only auth; TTL on every record. It never carries a message between people. README opens with: deleting it loses nothing any portal doesn't hold. `RELAY_URL` is a portal var; `none` turns it off.
- **Nostr.** Fourth carrier, stubbed behind `CARRIER_NOSTR=1`.
Public-tier needs cast to known cards and the relay in one action. Matched-only and directed never leave the portal. Stranger cards land as world-tier known cards; the intro flow is unchanged.

### 6.3 Threads and the pulse
A cast need is the root of its thread (§4.3b): open, collecting, closed, expired; fit-gated; capped at 5 candidates; reopen raises the cap by 5; `add_known_card` offers a new card to every open thread it fits, so a need cast yesterday picks up someone met today with no recast. Failure paths handled: no match, declined, offline portal, expired need.

The pulse (2026-09-27): a Cloudflare Cron Trigger on the Worker, every 30 minutes by default, one cast per open public need, one score pass over what landed, one badge line written to the mailbox as a `pulse` item, quiet when nothing hit. No agent involved. Manual `pulse` tool for the agent, read-only on the badge line. An agent-side hook (OpenClaw `HEARTBEAT.md`, a Claude scheduled task) is optional.

### 6.4 Identity and the directory (2026-09-27, shipped `v0.4.0-fly`)
Ed25519 key per portal (WebCrypto), generated at install or first use, private key in KV, public key in the HAAH params. Casts and `find.request`s carry an origin signature; relay and receiving portals verify. Rotation: a record signed by the old key, cached by the relay and the directory; threads survive a rotation.

A handle is `name@domain`, resolved by fetching `https://domain/.well-known/mazel/name.json`: a record signed by the portal's key holding public key, portal URL, timestamp, stored and served verbatim (a relay rewrite of the handle broke every signature once; fixed with a read-back test). Any domain can be a directory; a company serves its own staff. `name@mazel` is shorthand for `name@mazel.ai`, whose directory is a cache written from signed records portals publish to the relay. The key is the identity; the handle is a label; changing domains keeps the key and every thread. No handle marketplace; exact collisions resolve by proof, never first-claim.

### 6.5 Witnessed edges and second-hop ghosts (2026-09-27, decided, ships `v0.5.1-ghosts`)
People connect their CRMs and Gmail to their agents and use a fraction of it. Each person's agent holds their Salesforce, HubSpot, and Gmail contacts as ghosts on their own portal, tribe-tier to the owner only, never cast to the relay, never counted in anyone else's reach. Gmail is the largest ghost source: a business inbox is a CRM with dates, frequency, and context.

A need arriving on the gossip hop is scored against the receiver's ghosts. On a hit the owner is asked first: "Ariel is looking for X. You know Sarah at Contoso from a deal last spring. Want to introduce them?" Yes sends Sarah the HAH invite, or an ordinary intro if she is on Mazel, with the owner as router on the outcome object. No is silent. The contact's name reaches the asker only after the owner says yes. No auto-intros from someone else's contacts, ever. Reach of a tribe becomes the sum of its members' rolodexes.

Witnessed edges: a saved contact carries **no address and no hash of one** (`v0.5.2-sec`: the bucket was removed from the record and the hash removed from the contact, since a stored global hash is a liability with nothing left to match against). Directory records publish no email hash and no bucket (decided `v0.5.2-sec`): the reviewer measured a published bucket as a 99.7% membership test against a 12-address shortlist for a named person, and no salt fixes it since a usable salt is public. Until real private set intersection exists, a contact resolves to a card only when the owner pastes a handle or card URL, or the person installs through the invite. Resolution then writes the witnessed edge into the owner's local routing table. The edge is written into the owner's routing table on the owner's portal. Distributed means the sum of everyone's local tables; the edge is never sent to the relay, and the other person learns nothing until something is routed to them. Through the owner by default; the intro carries the owner's why and name. Exceptions: two people already in the same tribe match directly; public-tier matches at world tier through the relay skip the owner. When both sides' witnesses show the same edge, the portals can discover it through the signed pull and upgrade to a mutual tribe-tier known card after each owner says yes once. Closeness is the edge strength, computed on the owner's side from the witness (Gmail: threads, recency, who initiates, reply speed; CRM: deals, last activity; Calendar: meetings, recency); the owner sees it when asked to route; the other person never does. Paths across the network emerge with nobody holding the map.

Company-level needs: a need aimed at an organization becomes a query over people at that Organization entity, ranked by role match then edge strength, pinged one or two at a time through the strongest edge, closest first, never sprayed. Beyond that, parked for walk.

### 6.6 The shapes (2026-09-27)
Named by who is in the chain. One machine, one field different: the Intro's `origin`.
- **HAAH**: a human asks, the agents talk, the other human answers. The pull. `cast`.
- **AAHH**: two agents notice their humans fit during a pulse or an unrelated thread, agree on a why between themselves, and ask both humans at once. The push. `collision`. Needs a higher score and both cards corroborated, because nobody asked. Agents agree on a why, never a commitment; one no ends it silently; neither reveals anything above the other's tier.
- **HAH**: a human asks and the agent reaches a person with no agent yet. The ghost invite ("someone you know is looking for what you have"). How the network grows.
- **The clarifying hop**: a need reaches someone who cannot fill it but knows the domain; their agent shows it (tribe tier, consent as usual); they sharpen it in a sentence; the refined need continues with the refinement attached and signed by them. Hop 1 can be a human. The clarifier sees only what the origin's tier allows, adds text and never rewrites the origin's words, and the origin's agent can drop a refinement. If it lands, the clarifier is on the outcome as a router. The TSD channel manager's job as a protocol shape.
- **HH**: after 🌀 the agents step out and two people talk. Every path ends in HH.
They feed each other: a cast that goes quiet leaves the need open and a later collision can close it; a collision that connects teaches the scorer what fit looks like for that person.

### 6.7 Unexpected mail (2026-09-27)
The mailbox is where things arrive that the person never asked for. Their haves are subscribed on the relay; when a stranger's need lands on one, the pulse writes one note: who is looking, the why, one line, 📬. Quality bar: only casts that clear the fit bar, from corroborated cards, with a plain why; below that, silence, since a bad note costs more than no note. Uneven by nature, which is the variable reward without engineering it. Every note is an offer and yes is one word.

---

## 7. The portal and the wire

### 7.1 The endpoint rule (2026-09-14, Ariel)
Keep the endpoint on the user's own account, always. A brain (Claude, GPT) cannot host the portal because it only runs during a session and the portal must answer while the user is away. Setup can shrink (agent-driven deploy, one-click button, auto-provision) but never goes to zero, because whoever hosts the endpoint can cut the user off. Cheap, not free. The step retires only when a lab ships an always-on agent that receives inbound; that agent then becomes the portal and the Worker is dropped. Option C (Mazel hosts a relay or mailbox in the middle of people's messages) is rejected, permanently. The talk model is door plus mailbox with polled replies: an ack returns immediately on every send; a void is a bug; a guaranteed reply within a day already beats every trust network.

### 7.2 The portal today (`v0.5.7`)
One Worker per person, on their own account. Faces: `GET /` (welcome page before claim: the connector link and "paste this into your AI," for 60 minutes, then how to get a fresh one; after the first `update_card` claims it, the public card page); `GET /card` and `/.well-known/agent-card.json` (A2A v1.0 Agent Card with the HAAH extension); `POST /a2a` (A2A `SendMessage`, validates, queues to the KV mailbox, 30-day TTL, acks); `POST /mcp?token=` (the MCP connector for Claude and ChatGPT; tools: `my_card`, `my_identity`, `update_card`, `claim_link`, `check_mailbox`, `clear_messages`, `fetch_peer_card`, `add_known_card`, `remove_known_card`, `list_known_cards`, `resolve_handle`, `find`, `list_threads`, `close_thread`, `reopen_thread`, `propose_intro`, `respond_intro`, `respond_intro_link`, `list_intros`, `send_to_peer`, `pulse`, `carriers`, `rotate_key`; `v0.5.0` adds `note_need`, `close_need`, `note_have`); `GET /memory` (owner only); `GET /inbox`, `POST /inbox/clear` (raw, token-authed). A portal that cannot be given a secret (button installs) mints its own inbox key into KV and learns its own address, so the pulse still runs.

Signed links: the claim link and intro-response link let a person's browser do a write the connector cannot (ChatGPT Plus and Pro disable write tools on custom connectors). The agent drafts, hands the person a link to their own portal showing the draft with one Save button, single-use token, 30-minute bearer URL. Live-proven on the peer; ChatGPT live test pending.

Output shape: every tool returns one JSON shape with the prose in a `headline` field (mixing a glyph line with JSON broke parsing).

### 7.3 The wire (A2A v1.0 with the HAAH extension, `v0.3.0-a2a`)
Adopt, extend, no fork. Official A2A (Linux Foundation, Apache 2.0). The `@a2a-js/sdk` types and client are used in the harness and `create-mazel` (the Worker ships dependency-free; a conformance test asserts against the real types). Rust types serialize A2A-native by hand with a JS round-trip test in CI; no `a2a-rs` dependency (community, pre-1.0).

Agent Card (v1.0): `name, description, supportedInterfaces[], version, capabilities, defaultInputModes, defaultOutputModes, skills, securitySchemes, securityRequirements, signatures`. HAAH is declared as `capabilities.extensions: [{ uri: "https://mazel.ai/ext/haah/v1", required: false, params: { handle, need, have, glosses, rpc, publicKey } }]`. Every message carries `extensions: ["https://mazel.ai/ext/haah/v1"]`. Header `A2A-Version`. Typed actions inside the message: `note`, `find.request`, `find.hit`, `intro.propose`, `intro.respond`; new types slot in without a rewrite. Threads between people (§4.3b) use A2A's own `contextId`, `Message`, `Artifact`, `Task`, and push notification config; HAAH adds only authorship, consent, tiers, and (next) encryption. `TaskPushNotificationConfig {tenant, id, taskId, url, token, authentication}` is the subscribe primitive (named `pulse` in config, never heartbeat). SSE streaming stubbed behind a flag. Clean break at v0.3.0: no legacy card shape.

Errors are JSON-RPC standard codes. A pass is an agent-level polite no carried as a normal reply, never an error. `rpc_none` (a card with no endpoint yet) is a valid state; never invent a host. Unknown senders without a card URL may be answered with a pass.

### 7.4 Mailbox privacy and limits
Owner only, via the mailbox token, which is never shown after first issue. A second credential exists since `v0.4.1`: the setup key on the welcome page of an unclaimed portal, shown for 60 minutes and retired at the claim. Stored: agent-to-agent messages, 30-day TTL, deleted on clear; thread messages (§4.3b, from `v0.5.7-thread`), kept until the owner closes, exports, or deletes them. Never stored: tokens in logs, sender data beyond handle, card URL, and text. Logging: Cloudflare defaults, no Mazel analytics. Revoke: rotate the inbox token, re-add the connector. Abuse limits shipped in `v0.4.2-sec`: body-size and text-size limits, a daily find-request cap, TTL enforcement and replay protection on the relay. Per-IP and per-card caps on `/a2a` are a real item for `v0.5.2-sec`. KV read lag (~60s on back-to-back writes) is recorded and worked around in tests; Durable Objects fix it later.

### 7.5 Host boundary and the cache principle (2026-09-14, amended 2026-09-27)
mazel.ai and any Mazel-run host serve static install and about material, plus discardable caches of signed records under the §10 constraint (the relay, the directory). Test for any such host: delete it and no portal loses anything. The cache never sees message content, never holds a record past its TTL, and never decides a match a portal could not decide alone. Matching, chat, and anything Mazel-through-the-middle never run on Mazel hosts. Mazel indexes no conversations (Ariel, 2026-09-27): transcripts live in the host agent; thread messages between people (§4.3b) are stored on the two participants' portals for them to read and are never used for matching, cards, sensing, or aggregates; the portal holds the memory file and the objects, a compiled summary and never a log; sensing runs inside the agent through tool descriptions; more signal comes from a periodic reflect over the agent's own memory, from witnesses, or from a local sensor where the harness allows one, never from a corpus on the portal.

### 7.6 What is replaceable (2026-09-26)
Cloudflare: the portal is one JS file with a `fetch` handler and a key-value store; Deno Deploy, Vercel, Fly, or a Node process run it with a storage shim. A2A: the card is a projection, so a new wire is a re-projection; HAAH lives in an extension slot. The host agent: Claude, ChatGPT, Muse, Hermes are connectors. What survives all of it: the ontology and Rust core, the signing key, and the rule that nothing central owns anything. Real exposure: the relay is the one thing Mazel runs (gossip and Nostr carry when it is down); handle resolution is a cache of signed records so it never becomes the one central thing.

### 7.7 Three accounts (2026-09-27)
Workers on one account cannot call each other over workers.dev (error 1042), so every party that talks to another lives on its own account, which is also the honest shape of the network.

| Account | Email | Role | Holds |
|---|---|---|---|
| Personal | ariel.jalali@gmail.com | Ariel as a user | Worker `mazel` (Ariel's portal, 0.5.7, pulse cron set), `MAILBOX` KV, subdomain `ariel-mazel.workers.dev`. Also `q`, another project, off limits. |
| Company | ariel@mazel.ai | Mazel the company | Pages `mazel-a2a` serving a2a.mazel.ai (the Mazel card: company have and need, support@mazel.ai, no personal names), the relay Worker, the directory cache. |
| Test | mazel@mazel.ai (Zoho alias) | The permanent test peer | Worker `mazel` as `testpeer@mazel` at `mazel.mazel-testpeer.workers.dev`. CI targets this. |

Rules: nothing company on Personal, nothing personal on Company, nothing but the peer on Test. One API token per account (Edit Cloudflare Workers, no expiration, named for its role), in `~/mazel-work/{portal,company,testpeer}-token.txt`, gitignored, never in chat; a token that passes through a chat gets rotated. Version: `PORTAL_VERSION` is the only place a version is typed; the relay is stamped from it at build; a test fails on drift.

---
## 8. Onboarding and seeding

### 8.1 Install asks zero questions (`v0.4.1-install`, live)
Handle, card, and everything personal happen in the first conversation. Two paths, both ending on the user's own Cloudflare account:
- **Shell path** (Claude Code, OpenClaw, Cursor, Hermes): `npx create-mazel` (npm `create-mazel@0.4.2`, org `mazelai`, user `mazelhq`). Authenticates with Cloudflare's own OAuth flow (the public client `wrangler login` uses, disclosed in one line): browser opens, sign in or create an account, click Allow, nothing written to disk. `--token` stays as a hidden flag for CI. Update mode for existing portals.
- **Button path** (Claude.ai chat, ChatGPT, Muse, anyone without a terminal): a Deploy to Cloudflare button on mazel.ai/install. Cloudflare clones the public `mazelai/portal` repo into the person's GitHub, provisions KV and the pulse cron from `wrangler.json`, deploys. Human actions: Cloudflare sign-in, GitHub sign-in, Deploy.
Both end at the welcome page (`GET /` before claim). The first conversation claims the portal, sets the handle (the one question), drafts the card from what the agent knows, confirms, and casts. mazel.ai/install is written so an agent reading the URL derives the flow; a model with no prior knowledge of Mazel did. The install page is hidden from search until launch. The install file (this page, the onboarding tool description, the welcome page) is updated in the same batch as any change to what a new user sees or does (Ariel, 2026-09-28).

Doctrine (2026-09-14): the onboarding document is the installer, and its reader is the agent. A non-technical human with a capable agent is a technical user. Every stage leaves an artifact; the human's own AI is the recovery mechanism; last resort is a 15-minute pair-deploy onto their account, which preserves sovereignty because ownership is about whose account, never whose hands clicked. Human floor: a free Cloudflare account, plus GitHub for the button path.

Target brains (2026-09-14): Claude and ChatGPT first; OpenClaw and Grok/Cursor class are supported clients. Both consumer brains reach connected apps on a timer (scheduled tasks), which matches the mailbox model. Asymmetry: ChatGPT Plus and Pro custom connectors are read-only; the signed links (§7.2) are the workaround; Claude has no such split. OpenClaw: a Mazel skill on ClawHub reaches self-hosted, always-on agents; ship after the first tribe. Cross-brain Switzerland is a lock (§11): Claude/ChatGPT-first is sequencing, never architecture.

### 8.2 Witnesses: where the card comes from (`v0.5.0-seed`)
Three sources, by friction:
1. **The agent's own memory.** The onboarding tool asks the agent to draft haves and needs from what it already knows, then confirm. Mazel receives finished fields only.
2. **Connectors the agent already has.** CRM: open pipeline is needs, won deals are haves and outcomes. Calendar: who they meet and how often is the trust tier. Email and Slack: silent needs and the tribe. Drive and Notion: corroboration for haves. Chat memory: persona and the burning need. Nothing leaves the agent except the card and fingerprints. Mazel's portal never gets a connector to anything.
3. **Zips.** LinkedIn export (`Connections.csv`: name, company, position, connected-on date; plus positions, skills, recommendations, messages), Google Takeout, Meta data download. Extracted on the portal, deleted after.
Each have records its witnesses. Explained in thirty seconds as lidar: witnesses are the sensors, ghosts are the point cloud, the pulse is the sweep, and the point cloud stays on the car.

**The witness check** (`v0.5.1-ghosts`): at onboarding and on request, the agent reports which witnesses it can see and which are missing, specific to the card: which haves are uncorroborated, which would turn public with one more witness, roughly how many ghosts each missing source adds. `my_card` returns a `witnesses` block (seen, missing, what each unlocks); the agent enumerates its own connectors for "seen." Once at onboarding and when asked, never a nag.

**CRM write-back** (`v0.5.1-ghosts`): the CRM stays the system of record; Mazel never stores a contact, only a fingerprint and a question to the owner. Every 🌀 writes back as an activity on the contact, logged by the agent. Mazel is the layer between CRMs, since two companies' CRMs cannot talk and two agents can, with consent.

### 8.3 Ghosts and the bootstrap (`v0.5.1-ghosts`)
Contacts from witnesses become ghost cards: name, inferred have, organization, hashed email, edge strength; no address. Needs match against ghosts; a hit writes the invite ("someone you know is looking for what you have"); on install the ghost becomes real and both graphs are pre-wired. A have corroborated by sent mail, calendar, and a ghost that later joins is high trust without any rating.

The bootstrap game (2026-09-26, required before Muse): loading is the agent's ongoing job, and the first session is its first day. Each have or need that lands triggers an immediate cast, and sometimes it hits (a candidate, a why, a ✨). Rewards are real matches, never fabricated; the relay, gossip, and ghosts supply the liquidity that makes hits possible on day one; the game stops the moment the user has a pending intro.

LinkedIn coherence (parked for walk, 2026-09-19): a deterministic, non-LLM score of whether an exported history is a real lived career, from temporal coherence, network consistency, connection-date coherence, recommendation texture, and cross-portal corroboration. Feeds routing and verification confidence, never shown as a public number; surfaces to a human only as "I couldn't corroborate much of this yet." Provenance stays connector-level: the export seeds and corroborates, it verifies nothing by itself.

### 8.4 A tribe seeded by its organizer (`v0.5.1-ghosts` script; feature after two tribes)
1. The organizer drops the member documents; each becomes a ghost at tribe tier, nothing typed.
2. Members install with the button and their ghost is already there, pre-wired to everyone; day one their agent holds forty known cards.
3. Needs come from what they are selling into and match a have across the tribe in one pulse.
4. Credit is the outcome object: router and closer both hold the evidence; vouches follow; the router becomes the most-vouched person in the tribe.
5. The organizer sees counts only (needs cast, matches, 🌀), never content.
Members who each sell one thing start routing everything they see.

**Growth phase, organizer-first (Ariel, 2026-09-27).** Join-by-link is unrealistic as a first ask for busy professionals. In the growth phase the tribe works before anyone installs: the organizer's own portal holds every member as a contact at tribe tier; needs arrive the way they do today (calls, email, the podcast) and the organizer says "mazel"; matches go out as warm intros the organizer sends by hand; outcomes record on the organizer's portal. The first 🌀 happens with zero installs. Install is offered after a member has received an intro ("want your own AI doing this instead of waiting for me?"), and a member who installs converts from contact to card with tribe connections intact. Tribes are entities with actions (Ariel, 2026-09-27), in the same path as needs and haves: kind Tribe (name, purpose, organizer, members) in the §4.1 registry; edge `member_of`, witnessed by who invited or by the person's own join; the tribe tier (§5.1) is derived from shared membership, never hand-set. Actions `tribe.create`, `tribe.invite`, `tribe.join`, `tribe.leave`, `tribe.remove`. A tribe offers entry as a have ("a group of channel partners who route AI deals"); a person seeking a group casts a need; the match runs like any other. Joining is an Intro with `origin: tribe` and the unanimous-yes rule (§4.3): invite means the organizer proposes and the person says yes; ask-to-join means the person casts and the organizer says yes; the organizer is router on the outcome. Seeding from member documents is `tribe.invite` applied to each document. `tribe.leave`: the person leaves any time, no one's yes, nothing said to anyone; the `member_of` edge gets an end date and is never deleted; tiers recompute from what else connects two people (another shared tribe, a witnessed edge, or world); intros and outcomes already made stay on both portals; pending intros that originated in the tribe cancel silently. Visibility (Ariel, 2026-09-27): each `member_of` edge carries the member's tier like any card field (public, tribe, inner, matched-only), default tribe, so fellow members see it and no one else does; each tribe is listed or unlisted by its organizer; a member cannot make a membership public in an unlisted tribe; hidden memberships still route and still set the tier between members, since matching runs on the whole memory file. Tribes are flat, no hierarchy (Ariel, 2026-09-27): a smaller group inside a larger one (the AI people in a TSD community) is simply another tribe with its own organizer; a person can be in any combination; overlap does the work, so the more tribes two people share, the higher their match ranks (a routing weight, not a new tier); no parent rules for joining or leaving. `tribe.remove`: the organizer ends a membership with the same effects; the removed person's agent tells them once, in one line, since it is a crossing. A tribe wires itself together (2026-09-28): when a member joins, the organizer sends them the other members' handles and addresses and sends each member the new one, signed by the organizer's key and accepted only for a tribe the receiving portal is already in, so a member's agent holds the tribe on day one; the roster carries handles and addresses and nothing else. A tribe can later have its own card, like an Organization, and that is when a membership marked public starts being published; until then the setting is recorded and fellow members see it either way. Shipped in `v0.5.3-tribe`.

Later modes, parked for after growth: invite links; a Muse group admin seeding the whole group; an enterprise admin installing for a team (Copilot); always-on lab agents that are the portal already.

---

## 9. Experience: magic word, badges, the loop

### 9.1 The magic word
"mazel." One word to learn. The sole spoken trigger that routes a need to the network, and the consent. Tool descriptions key on it so "check my mazel" never blurs with "check my mailbox." Wings and other easter eggs are never spoken commands.

### 9.2 Badges (2026-09-18, emoji since chat has no UI)
Two registers: a quiet daily vocabulary and two reserved marks.
- **Closeness, the wing scale, one line:** 🪽 direct (two people), 🪽🪽 intro (three), 🪽🪽🪽 tribe, 🌍 world (from outside your water). Wing count equals parties minus one. Inner and tribe are inside your water and not separately flagged.
- **Mailbox:** 📬 flag up, 📭 flag down. "Checked your mazel: 📬 3."
- **Presence is the status.** If something is in your mazel it is live. Passed, declined, expired items are deleted, not marked. No status glyphs, no freshness glyphs, no colored circles, no stars (each is a scale, and a scale becomes a score).
- **✨ the magic worked.** The network delivered something you could not get yourself. Never on a cast, routine mail, or setup. Rarest use: an opportunity that arrived unasked.
- **🌀 a crossing.** Something passed between your world and another, so who-can-reach-whom changed: your portal opens; your card lands in someone's portal; first contact from the world; your need crosses out of your web; you became a bridge; a connect; someone moves a tier closer. Never for traffic inside your own world.
Rules: one glyph per axis, at most three per line, the wing is the only Mazel-native symbol. A month of use shows 🌀 a handful of times and ✨ only on days something real landed. Badges live inside the JSON payload's `headline`, never prepended to it.

### 9.3 The loop (Hooked, with no screen)
Trigger: external 📬; internal, the itch "I need someone for this." Action: say "mazel." Variable reward: ✨, sometimes a person, sometimes better than asked, sometimes nothing yet; and unexpected mail (§6.7). Investment: 🌀, the crossings that load the next trigger. So: 📬 → mazel → ✨ → 🌀 → 📬. Honesty rule: ✨ only when the network delivered a real person or opportunity; the moment it fires on anything else, Mazel is a slot machine, the Sensay scar.

### 9.4 The investment layer: sprucing up your portal
Richer portals get more magic, and sprucing up happens by talking to your agent: a richer card; more cards in your web (highest leverage); vouches given; being a bridge; opening your world tier; closing the loop by saying how intros went; connecting another witness (§8.2). Each is something the person does for their own reasons; it happens to make their portal stronger. Rule: sprucing up is never a profile to maintain. No completeness meters, no "60% set up," no nagging. The agent may offer a spruce-up when it notices one would help and never assigns homework.

---

## 10. Go-to-market

### 10.1 Launch definition (Ariel, 2026-09-26) and MDP (2026-09-27)
Launch is a minimal, delightful product with a user-acquisition flywheel: easy to onboard, and the magic shows in minutes. Tests, all against a stranger:
- Onboard: install to a live card in under 10 minutes, card drafted by their agent, the person only confirming.
- Magic in minutes: within the first session, at least one candidate with a plain why (✨), from the relay or a ghost.
- Flywheel: the first session produces at least one invite the person wants to send, and the invitee lands in the same test.
- Delight: the person says something unprompted; screenshots come back unasked.
MDP = hassle-free onboarding + ghosts. Install asks nothing, the card is drafted from witnesses, and on day one the agent holds the people the person knows as ghosts. The first friend test (Dylan, Gary) waits for `v0.5.0-seed` and `v0.5.1-ghosts`. Typing needs and haves is the fallback, never the primary path; a launch where the first thing a person does is type a list fails.
Gate: the Muse listing publishes when three strangers in a row pass all four. Until then it stays unpublished.
North-star metric (proposed 2026-09-27): 🌀 per active portal per week, with ✨ rate and met-continued rate underneath.

### 10.2 Three beachheads, one feature (2026-09-27)
First hundred users come from bounded groups that already trust each other and already have a human router. Each has documents on every member, and the tribe-seed feature (§8.4) serves all three:
1. A TSD partner community; organizer the channel manager, who routes by hand today.
2. A PE fund's portfolio; organizer the operating partner, who routes cross-portfolio selling by spreadsheet.
3. A professional Facebook Group (local business owners, a trade, an alumni network, a franchisee community); organizer the group admin; members already on Muse so the button path is the whole install; member intro posts as the documents.
Muse becomes a tribe you seed, which satisfies the launch gate honestly. Open: which goes first. Public copy never names a specific partner network, fund, or group, and never uses Paragon or PE examples.

Concierge rule (2026-09-14): the first ten are personal messages from Ariel with a screen share on offer; each screen share is product research. Onboarding ends with the person's card URL back. Acquisition flywheel: an unfilled need is the acquisition event; the agent asks the person's inner circle who outside the network might fill it, and the recruit arrives vouched. Early on Ariel routes misses by hand; correct for ten users, wrong for a hundred.

### 10.3 Channels and the record
Muse connector application submitted 2026-09-22 (individual developer; LLC later). Claude custom connectors and ChatGPT developer-mode connectors are one URL. ClawHub skill after the first tribe. Meta acquired Moltbook (launched 2026-01-28, acquired 2026-03-10) for an always-on directory of agents tethered to owners: Mazel's category, marked buyable, with Meta MSL in the room as a funded in-silo competitor. What Moltbook proved: install as a skill file plus one human action; a cadence that keeps the network alive; a watchable public surface. What it lacked: any outcome. Its security (open database, leaked tokens) and its token pump are the counter-example. Watch list: Instinct, Meta MSL/Muse, Claude and GPT native people-finders, copies. Defense: cross-silo habit, cards on user infra, an open spec others implement, speed. Never race an in-silo people-finder on its home field; no lab will federate with rivals, so cross-brain matching stays open to a Switzerland.

### 10.4 Brand and copy rules (2026-09-14)
Palette: Signal #C6FF4A (accent, CTAs on dark, agent presence; fills only), Ink #1A1A1A, Paper #FAFAF7, Mute #8B919A. Poppins headings, Barlow body. Wordmark "Mazel" in a plain confident sans; the wing lockup with a Signal halo over the M is the icon (built from Ariel's wing image, square corners); **Mz** monogram as fallback favicon. Cards render as documents a person holds, never profiles a person performs; handle in contract format everywhere; captions attribute to the human ("what they need"). Approved lines: "Mazel connects two humans for whatever they need through their AI agents"; "Own your brain. Own who you can reach."; "Add Mazel once. Your agent does the rest."; "Found someone you need. Someone needed what you have."; "Agents talk freely. Humans connect only when everyone says yes."; "Connect once. Your agent finds relevant humans."; builders and about only: "A2A moves work. HAAH moves people." One approved line per surface. Say what it is; no em dashes; humans first, agents are the path; plain headers; no coined jargon in user copy. Audience modes friend / partner / builder; HAAH, rpc, heat, TTL are builder vocabulary. No personal names or personal Gmail on product surfaces, cards, WHOIS, or subdomains; doc headers ("personal project for Ariel Jalali") are doc-facing only. Legal pages are bare minimum, adults 18 and over, single contact support@mazel.ai; terms include: if you use Mazel through an AI account your employer provides, you are responsible for complying with your employer's security and data policies and confirm you are permitted to connect that account (2026-09-27). Hebrew depth (Makom, Zman, Lashon or Limud; the twelve tribes and the twelve mazalot) quiet about-page only.

---

## 11. Architecture principles, security, and operating locks

### 11.1 Values and the constraint (2026-09-18)
Three values, used as tests on every choice: **V1 magic, not work** (the user does nothing they would call setup or searching); **V2 sovereign** (no single point a lab can shut off; the user keeps their graph, threads, and outcomes even if Mazel vanishes); **V3 two-way doors** (contracts stable and versioned; insides change freely; avoid one-way doors). Derived constraint every layer obeys: **the user's portal is the sole home of the user's graph, threads, and matches; anything shared is a speed cache that owns nothing.** Preferred substrate: CRDTs plus gossip plus content-addressed cards, over blockchain or a central index.

### 11.2 Components: stable contract, replaceable insides
| Component | Contract | Insides |
|---|---|---|
| Portal | `/card`, `/a2a`, `/mcp`, `/memory` | Cloudflare Worker today; any host or an always-on harness later |
| Connector | A thin tool surface the host agent calls (about 25 tools) | MCP today (Anthropic-originated, industry-adopted); exposable through OpenAI's Apps SDK or a Muse connector spec if they diverge. Noted 2026-09-27 as the one Anthropic-originated dependency in the architecture. |
| Card | A2A v1.0 card with the HAAH extension, a projection of the memory file | Authored from conversation and witnesses; content-addressed later |
| Graph | Local store with a sync interface: known cards with tiers, ghosts, witnessed edges, entities, witnessed acts | KV today; CRDTs for peer sync later |
| Wire | A2A `SendMessage` carrying typed, versioned actions | Types added, never rewritten |
| Decisions | Four sockets: sensing, trust, routing, matching | LLM today; tuned models, graph methods, learned policies later |
| Threads | Need lifecycle: open, collecting, closed, expired | A view of the Need object |
| Verification | Confidence per Have and Need | Witnessed outcomes, weighted vouches, local corroboration |
Not components, by design: a central index or directory (caches only), a Mazel UI (the AI is the interface). Durability test for any change: does it alter a contract or an inside?

One-way doors, named: what a card is (§3.1); the signing key format and rotation; handle resolution as signed records; the Intro `origin` field; the MIT license on the portal kit (public since `v0.4.1`; relay and Rust core licensing is a separate decision); anything public-tier that has touched the relay, since it has been seen.

### 11.3 Stack (Ariel, 2026-09-14)
Two languages plus the Worker. Rust owns types and the ontology (serialized A2A-native by hand). Elixir owns future server-side work: the always-on coordinator for gossip, subscriptions, and pulses across many portals at walk, and any matching or content pipelines; no official A2A SDK, and it arrives when its concurrency model earns its place. JS owns the user-side Worker and `create-mazel`. Python is break-glass only. Every Elixir or Rust change ends with a green `mix compile` or `cargo test` before "done."

### 11.4 Standing locks (2026-09-14, amended)
1. **Install pack trust:** the trusted origin is mazel.ai, npm `create-mazel`, or a signed GitHub Release from `mazelai` with a checksum (checksum deferred by choice at `v0.4.2`; §19.1 of the old spec still wants it). Cloudflare stays an invisible pipe.
2. **Host boundary and the cache principle:** §7.5.
3. **Privacy hygiene:** no personal Gmail or legal names on mazel.ai, cards, WHOIS, or subdomains.
4. **Anti-spam:** every feature ships with its abuse check in the same commit; uploads alone never become a trusted Have; contradictions demote to curious.
5. **OSS thin core:** every feature answers "can a friend run this easily" before merge.
6. **Cross-brain Switzerland:** cards, portals, and install stay brain-portable.
7. **Docs redundancy:** the spec lives on GitHub, in the project, and on Ariel's machine; nothing lives only in an agent harness.
7b. **No surprise publishing (Ariel, 2026-09-28):** nothing the agent reads from a connector reaches the public card without the owner reviewing it. Connector reads default to matched-only (needs) or tribe (haves); the portal rejects any public write without `confirmed: true`. The one thing that would frighten a user is a need from their inbox appearing on their public card; the design makes it impossible.
8. **Security cadence (Ariel, 2026-09-27):** every third tag is a security review and build by a fresh reviewer with no context from the building session; findings ranked with a reproducing test each; all high and medium fixed and added to the security suite before the next feature batch. First: `v0.4.2-sec` (45 checks). Next due after `v0.5.1-ghosts`, and it must cover what a malicious need can learn from a portal's ghost set by probing, and hashed-email resolution.
9. **Builder locks:** done means a real person can run it; harness greens are theater. Blocked means say blocked. Announce before non-chat actions. Foundations only, no throwaways. No cloud agents, farms, or loops without Ariel's OK. One engineer, serial batches, one batch in flight; a fresh reviewer at each tag is the only parallelism.
10. **Model use:** Fable for batches with judgment in them (wire contracts, ontology, anything touching other people's data); Opus for plumbing (installers, docs, CI, security fixes with a spec).
11. **Messaging lives only on the participants' portals (Ariel, 2026-09-28):** Mazel messaging is A2A-native; HAAH adds consent, authorship, tiers, and encryption. No Mazel-run host stores or carries message content; Mazel builds nothing that copies a conversation out; human words pass verbatim. The thread stays independent of intros.
12. **Nothing fabricated reaches a person (Ariel, 2026-09-28):** every match, candidate, yes, and message a person sees exists as a signed object on a portal, with a real human behind it. A fake intro kills user trust and the product (the Moltbook failure). Every batch states how it keeps the agent from inventing matches, yeses, facts, or commitments, and ships a test for it. Mechanisms and the proof-of-yes decision are open in §12.5.

### 11.5 Anti-goals and dead list (permanent)
Mazel hosting anyone's chat or endpoint (messaging between people is in, on their own portals, §11.4 lock 11); LinkedIn-style claim-Has or hop-count; a central user DB of handles; a handle marketplace; coins, ratings, public scores; automating the human vouch; payments-first; vendor scrapers; B2B lead-gen identity; relying on labs for portable inbound; forking A2A; co-founder matching as a use case. Dead theater: demo farms, fixture handles, fake readiness flags, the Option C server, bot swarms, keep-building loops. Spend scar: ~$909 of Cursor on-demand burned by a farm; cap means build carefully, never freeze.

---

## 12. Status and roadmap

### 12.1 Live status (2026-09-27 15:30)
- Shipped and tagged, CI green on both repos: `v0.2.0-friends` (one-hop finding), `v0.3.0-a2a` (A2A v1.0 wire, HAAH extension, clean break), `v0.4.0-fly` (gossip, relay, subscribe, pulse, signing keys, directory), `v0.4.1-install` (OAuth installer, zero questions, welcome page, signed links, public repo, npm, install page), `v0.4.2-sec` (45 security checks).
- Three portals live on three accounts at 0.4.2: Ariel's portal, the test peer, the relay. Two strangers on separate accounts met through the relay at world tier, intro proposed and accepted, `connected` on both sides, both handles resolving through the directory.
- Suites: sec 45, install 55, crawl 54, relay 20, cli 17, identity 16, fly 15, a2a 14, m15 14, live-peer 12. Rust green.
- Open on Ariel: a ChatGPT live run of the signed-link path; the button path on fresh Cloudflare and GitHub accounts, both paths timed; sending Gary the zip; picking the first tribe; deciding recovery and deletion (§3.7).
- Deferred by choice: signed links as 30-minute bearer URLs; no installer checksum.

### 12.2 Stages
- **Crawl** (complete 2026-09-27): security fixes; one-hop finding; threads; card authored from conversation; tiers as a field; outcome objects from day one (correction 2026-09-28: never built; the engineer found none in code; first written in `v0.5.7-thread`, keyed by intro, backfilled for existing intros); failure paths; Rust ontology types; typed action envelope; A2A alignment; one-command install; permanent test peer and CI.
- **Fly** (complete 2026-09-27, pulled ahead of walk): needs reach strangers; all carriers; pulse; identity; directory.
- **Walk** (next): memory file, witnesses, living card, silent needs (`v0.5.0-seed`); ghosts, second hop, witnessed edges, entities, witness check, write-back, tribe seed (`v0.5.1-ghosts`); security (`v0.5.2-sec`); first tribe live, ten 🌀; then levels, noise defenses, vouches, mutual edge upgrade, trust inferred from costly acts (`v0.6.0-trust`); CRDT sync; routing policy learning from outcomes.
- **Run**: cold discovery via DHT or a discardable index; decision sockets filled with the right model each; federated learning; content-addressed cards and signed claims; Mazel invisible under the conversation; proxies retired.

### 12.3 Batch queue (one in flight at a time)
1. `v0.5.0-seed` (shipped 2026-09-27): memory file, tiers and signed pull, witnesses, living card tools, silent needs with hash prefixes, tier-projection tests.
2. `v0.5.1-ghosts` (shipped 2026-09-27): saved contacts from CRM, Gmail, Calendar, LinkedIn export with edge strength; ghost matching as invites; gossip scores against ghosts, owner asked first; salted opt-in hashed-email resolution into local witnessed edges; witness check; evidence-ordered projection with `PUBLIC_HAVES_MAX`; action-based aging; the remove-and-add bug. Test: forty ghosts from fixtures, a cast hits a ghost, a gossip hop hits a ghost on the peer, one real cast on Ariel's portal hits one real ghost.
3. `v0.5.2-sec` (shipped 2026-09-27): fresh reviewer; covered probing of the saved-contact set, hashed-email resolution, the blind-cast path, and per-IP and per-card caps on `/a2a`. Fifteen findings, every high and medium fixed, security suite 52 → 68.
4. `v0.5.3-tribe` (shipped 2026-09-28): Entity and Edge with a registry (Organization by domain, Skill by slug, Tribe by organizer key plus slug; works_at, knows, has_skill, sold_to, met_at, based_in, member_of), entities never leaving the portal, the scorer matching on them. Tribes as entities with actions, built through the same code as needs and haves: flat, tier from shared membership, joining as an intro with `origin: tribe`, leaving silent and never deleted, organizer-first seeding from member documents, organizer sees counts only. CRM write-back on every 🌀, logged by the owner's own agent. Mutual edge upgrade through a signed pull, one yes each. User-facing strings say "someone you already know", never "ghost". Shipped as specified, with two things worth naming: the organizer sends a signed roster (handles and addresses only) to members when someone joins, so a member holds the tribe on day one instead of adding forty cards by hand; and a membership marked public is recorded but not yet published anywhere, because no card carries memberships until a tribe has its own card. Suite: tribe 36. Live on the peer (2026-09-28): a tribe created, five member documents read in and invited straight through, six members with one portal, a need cast, the right member matched on two tags and an edge of 80, and words naming the tribe for the organizer to send by hand — with nothing on any wire.
5. `v0.5.4-rank` (shipped 2026-09-28): fixes from the first live run on Ariel's portal with six real contacts. Ranking by how much of the need someone answers before closeness; matched tags weighted by how rare they are among the owner's own cards and contacts, computed locally and never travelling; the headline leading with people who fit even when none has a portal; `SUGGEST_MIN_EDGE` (config, default 50), below which a contact still matches but is not suggested until the person asks who else; every `invite_text` naming the thread or tribe it is for; a ceiling of 50 drafts a day per portal to catch a loop, with no bulk-invite tool and the person approving who gets one; `tribe_invite` under its own ceiling of 200 a day, above any real seed.
6. `v0.5.5-guard` (shipped 2026-09-28): the installer template refuses to be an update path (a `wrangler deploy` from a clone binds a new empty mailbox and strands the old one, and the guard keys off a local wrangler login so a CI rename cannot break the install button); the `/mcp` token is accepted as an `Authorization: Bearer` header as well as `?token=`; the onboarding description tells the agent to load every contact rather than a sample.
7. `v0.5.6-queue` (shipped 2026-09-28): a daily ceiling queues what it cannot take rather than refusing it, released by the pulse oldest first on the approval already given, with `list_queue`, `clear_queue` and a fortnight's lapse; a relay cast refused by the relay's daily cap stays pending and reads to the owner as waiting, never as an error; a blind cast is re-cast before its 24 hours run out while its need is still open; the pulse reports everything it did rather than only new arrivals; the installer's deploy guard keys off a local wrangler login rather than CI variable names, so a rename by Cloudflare cannot break the install button.
8. `v0.5.7-thread` (2026-09-28, Fable, shipped and live-tested; step 4 the phone ring optional while §12.5 is open): A2A-native threads opening on 🌀, authorship, push subscribe between portals with no bearer, `/inbox` as a Home Screen app, doorbell by web push, reply by link, edge behavior (§4.3b), outcome objects keyed by intro with a timestamped history and backfilled. Live: the peer upgraded; one real intro to 🌀 on both portals with the ask in message one; a message from the peer landing verbatim with a contentless doorbell; a reply by link from Ariel's second address landing as that contact's words; the relay's search holding no thread text. Then `v0.5.7.1-use` (2026-09-28): the fit bar for the world (a have must answer the need; a gossip hit judged on the fetched card), a moved portal re-resolved through the directory and retried through the outbox before the owner hears, test traffic marked `test: true` and cleared by `clear_test_history` (`TEST_HANDLES`), and names-and-why copy without ids. Then `v0.5.7.2-sec` (2026-09-28): the fresh review lock 8 owed, five tags late - one high, four medium, two low; all high and medium fixed with a test each (a block portal-wide; a participant's key only from the card in the intro or thread at open, checked against the directory; delete leaving nothing behind and saying what stays; fresh thread actions and a lapse only an unwritten thread past its window can take; thread traffic under the same caps as everything else); security suite 68 + 29.
9. `v0.5.8-box` (built 2026-09-28, Fable and Opus; reviewed five times by fresh sessions, 28b through 29e, every high and medium fixed with a regression each; untagged until Ariel tags): one need, one thread with a random branch per candidate; tier riding on the branch (§3.6); the box and its four kinds with `DOORBELL_DAILY_CAP`; the ring offer held behind `RING_OFFER` (§12.5); outcomes per branch; the listed surface at nineteen tools; the install file updated in the batch. And the inbound gate: one rule for everything that arrives claiming to be from somebody - signed, fresh, the handle resolved through the directory to its key, the signature checked against it; a card is a person only that way; every id a stranger could compute is random; reply-by-link gated by its MAC. Cost stated: a stranger is a person only while the directory answers. Review 29e (2026-09-29) closed the rule: everything about a handle - key, door, card content, presence in a thread - comes only from something its owner signed or from the directory's record; a card at any other address is at most a pointer; and routing for a third person is off the wire (`router_for` refused in words; a routed intro is two ordinary intros) until item 11. Review 29f (2026-09-29): the gate runs once at the door and a refused action is dropped, never mail; a router-kind `thread.open` is refused outright; a proposal names only a thread its proposer opened; a held-back need's buckets and a tiered pull go only to the circle the owner drew by hand (§3.6, §5.1: a roster-conferred tier matches, nothing more); the outbox re-signs on retry. Six review rounds on one batch: a written reduction plan (`REDUCTION-PLAN-2026-09-29.md`) precedes any further fix.
10. `v0.5.9-seal`: encryption between portals and agent-to-agent scheduling.
11. `v0.5.10-route` (queued 2026-09-29 by review 29e): routing as a signed cast of the person's own. A router's proposal carries the routed-for person's own signed `find.request` - the need as it reached the router - verified through the gate as that handle's; its `needId` is the thread's origin; the person's key, door and card come from `pinIdentity`, never from the router; the three-party thread, the router's offer to leave after the first reply, and router credit on the outcome return with it. Until then a routed intro is two ordinary intros and no proposal names a third person.
12. First tribe live. Ten 🌀. Bug fixes only until then.
13. `v0.6.0-trust`: levels, noise defenses, vouches, thresholds tuned from the tribe.
14. HAAH v1 published as a spec page from the code, with a conformance test anyone can run.
Every batch ends with a live test in plain words and a tag. Release rhythm: internal releases ship freely to Ariel's portal; friend releases ship at milestones with a generated changelog; friends update with one command.

### 12.4 Technical debt (watched)
Scorer inlined into portal and relay at build (fold into the Rust core at walk). KV read lag drives 60-second waits in tests (Durable Objects later). Token files on Ariel's Mac (password manager is the right home). Wrangler's OAuth client borrowed. The Elixir tree sits unused in the private repo. Two repos to keep in sync (private `mazelai/mazel`, public `mazelai/portal`, mirrored by script). Signed links are bearer URLs. No checksum on the installer.

### 12.5 Parked (the only list; the Wednesday reminder reads it)
- **Nostr as a carrier** (stubbed). Reopen when the relay is a bottleneck.
- **Fingerprint vector layer** (§3.6). After hash prefixes prove out; one vector per persona.
- **Personas as lenses over one memory** (§3.5). With the memory file's second iteration: one corpus, projection rules per persona, consent per lens, matching across all. Watch for the Muse angle: Meta's users already live every persona in one account.
- **Private set intersection** for matched-only inside a tribe. After hash prefixes.
- **LinkedIn coherence score** (§8.3). Walk.
- **Company-level needs** beyond ping-through-strongest-edge; company cards as Organization portals (§6.5). Walk.
- **Mutual witnessed-edge upgrade** (§6.5). `v0.6.0-trust`.
- **Notification beyond the pulse badge line.** Unparked 2026-09-28: the doorbell ships with `v0.5.7-thread` (§4.3b).
- **Sovereign AI messaging** (Ariel, 2026-09-28). Pivot option the thread design keeps open: threads without intros, portals runnable outside Cloudflare, identity on the owner's own domain, encryption between portals, the open protocol. Trigger: a government or regulated buyer asks, or macro pressure on US AI providers.
- **How Mazel rings people (open, Ariel sitting with it, 2026-09-28).** Options on the table: web push from `/inbox` as a Home Screen app (built in `v0.5.7`, friction); a scheduled task in the person's AI (depends on labs; Ariel: a hack); email notification from a Mazel-run notifier holding one address per user, contentless (scales; changes the privacy line to "Mazel holds only where to ring you"); a thin Mazel phone app with real push (scales; reverses §1 "no interface of its own"). Decide before `v0.5.8-box` ships its ring offer.
- **Preventing fake intros (open, Ariel, 2026-09-28: park and think; "or we turn into Moltbook").** Sources: the owner's AI narrating matches or details no tool returned (check tonight's "Tuesdays work" line against the peer's actual notes); the AI saying yes for its human through `respond_intro`; agents inventing facts or commitments in branches; portals with no human behind them. Candidate defenses: the portal is the only truth and the box shows only signed objects; tools return exact wording plus an object reference; the why shows the scorer's matched tags; agents in branches cite a source for every fact and never commit; unclaimed, unwitnessed, outcome-less portals cannot reach strangers; a fabrication test suite against real Claude and ChatGPT every release. Open decision: proof of a yes (chat yes, a tap in the box, or chat yes for known people and a tap for strangers, shown to both sides).
- **Recovery and deletion** (§3.7). Decide before the first tribe.
- **Business model.** No decision before the first tribe; the attribution receipt is the only hook named.
- **Group rooms.** Until Ariel asks.
- **Public card as an evidence-ordered projection.** `PUBLIC_HAVES_MAX` in config (default 6), haves ordered by witness count and recency, N raised by level once levels ship. Queued for `v0.5.1-ghosts`.
- **Copilot for business users.** Copilot's connector model is enterprise-admin-gated, so install is an admin decision, witnesses are Microsoft 365 (Outlook, Teams, Dynamics), and the endpoint rule holds. Same shape as the Muse beachhead: the organizer is the admin. Reopen when a tribe organizer runs a Microsoft shop. Terms carry the employer-policy sentence (2026-09-27).
- **Trust modes** (the old Unsecured / Basic / Stronger): overtaken by signing keys; restate or retire when deal details start traveling.
- **Wings promotion** in the wordmark: decided in favor (the icon is the wing); easter eggs still come later and are never emoji commands.
- **Muse listing**: submitted, unpublished until the launch gate.
- **Gmail send-as, SPF, DKIM for mazel.ai; iwantmyname payment method; LLC (Ariel, 2026-09-28: not until Mazel has users beyond friend testers); Cursor and Grok credential revocation; moving a2a.mazel.ai's CNAME target if the Pages name ever changes.**

---
## Appendix A. Professional use cases (WIP, 2026-09-27)

Status: working list, ranked by value per meeting, how badly today's tools serve it, and how well an agent-brokered, consent-first intro fits. Nothing here is validated by a user yet. Revisit after the first tribe produces ten 🌀 and reorder by what actually happened.

| # | Use case | Value per meeting | Frequency | Failure of today's tools | Mazel fit |
|---|---|---|---|---|---|
| 1 | Warm intro to a buyer | Highest | Medium | LinkedIn shows the path and does nothing; the human ask is awkward and mostly never sent | The middle person's agent asks; yes or no with no social cost (§6.5) |
| 2 | Hiring by vouch | High | Medium | Recruiters spam; boards return the wrong people; the best candidate is open but not looking | Need travels only to corroborated haves and comes back with a why |
| 3 | Expert for an hour | Medium | High | Expert networks cost hundreds per call and gatekeep | The expert's agent decides whether to bother them |
| 4 | Deal and channel partners | High | High | Referral partners, co-bidders, subcontractors found by luck; no credit for routing | Symmetric have and need; outcome objects give the router credit; strongest met-continued loop |
| 5 | Capital, both directions | Highest | Low | Cold pitches die; warm paths depend on who you already know | Vouches matter more here than anywhere |
| 6 | Customer references and peer advice | Medium | High | Buyers want a peer who switched; vendors gatekeep references | Agents route around the vendor |
| 7 | Advisors and board seats | High | Low | Cold outreach; long relationships started badly | Tribe-tier vouches and corroborated history |
| 8 | Speaking, podcast, press guests | Low | High | Booking agencies and guest platforms, pay to play | Host need meets guest have; every 🌀 is public proof |
| 9 | Local professional peers | Medium | Medium | "Another agency owner in Denver" exists and nobody sees each other | The Waze insight: the people are already there |

Notes, WIP:
- 1 and 2 are the pitch. 4, 6, and 9 produce the most 🌀 per week, which the levels and the flywheel need first. Launch prompts come from 4, 6, and 9; the story from 1 and 2.
- Co-founder matching considered and cut (Ariel, 2026-09-27).
- Beachheads (§10.2) map onto this list: TSD partners on 4 and 1; PE portfolios on 4, 1, and 6; a professional Facebook Group on 9, 6, and 3.
- Where LinkedIn and social structurally fail: the ask (the path is shown, the message is never sent); private needs (you cannot post "open to leaving" or "quietly raising"); not-looking people; timing (needs last weeks, profiles last years); trust (self-reported, gamed); noise; dormant ties; no closed loop; cross-platform. The first two are the pitch, since a visibility-funded network cannot fix them.
- Open questions: which row the first tribe's needs fall into; whether 3 and 6 need a lighter shape (a question answered, no meeting); whether 5 needs a stricter tier default; what persona × moment (§3.5) does to rows 1 and 5.
- Evidence to gather: referral versus cold conversion, recruiter fee norms, expert-network pricing, partner-sourced revenue shares, warm-intro versus cold-pitch success for capital.

---

## Appendix B. Assets and accounts

| Asset | Location | State (2026-09-27) |
|---|---|---|
| Private repo | github.com/mazelai/mazel | Spec, portal, relay, Rust crates, recovered Elixir tree (unused), docs (CLOUDFLARE-TOKEN.md, GIT-DEPLOY.md) |
| Public repo | github.com/mazelai/portal | Portal, relay, LICENSE (MIT), README with the Deploy button; mirrored from private by script |
| npm | `create-mazel@0.4.2`, org `mazelai`, user `mazelhq`, email mazel@mazel.ai | Live; installer verified from the registry |
| Install page | mazel.ai/install (Squarespace, hidden from search) | Live; agent-readable |
| Legal and docs pages | mazel.ai/privacy, /terms, /docs | Live; bare minimum, adults 18 and over, support@mazel.ai |
| Mazel card host | a2a.mazel.ai (Cloudflare Pages `mazel-a2a`, Company account; iwantmyname CNAME) | Live on the v0.3.0 A2A shape; company have and need; no personal names |
| Human site | mazel.ai (Squarespace); mazal.ai redirects | Live |
| Mail | Zoho on mazel.ai: ariel@, mazel@ (alias), support@, hello@, privacy@, legal@; forwards to Gmail | Live; SPF and DKIM pending |
| Friend zip | `~/mazel-for-friends.zip` (CHANGELOG, README, MAZEL.md, screenshots) | Rebuilt at each friend tag; superseded by `npx create-mazel` |
| Icons | mazel-icon-512.png, mazel-icon-512-signal.png, mazel-wing-transparent.png | Signal version used on the Muse form |
| Muse | Connector application submitted 2026-09-22, individual developer | Pending; listing unpublished until the launch gate |
| Cloudflare accounts | §7.7 | Three, one token each |
| Recovery archives | mazel-codebase.zip (culled), full recovery archive (1,463 files), Chief 5-zip export | Backups; revoke Cursor and Grok access at will |
| Scheduled tasks | Wednesday 9am PT parked-items reminder; Sunday 9am PT product review | Read `claude/MAZEL-SPEC.md` in the project |

---

## Appendix C. History (superseded; kept so nothing is lost)

**Names retired (2026-09-14, 2026-09-18):** door → portal; morph → connect (retired in code too); postage → badge (and the badge as a gate for crossing into world is superseded by levels and corroboration, §5.3); session → room; soft-no → pass; warm packet → intro note; double magic → the mutual why; communities of belonging → tribes; heartbeat → pulse (2026-09-27); founder card → the Mazel card; "conventions: haah" → the HAAH extension URI; SPEC-COMPREHENSIVE.md → MAZEL-SPEC.md. Grok-era terminology (Chief, mix demo farm, LOOK harness) is dead.

**The 2026-09-14 card contract** (`{handle, url, rpc, protocol: "a2a", conventions: ["haah"], need[], have[]}`) and its wire (`message/send` with `parts[{kind:"text"}]` and `metadata{handle, cardUrl}`) were replaced by the A2A v1.0 shape at `v0.3.0-a2a` with a clean break. Rules that carried over: rpc and url are different paths; never invent a host; `rpc_none` is valid.

**The M-plan (2026-09-14):** M0 ground truth on GitHub (done); M1 founder portal live (done); M1.5 live-editable card via `update_card` (done 2026-09-18); M2 second person and v0.1.0 (superseded by `v0.2.0-friends`); M3 spine health (Elixir compile gate; deferred with the Elixir tree); M4 hardening (token off the homepage, delivery confirmed, rate limits: done across `v0.2.0` and `v0.4.2-sec`; badge gate option: superseded); M5 first tribe (now §10.2 and the batch queue). The wrangler-first one-command install parked on 2026-09-14 shipped 2026-09-22.

**The phase roadmap (Grok era, revised 2026-09-14):** Phase 0 friend-can-try; Phase 1 need snooze and filter (now the three-moment rule and tiers); Phase 2 proof-Has and wiki person-slices and deterministic quant (now witnesses, the memory file, and §5.5); Phase 3 chat fingerprint / DNA-match router and communities of belonging (now §3.6 fingerprint and tribes); Phase 4 trust modes Unsecured / Basic / Stronger with dotenvx-shaped sealed payloads (parked, overtaken by signing keys); Phase 5 federated card directory (now §6.4), router chain cases (hidden have, unknown router, unclear need: now second-hop ghosts and the clarifying hop), group chat (parked), Hebrew depth (§10.4), versioning on tags.

**Install doctrine v1 (2026-09-14):** the staged paste (card first, portal second, wake third, find fourth) and FRIEND_PASTE_V2, AGENT_ONBOARD.md, the dashboard KV-binding path, and the setup page that showed the token to the first visitor (closed at `v0.2.0`). Replaced by §8.1.

**Lab blockers table (2026-09-14):** chat UIs cannot deploy inbound from a thread (mitigated by the button and OAuth installer); connector friction (solved, one URL); no wake-on-inbound (solved by scheduled tasks plus the mailbox); ToS on agent-to-agent contact (watch); in-silo people-finder competition (active, §10.3); labs won't vouch a Worker is "@sam" (answered by witnesses and vouches); rate limits and ephemeral sessions (the mailbox absorbs it); ChatGPT consumer connectors read-only (answered by signed links). Never depend on labs shipping portable inbound doors.

**Open questions from 2026-09-14, resolved:** stranger gate default (open; levels and config thresholds); repo public timing (`v0.4.1`); the Claude-coding weekend (moot; the engineer ships nightly); first-visit token window (closed); when wings graduate (the icon is the wing).

**Handoff draft (2026-09-28, withdrawn the same night):** routes revealed on yes, first email from the owner's own inbox, agents step out. Replaced by the thread (§4.3b) when Ariel chose Mazel as the messaging layer. "Becoming a messenger" left the anti-goal list the same day; Option C stays rejected because messages live on the participants' portals, never in the middle.

**Product module map (2026-09-14):** Install, A2A, Match, Room, Consent, Trust, Growth. Internal names; friend copy says Mazel.

**Discovery architecture document (2026-09-18, `DISCOVERY-ARCHITECTURE.md`):** folded into §6 and §11; the standalone file is history.

**Stack rationale (2026-09-14):** what killed the previous effort was theater incentives, building the rejected Option C server, and no git remote; the language got minor blame. Elixir's BEAM advantages become load-bearing at scale; AI coding assistance is stronger in TS and Python; the mitigations were a compile gate and code in pushed git from day one.

**Muse acquisition thought experiment (2026-09-19):** discussed, not a plan; only the LinkedIn export item was parked from it. Moltbook's acqui-hire pattern and the Peter/OpenClaw outcome are on the record as category validation.
