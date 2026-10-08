// LOW. openBranch() (index.js ~4665) gives the branch's other participant a key only from a card
// held above world; a candidate held at world - pinned by the gate on a note, or from a relay
// result - is in the branch with publicKey null although pinCard stored the record's key for them.
// thread_block (~1640) writes a block only for a participant with a key, so blocking that branch
// writes nothing: the tool says "Everything from that portal is refused from now on - this thread,
// notes, proposals, needs", and the next note from that portal lands as usual.
import { addPortal, call, J, ok, done, portals, worker, relayReplies, keys, mail } from '../sec-review-2026-09-28/_harness.mjs';

const B = 'https://bob-g5.test', S = 'https://stranger-g5.test';
addPortal(B, 'bob@mazel'); addPortal(S, 'stranger@mazel');
await call(S, 'update_card', { add_have: 'fractional-cfo', witnesses: ['hubspot'], confirmed: true });
for (const [o, n] of [[B, 'bob'], [S, 'stranger']]) relayReplies.directory[n] = await (await worker.fetch(new Request(`${o}/.well-known/mazel/${n}.json`), portals[o])).json();
await call(S, 'send_to_peer', { rpc: B + '/a2a', text: 'Hello.' });
const held = keys(B, 'known:').map((k) => JSON.parse(portals[B].MAILBOX.m.get(k)))[0];
ok('precondition: the stranger is held at world with the record\'s key', held && held.tier === 'world' && !!held.publicKey);
const f = await J(B, 'find', { need_text: 'a fractional cfo', tags: ['fractional-cfo'] });
const cand = f.candidates.find((c) => c.handle === 'stranger@mazel');
const ctx = keys(B, 'conv:')[0].slice(5);
const conv = JSON.parse(portals[B].MAILBOX.m.get('conv:' + ctx));
ok('(a branch with them is open; their key in it is null)', !!cand && conv.participants.some((p) => !p.me && p.handle === 'stranger@mazel' && !p.publicKey), JSON.stringify(conv.participants.map((p) => [p.handle, !!p.publicKey])));

const said = await call(B, 'thread_manage', { action: 'block', context_id: ctx, report: true, confirmed: true });
ok('(the tool says the portal is blocked)', /Everything from that portal is refused/.test(said));
ok('blocking a branch blocks the portal on the other side of it', keys(B, 'blocked:').length > 0, `blocked: keys written: ${keys(B, 'blocked:').length}; trust: ${keys(B, 'trust:').length}`);
await call(S, 'send_to_peer', { rpc: B + '/a2a', text: 'Still here.' });
const after = (await mail(B)).find((m) => /Still here/.test(m.text || ''));
ok('a note from the blocked portal is refused at the door', !after, after ? `landed as fromHandle ${after.fromHandle}` : '');
done();
