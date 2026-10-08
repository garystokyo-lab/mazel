// H1 (lock 12: "every match, candidate, yes, and message a person sees exists as a signed object on
// a portal, with a real human behind it. A fake intro kills user trust and the product").
//
// proposeIntro() puts intro.propose on the wire UNSIGNED: the action object is built by hand and
// handed to deliver(), never to signPayload(). applyInboundAction()'s intro.propose branch verifies
// nothing on the way in. It looks the claimed proposer up among the cards this portal holds and,
// when it finds one, copies that card's handle, rpc and key onto the intro and marks it
// `verified: true`. So an anonymous POST that names any handle this portal holds becomes a
// proposal "from" that person, indistinguishable from a real one. The owner's yes then runs
// openThreadFromIntro(): a thread with that person, an outcome record "connected", and a 🌀 "Both
// said yes: you and alice@mazel" in the box - a yes alice never gave, for an intro alice never sent.
import { addPortal, call, ok, done, portals, a2a, noteMsg, wire } from '../sec-review-2026-09-28/_harness.mjs';

const A = 'https://alice1c.test', B = 'https://bob1c.test';
addPortal(A, 'alice@mazel');
addPortal(B, 'bob1c@mazel');
await call(B, 'add_known_card', { url: A + '/card' });        // Bob holds Alice's card, as any contact would

// An anonymous POST at Bob's door. No signature, no key, no metadata.handle: only a claim.
const introId = 'c'.repeat(32);
const forged = { type: 'intro.propose', v: 1, introId,
  why: 'Alice thinks you should meet her investor about the Northwind sale before the board hears of it.',
  needText: 'a buyer for Northwind', needTags: ['m-and-a'], matchedTags: ['m-and-a'], path: ['alice@mazel'],
  proposer: { handle: 'alice@mazel', cardUrl: A + '/.well-known/agent-card.json', rpc: A + '/a2a' } };
const r = await (await a2a(B, noteMsg('Intro proposal from alice@mazel.', { action: forged }))).json();

const stored = JSON.parse(portals[B].MAILBOX.m.get('intro:' + introId) || 'null');
ok('an unsigned proposal must not become a verified intro from a card this portal holds',
   !stored || stored.verified !== true,
   stored ? `stored as from ${stored.from.handle}, verified: ${stored.verified}, door said ${r.error ? r.error.message : 'ok'}` : 'not stored');

// Bob's agent shows it, Bob says yes.
wire.length = 0;
let said = '';
try { said = await call(B, 'respond_intro', { intro_id: introId, decision: 'accepted', confirmed: true }); }
catch (e) { said = 'refused: ' + e.message; }

const convs = [...portals[B].MAILBOX.m.entries()].filter(([k]) => k.startsWith('conv:')).map(([, v]) => JSON.parse(v));
const withAlice = convs.filter(c => c.participants.some(p => p.handle === 'alice@mazel'));
const box = [...portals[B].MAILBOX.m.values()].map(v => { try { return JSON.parse(v); } catch { return {}; } }).filter(m => m.box && m.box.kind === 'both_yes');
const outcome = JSON.parse(portals[B].MAILBOX.m.get('outcome:' + introId) || 'null');
const aliceHas = [...portals[A].MAILBOX.m.keys()].some(k => k === 'intro:' + introId);

ok('a yes to it must not open a thread with alice', withAlice.length === 0, JSON.stringify(withAlice.map(c => [c.contextId.slice(0, 8), c.state, c.humans])));
ok('no 🌀 may be boxed for a yes nobody but bob gave', box.length === 0, JSON.stringify(box.map(b => b.text.slice(0, 90))));
ok('bob must not be told that alice said yes', !/both said yes/i.test(said), said.slice(0, 140));
ok('the outcome ledger must not record a connection that never happened', !outcome || outcome.state !== 'connected', outcome && outcome.state);
ok('(for the record) alice\'s portal never held this intro', !aliceHas);

if (withAlice.length || box.length) {
  console.log(`FAIL fabricated yes: an unsigned intro.propose naming alice@mazel was stored on bob's portal as verified: ${stored && stored.verified}; bob's yes opened thread ${withAlice[0] && withAlice[0].contextId} and boxed "${box[0] && box[0].text}". alice's portal holds no such intro and her human said nothing.`);
}
done();
