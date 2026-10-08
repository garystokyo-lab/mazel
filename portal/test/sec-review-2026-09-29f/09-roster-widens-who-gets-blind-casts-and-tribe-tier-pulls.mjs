// LOW (recorded by 29e as designed; scripted here because the consequence was not). onTribeRoster()
// (index.js ~3588-3603): a tribe organizer's signed roster adds every listed handle as a tribe-tier
// card on each member's portal - key and door from the directory, content from the record's card
// (28d, 29e), so nothing about the person is fabricated. What the organizer's word decides is who is
// at TRIBE TIER on a member's portal, and two things key on exactly that:
//   - castBlindNeed() (~3355) sends the member's matched-only fingerprints to every non-world card,
//     which §3.6 justified as "the circle that already knows the person";
//   - tierForPull() (~5432) serves the member's tribe-tier haves and persona to any signed pull from
//     a card held at tribe.
// So an organizer lists any real handle with a directory record - a competitor, a journalist, a
// stranger - and that person receives the member's held-need buckets on the next pulse and can pull
// the member's tribe-only card, without the member choosing either. The member said yes once, to
// the organizer, to join.
import { addPortal, call, J, ok, done, portals, worker, relayReplies, signingOf, signWith, a2a, noteMsg, keys, wire, pulse } from '../sec-review-2026-09-28/_harness.mjs';

const O = 'https://org-f9.test', M = 'https://member-f9.test', X = 'https://x-f9.test';
addPortal(O, 'org@mazel'); addPortal(M, 'member@mazel'); addPortal(X, 'x@mazel');
for (const [o, n] of [[O, 'org'], [M, 'member'], [X, 'x']]) relayReplies.directory[n] = await (await worker.fetch(new Request(`${o}/.well-known/mazel/${n}.json`), portals[o])).json();
await call(O, 'add_known_card', { url: M + '/card' });
await call(M, 'add_known_card', { url: O + '/card' });
// The member joins the organizer's tribe the ordinary way: an invitation, and one yes.
const created = await call(O, 'tribe_create', { name: 'Health Systems Circle', purpose: 'operators who trade notes' });
const tribeId = created.match(/Its id is (\S+) and/)[1];
await call(O, 'tribe_invite', { tribe_id: tribeId, handle: 'member@mazel', confirmed: true });
const inviteId = keys(M, 'intro:').map((k) => JSON.parse(portals[M].MAILBOX.m.get(k))).find((i) => i.tribeId === tribeId).id;
await call(M, 'respond_intro', { intro_id: inviteId, decision: 'accepted', confirmed: true });
ok('precondition: the member is in the tribe', keys(M, 'edge:').length > 0);

// The member holds one thing back, and one thing at tribe tier.
await call(M, 'update_card', { add_have: 'northwind-turnaround', have_visibility: 'tribe', witnesses: ['gmail'], confirmed: true });
await call(M, 'update_card', { add_need: 'fractional-cfo', need_visibility: 'matched-only' });
await J(M, 'find', { need_text: 'a replacement CFO for Northwind before the board hears about it', tags: ['fractional-cfo'] });

// The organizer rosters x - a real handle with a real record, never invited, never asked.
const os = await signingOf(O);
const roster = await signWith(os, { v: 1, type: 'tribe.roster', handle: 'org@mazel', publicKey: os.pub, cardUrl: O + '/.well-known/agent-card.json', rpc: O + '/a2a', castAt: new Date().toISOString(),
  tribeId, tribeName: 'Health Systems Circle', members: [{ handle: 'x@mazel', cardUrl: X + '/.well-known/agent-card.json', rpc: X + '/a2a' }] });
await a2a(M, noteMsg('Health Systems Circle: 1 member to hold.', { handle: 'org@mazel', cardUrl: O + '/.well-known/agent-card.json', action: roster }));
const xCard = (await J(M, 'list_known_cards')).find((c) => c.handle === 'x@mazel');
ok('precondition: x is now a tribe-tier card on the member\'s portal, on the organizer\'s word', !!xCard && xCard.tier === 'tribe', xCard ? `tier ${xCard.tier}, rpc ${xCard.rpc}` : 'not held');

// Next pulse: the member's held need goes out as buckets to "the circle that already knows them".
wire.length = 0;
await pulse(M);
const blindToX = wire.filter((w) => w.url === X + '/a2a' && /find\.blind/.test(w.body));
ok('a member\'s held-need buckets go only to cards the member chose to hold that close', !blindToX.length, `${blindToX.length} blind cast(s) at x's door on the pulse`);

// And x, held at tribe, can pull the member's tribe-only card with a signature of their own.
const xs = await signingOf(X);
const e = Date.now() + 60000;
const pull = await signWith(xs, { as: 'x@mazel', e, at: M });
const card = await (await worker.fetch(new Request(`${M}/card?as=x%40mazel&e=${e}&sig=${encodeURIComponent(pull.sig)}`), portals[M])).json();
const have = ((card.capabilities || {}).extensions || [{}])[0].params ? card.capabilities.extensions[0].params.have : [];
ok('a tribe-only have is served only to someone the member put at tribe', !(have || []).includes('northwind-turnaround'), `x pulled: have ${JSON.stringify(have)}, held at ${card.mutual && card.mutual.youAreHeldAt}`);
done();
