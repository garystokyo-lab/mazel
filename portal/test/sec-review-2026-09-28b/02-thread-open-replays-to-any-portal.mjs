// H2. The thread.open wire message is signed by the opener but is NOT bound to its recipient.
// onThreadOpen()'s need path (index.js) verifies the signature, the freshness window (2 days) and
// the sender's pinned key, and then hands the action straight to onNeedBranch(), which builds the
// conversation out of `me` and the sender and never looks at action.participants. The router path
// a few lines below does check `named.some(p => p.handle === me.handle)`; the need path does not.
// So anyone who sees one branch-open - the named recipient of a DIRECTED need, a proxy, a log -
// can replay it verbatim at any other portal for 48 hours, and that portal will screen it, open a
// branch and put "Someone needs what you have" in its owner's box, carrying the need's words.
import { addPortal, call, J, ok, done, portals, wire } from '../sec-review-2026-09-28/_harness.mjs';
import worker from '../../src/index.js';

const A = 'https://alice2.test', B = 'https://cal2.test', C = 'https://carol2.test';
addPortal(A, 'alice@mazel');
addPortal(B, 'cal@mazel');
addPortal(C, 'carol@mazel');

const SECRET = 'a replacement CFO for Northwind before the board hears about it';

for (const p of [B, C]) await call(p, 'update_card', { add_have: 'fractional-cfo', confirmed: true });
await call(A, 'add_known_card', { url: B + '/card' });
await call(C, 'add_known_card', { url: A + '/card' });   // Carol holds Alice's card, as any contact might

await call(A, 'update_card', { add_need: 'directed-cfo', need_visibility: 'directed', need_to: 'cal@mazel' });
wire.length = 0;
await J(A, 'find', { need_text: SECRET, tags: ['directed-cfo', 'fractional-cfo'] });

// The one branch-open Alice's portal put on the wire, for cal@mazel only.
const sent = wire.filter(w => w.url === B + '/a2a' && w.body.includes('thread.open'));
ok('the directed branch-open went only to the named recipient', sent.length === 1, String(sent.length));
const open = JSON.parse(sent[0].body);
ok('that open carries the need\'s words', JSON.stringify(open).includes('Northwind'));

// Replay it, byte for byte, at a portal the need never named.
const before = [...portals[C].MAILBOX.m.keys()].filter(k => k.startsWith('conv:')).length;
await worker.fetch(new Request(C + '/a2a', { method: 'POST', headers: { 'content-type': 'application/json' }, body: sent[0].body }), portals[C]);
const convs = [...portals[C].MAILBOX.m.entries()].filter(([k]) => k.startsWith('conv:')).map(([, v]) => JSON.parse(v));
const box = [...portals[C].MAILBOX.m.entries()].filter(([k]) => k.startsWith('msg:')).map(([, v]) => JSON.parse(v)).filter(m => m.box);
const sawWords = [...portals[C].MAILBOX.m.values()].some(v => String(v).includes('Northwind'));

ok('a replayed thread.open must not open a branch at an unnamed portal', convs.length === before,
   `carol now holds ${convs.length} branch(es): ${JSON.stringify(convs.map(c => c.participants.map(p => p.handle)))}`);
ok('a replayed thread.open must not put an item in an unnamed portal\'s box', box.length === 0,
   JSON.stringify(box.map(b => b.text)));
ok('a directed need\'s words must not reach an unnamed portal', !sawWords);

if (convs.length > before || box.length || sawWords) {
  console.log(`FAIL thread.open is unbound: the signed open Alice sent to cal@mazel was replayed at carol@mazel, which opened branch ${convs[0].contextId} and boxed: "${(box[0] || {}).text || ''}"`);
}
done();
