// MEDIUM. handleSend() (index.js ~672): every sender the gate verifies and does not already hold is
// pinned at world tier through pinCard - one signed note is enough. findInKnownCards() (~2772-2775)
// then scores that card like one the owner chose: score >= 2 with any matched have, no strongFit(),
// which searchRelay() (~3382) applies to strangers precisely because "a card the person holds can
// get in on a gloss that shares a couple of words with the need: they chose to hold it. A stranger
// from the relay cannot." So a stranger with a directory record and a gloss stuffed with common
// words sends one note to a portal and is a ✨ candidate for its next public need, with a branch
// opened, the need's words sent to their door, and "Found someone" in the box - a fit the relay
// path would have dropped.
import { addPortal, call, J, ok, done, portals, worker, relayReplies, mail, keys, wire, stubs, R } from '../sec-review-2026-09-28/_harness.mjs';

const B = 'https://bob-g3.test', S = 'https://stranger-g3.test';
addPortal(B, 'bob@mazel'); addPortal(S, 'stranger@mazel');
await call(S, 'update_card', { persona: 'I book guests.', add_have: 'podcast-guest', witnesses: ['hubspot'], gloss_tag: 'podcast-guest', gloss_text: 'hospital group finance stories', confirmed: true });
for (const [o, n] of [[B, 'bob'], [S, 'stranger']]) relayReplies.directory[n] = await (await worker.fetch(new Request(`${o}/.well-known/mazel/${n}.json`), portals[o])).json();
ok('precondition: bob holds nobody', !keys(B, 'known:').length);

// One note. Not a proposal, not a hit: a note.
await call(S, 'send_to_peer', { rpc: B + '/a2a', text: 'Hello from a podcast booker.' });
const held = keys(B, 'known:').map((k) => JSON.parse(portals[B].MAILBOX.m.get(k)));
ok('(the note made bob hold the stranger\'s card, at world)', held.length === 1 && held[0].tier === 'world', JSON.stringify(held.map((c) => [c.handle, c.tier, c.tierByHand])));

wire.length = 0;
const f = await J(B, 'find', { need_text: 'a fractional CFO for a hospital group', tags: ['fractional-cfo'] });
const cand = (f.candidates || []).find((c) => c.handle === 'stranger@mazel');
ok('a card that drifted in on a note is held to the stranger\'s bar (strongFit), not the chosen card\'s', !cand, cand ? `rank ${cand.rank}, tier ${cand.tier}, via ${cand.via}, matched ${JSON.stringify(cand.matched)}, score ${cand.score}: ${cand.why}` : '');
const open = wire.find((w) => w.url === S + '/a2a' && /thread\.open/.test(w.body));
ok('the need\'s words do not go to a stranger the owner never chose', !open, open ? 'thread.open at the stranger\'s door carrying: ' + (JSON.parse(open.body).params.message.metadata.action.note.parts[0].text || '').slice(0, 80) : '');
const box = (await mail(B)).find((m) => m.box && m.box.kind === 'found_for_you');
ok('no ✨ for a gloss-word fit with someone who merely wrote in', !box, box ? box.text.slice(0, 120) : '');
// For contrast: the same card, offered by the relay to a portal that does not hold it, meets strongFit and is dropped.
const C = 'https://carol-g3.test';
addPortal(C, 'carol@mazel');
stubs.push({ test: (u) => u.startsWith(R + '/search'), reply: async () => new Response(JSON.stringify({ results: [{ handle: 'stranger@mazel', cardUrl: S + '/.well-known/agent-card.json' }] }), { headers: { 'content-type': 'application/json' } }) });
const g = await J(C, 'find', { need_text: 'a fractional CFO for a hospital group', tags: ['fractional-cfo'] });
ok('(for contrast: the relay offering the same card to a portal that never heard from it is dropped by strongFit)', !(g.candidates || []).some((c) => c.handle === 'stranger@mazel'), JSON.stringify((g.candidates || []).map((c) => c.handle)));
done();
