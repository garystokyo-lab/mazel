// M1 (regression on the previous review's H1: "block applies portal-wide"). thread_block writes
// blocked:<publicKey> and blocked:h:<handle> - but only inside `for (const p of others) { if
// (!p.publicKey) continue; ... }`. A participant whose key this portal never pinned is skipped
// entirely, so NEITHER key is written and the block collapses back to conv.blocked, i.e. one
// thread. That participant is the ordinary case for an unverified intro: applyInboundAction's
// intro.propose branch builds `from` as { handle, cardUrl, rpc } with no publicKey when the portal
// holds no card for the proposer, and openThreadFromIntro copies that straight onto the
// participant. "Block is one step for someone being harassed" (thread_manage) then blocks nothing
// but the thread they were harassed in: the same portal's notes, proposals and new needs all still
// land.
import { addPortal, call, ok, done, portals, signingOf, signedAction, a2a, noteMsg } from '../sec-review-2026-09-28/_harness.mjs';

const V = 'https://victim5.test', S = 'https://spam5.test';
addPortal(V, 'victim@mazel');
addPortal(S, 'spam@mazel');

// An intro proposal from a portal the victim holds no card for: "unverified", but answerable.
const sSign = await signingOf(S);
const propose = await signedAction(sSign, { origin: S, handle: 'spam@mazel' }, {
  type: 'intro.propose', introId: 'b'.repeat(32), why: 'I think you two should talk.',
  needText: 'a fractional cfo', needTags: ['fractional-cfo'], matchedTags: ['fractional-cfo'],
  proposer: { handle: 'spam@mazel', cardUrl: S + '/.well-known/agent-card.json', rpc: S + '/a2a' }, path: ['spam@mazel'] });
await a2a(V, noteMsg('Intro proposal from spam@mazel.', { handle: 'spam@mazel', cardUrl: S + '/.well-known/agent-card.json', action: propose }));

await call(V, 'respond_intro', { intro_id: 'b'.repeat(32), decision: 'accepted', confirmed: true });
const conv = [...portals[V].MAILBOX.m.entries()].filter(([k]) => k.startsWith('conv:')).map(([, v]) => JSON.parse(v))[0];
ok('a thread opened with the unverified proposer', !!conv, JSON.stringify(conv && conv.participants.map(p => [p.handle, !!p.publicKey])));

await call(V, 'thread_block', { context_id: conv.contextId, confirmed: true, report: true });
const blockKeys = [...portals[V].MAILBOX.m.keys()].filter(k => k.startsWith('blocked:'));
ok('blocking records the portal, not just the thread', blockKeys.length > 0, JSON.stringify(blockKeys));

// The blocked portal writes again, outside that thread.
const before = [...portals[V].MAILBOX.m.keys()].filter(k => k.startsWith('msg:')).length;
const r = await a2a(V, noteMsg('Still here. Answer me.', { handle: 'spam@mazel', cardUrl: S + '/.well-known/agent-card.json' }));
const body = await r.json();
const after = [...portals[V].MAILBOX.m.keys()].filter(k => k.startsWith('msg:')).length;
const refused = !!(body.error && body.error.code === -32603);

ok('a blocked portal is refused everywhere, not only in that thread', refused && after === before,
   `door answered ${body.error ? body.error.code + ' ' + body.error.message : 'ok'}; mailbox ${before} -> ${after}`);
if (!refused) {
  console.log(`FAIL block is not portal-wide: thread_block wrote ${blockKeys.length} blocked: key(s) because the participant had no pinned publicKey, so spam@mazel's next note walked straight into victim@mazel's mailbox.`);
}
done();
