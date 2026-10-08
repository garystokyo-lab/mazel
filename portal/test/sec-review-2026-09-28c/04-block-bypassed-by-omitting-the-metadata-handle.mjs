// M2 (regression on 2026-09-28b M1, "block is portal-wide for an unpinned stranger").
//
// The fix writes blocked:h:<handle> for every participant with a handle, key or no key. The door
// (handleSend) then reads the block by `fromHandle`, which is message.metadata.handle - a field
// the sender fills in, or leaves out. With no metadata.handle, fromHandle is message.role
// ("ROLE_USER"), no held card matches it, and the block by handle is never consulted; a block by
// key would still catch a signer, but the whole point of M1 was the stranger whose key this portal
// never pinned. Every typed action carries its own `handle` (and intro.propose its `proposer`),
// and the door checks neither. So the harasser blocked in M1 drops one optional field and their
// proposals and needs walk in again.
import { addPortal, call, ok, done, portals, signingOf, signedAction, a2a, noteMsg } from '../sec-review-2026-09-28/_harness.mjs';

const V = 'https://victim4c.test', S = 'https://spam4c.test';
addPortal(V, 'victim@mazel');
addPortal(S, 'spam@mazel');

// The M1 setup: an unverified proposal, a thread, a block.
const sSign = await signingOf(S);
const propose = await signedAction(sSign, { origin: S, handle: 'spam@mazel' }, {
  type: 'intro.propose', introId: 'd'.repeat(32), why: 'I think you two should talk.', needText: 'a fractional cfo', needTags: ['fractional-cfo'], matchedTags: ['fractional-cfo'],
  proposer: { handle: 'spam@mazel', cardUrl: S + '/.well-known/agent-card.json', rpc: S + '/a2a' }, path: ['spam@mazel'] });
await a2a(V, noteMsg('Intro proposal from spam@mazel.', { handle: 'spam@mazel', cardUrl: S + '/.well-known/agent-card.json', action: propose }));
await call(V, 'respond_intro', { intro_id: 'd'.repeat(32), decision: 'accepted', confirmed: true });
const conv = [...portals[V].MAILBOX.m.entries()].filter(([k]) => k.startsWith('conv:')).map(([, v]) => JSON.parse(v))[0];
await call(V, 'thread_block', { context_id: conv.contextId, confirmed: true, report: true });
ok('the block is recorded by handle (M1 holds)', portals[V].MAILBOX.m.has('blocked:h:spam@mazel'));

// With metadata.handle present, the door refuses (M1's own regression). Without it:
const before = [...portals[V].MAILBOX.m.keys()].filter(k => k.startsWith('msg:') || k.startsWith('intro:')).length;
const propose2 = await signedAction(sSign, { origin: S, handle: 'spam@mazel' }, {
  type: 'intro.propose', introId: 'e'.repeat(32), why: 'Still want to talk. Answer me.', needText: 'a fractional cfo', needTags: ['fractional-cfo'], matchedTags: ['fractional-cfo'],
  proposer: { handle: 'spam@mazel', cardUrl: S + '/.well-known/agent-card.json', rpc: S + '/a2a' }, path: ['spam@mazel'] });
const r1 = await (await a2a(V, noteMsg('Intro proposal from spam@mazel.', { cardUrl: S + '/.well-known/agent-card.json', action: propose2 }))).json();
const intro2 = portals[V].MAILBOX.m.has('intro:' + 'e'.repeat(32));
ok('a blocked handle\'s proposal is refused even with metadata.handle left out', !!(r1.error && r1.error.code === -32603) && !intro2,
   `door: ${r1.error ? r1.error.code + ' ' + r1.error.message : 'ok'}; intro stored: ${intro2}`);

const need = await signedAction(sSign, { origin: S, handle: 'spam@mazel' }, { type: 'find.request', needId: 'n-spam-2', needText: 'a cfo who will answer me', needTags: ['fractional-cfo'], maxHops: 1, originRpc: S + '/a2a', hops: 0, path: ['spam@mazel'] });
const r2 = await (await a2a(V, noteMsg('looking', { cardUrl: S + '/.well-known/agent-card.json', action: need }))).json();
const seen = portals[V].MAILBOX.m.has('seen-need:n-spam-2');
ok('and so is its need', !!(r2.error && r2.error.code === -32603) && !seen, `door: ${r2.error ? r2.error.code : 'ok'}; need processed: ${seen}`);

const after = [...portals[V].MAILBOX.m.keys()].filter(k => k.startsWith('msg:') || k.startsWith('intro:')).length;
ok('nothing new landed', after === before, `${before} -> ${after}`);

if (!(r1.error && r1.error.code === -32603) || !(r2.error && r2.error.code === -32603)) {
  console.log(`FAIL block bypassed: spam@mazel is blocked by handle on victim@mazel's portal, but a proposal and a need signed under that same handle got through by omitting message.metadata.handle (the door reads the block from that field only; action.handle and proposer.handle are not checked).`);
}
done();
