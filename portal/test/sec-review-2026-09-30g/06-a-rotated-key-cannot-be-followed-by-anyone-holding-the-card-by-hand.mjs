// MEDIUM. pinIdentity() (index.js ~4134-4140) answers from a card held by hand before it asks the
// directory, and pinCard()'s identity path (~2467) refuses any key that differs from the held one,
// even when resolveHandle() has just verified the rotation chain that leads to it. So after a
// person rotates (rotate_key: "peers that remember the old key re-resolve and follow the chain"),
// every portal that holds their card by hand - their tribe, their inner circle, the people who
// pasted their link - refuses everything they sign: proposals and answers die as "refused" in the
// sender's outbox, thread messages are "not signed by that participant", and `cards add` by handle
// says no rotation chain exists. Only re-pasting the card url by hand recovers, one holder at a time.
import { addPortal, call, J, ok, done, portals, worker, relayReplies, mail, pulse, lastIntro, keys } from '../sec-review-2026-09-28/_harness.mjs';

const A = 'https://alice-g6.test', B = 'https://bob-g6.test';
addPortal(A, 'alice@mazel'); addPortal(B, 'bob@mazel');
await call(B, 'update_card', { add_have: 'fractional-cfo', witnesses: ['hubspot'], confirmed: true });
await call(A, 'add_known_card', { url: B + '/card' });
await call(B, 'add_known_card', { url: A + '/card' });   // bob holds alice by hand, at tribe
const before = keys(B, 'known:').map((k) => JSON.parse(portals[B].MAILBOX.m.get(k))).find((c) => c.handle === 'alice@mazel');

const rot = await call(A, 'rotate_key', { confirmed: true });
ok('precondition: alice rotated, the record is published with the chain', /Key rotated/.test(rot));
for (const [o, n] of [[A, 'alice'], [B, 'bob']]) relayReplies.directory[n] = await (await worker.fetch(new Request(`${o}/.well-known/mazel/${n}.json`), portals[o])).json();
ok('(the directory record carries one rotation)', relayReplies.directory.alice.rotations.length === 1);

const f = await J(A, 'find', { need_text: 'a fractional cfo', tags: ['fractional-cfo'] });
const said = await call(A, 'propose_intro', { thread_id: f.thread_id, card_url: f.candidates[0].card_url, confirmed: true });
const introId = lastIntro(A, 'bob@mazel');
ok('a proposal signed with the rotated key is taken by a portal holding the old one', !!portals[B].MAILBOX.m.get('intro:' + introId), said.slice(0, 140));
// The outbox waits a minute before its first retry; move the clock rather than wait.
for (const k of keys(A, 'outbox:')) { const o = JSON.parse(portals[A].MAILBOX.m.get(k)); o.nextAt = new Date(0).toISOString(); portals[A].MAILBOX.m.set(k, JSON.stringify(o)); }
await pulse(A);
const told = (await mail(A)).find((m) => m.mine && /could not be delivered/.test(m.text || ''));
ok('alice\'s owner is not told bob refused it', !told, told ? told.text.slice(0, 160) : '');

const add = await call(B, 'cards', { action: 'add', handle: 'alice@mazel' });
ok('cards add by handle follows a verified rotation chain', /Refreshed|Added/.test(add), add.slice(0, 200));
const after = keys(B, 'known:').map((k) => JSON.parse(portals[B].MAILBOX.m.get(k))).find((c) => c.handle === 'alice@mazel');
ok('the held key moved to the new one', after && after.publicKey !== before.publicKey && after.publicKey === relayReplies.directory.alice.publicKey, `held ${String(after && after.publicKey).slice(0, 12)}…, record ${relayReplies.directory.alice.publicKey.slice(0, 12)}…`);
// What does recover: pasting the url again by hand, which the person has to do at every holder.
const byUrl = await call(B, 'cards', { action: 'add', url: A + '/card' });
ok('(re-pasting the url by hand is the one road that follows the chain)', /Refreshed/.test(byUrl), byUrl.slice(0, 100));
done();
