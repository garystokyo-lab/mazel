// H3. A branch's contextId is branchId(openerPublicKey, rootId, candidateHandle) =
// stableId("branch", pub, rootId, handle) - and rootId is stableId("thread", sortedTags).slice(0,8),
// which is derived from the need's TAGS alone. The opener's public key is published on its agent
// card. So any third party can compute, ahead of time, the contextId Alice's portal will use for
// her branch to Bob. onThreadOpen()'s need path accepts whatever contextId the sender writes - it
// never checks it against branchId(sender's own key, ...) - and refuses a second open for a
// contextId it already holds. A stranger therefore squats the id: Bob's portal ends up holding a
// branch with the squatter, and Alice's real branch-open is dropped in silence, forever.
import { addPortal, call, J, ok, done, portals, signingOf, signedAction, a2a } from '../sec-review-2026-09-28/_harness.mjs';

const A = 'https://alice3.test', B = 'https://bob3.test', M = 'https://mallory3.test';
addPortal(A, 'alice@mazel');
addPortal(B, 'bob3@mazel');
addPortal(M, 'mallory@mazel');

const stableId = async (...parts) => {
  const h = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(parts.join('|')));
  return [...new Uint8Array(h)].map(b => b.toString(16).padStart(2, '0')).join('').slice(0, 32);
};

await call(B, 'update_card', { add_have: 'fractional-cfo', confirmed: true });
await call(A, 'add_known_card', { url: B + '/card' });
await call(B, 'add_known_card', { url: A + '/card' });
await call(B, 'add_known_card', { url: M + '/card' });   // Bob holds Mallory's card too: an ordinary contact

// Mallory knows Alice's public key (it is on her card) and guesses the tags of the need she will cast.
const aliceKey = (await signingOf(A)).pub;
const TAGS = ['fractional-cfo'];
const rootId = (await stableId('thread', [...TAGS].sort().join(','))).slice(0, 8);
const predicted = await stableId('branch', aliceKey, rootId, 'bob3@mazel');

// Mallory opens a branch at that exact id, first.
const mSign = await signingOf(M);
const at = new Date().toISOString();
const note = { messageId: 'm-squat', contextId: predicted, taskId: '', role: 'ROLE_USER',
  parts: [{ text: 'Looking for: someone who does fractional-cfo work.' },
          { data: { need: { needId: 'zzzzzzzz', tier: 'public', text: 'someone who does fractional-cfo work', tags: TAGS }, matched: TAGS, why: '' } }],
  metadata: { haah: { author: 'agent', from: 'mallory@mazel', at, envelope: null }, action: { type: 'thread.message', v: 1 } },
  extensions: ['https://mazel.ai/ext/haah/v1'], referenceTaskIds: [] };
const open = await signedAction(mSign, { origin: M, handle: 'mallory@mazel' }, {
  type: 'thread.open', contextId: predicted, kind: 'need', firstWriter: 'mallory@mazel',
  origin: { needId: 'zzzzzzzz', tier: 'public' },
  participants: [{ handle: 'mallory@mazel', cardUrl: M + '/.well-known/agent-card.json', rpc: M + '/a2a', role: 'need' },
                 { handle: 'bob3@mazel', cardUrl: B + '/card', rpc: B + '/a2a', role: 'have' }],
  note });
await a2a(B, { messageId: 'sq-1', contextId: '', taskId: '', role: 'ROLE_USER', parts: [{ text: 'a need' }],
  metadata: { handle: 'mallory@mazel', cardUrl: M + '/.well-known/agent-card.json', action: open }, extensions: [], referenceTaskIds: [] });

const squatted = JSON.parse(portals[B].MAILBOX.m.get('conv:' + predicted) || 'null');
ok('mallory could compute the id of a branch she is not part of', !!squatted, predicted);

// Now Alice casts the need she was always going to cast, to the same tag.
const f = await J(A, 'find', { need_text: 'someone who does fractional-cfo work', tags: TAGS });
const mine = JSON.parse(portals[A].MAILBOX.m.get('conv:' + predicted) || 'null');
ok('alice\'s own branch really does land on the predicted id', !!mine, f.thread_id + ' / ' + predicted);

const bobSide = JSON.parse(portals[B].MAILBOX.m.get('conv:' + predicted) || 'null');
const bobHasAlice = [...portals[B].MAILBOX.m.entries()].filter(([k]) => k.startsWith('conv:'))
  .map(([, v]) => JSON.parse(v)).some(c => c.participants.some(p => p.handle === 'alice@mazel'));

ok('bob\'s copy of that branch must be the one alice opened', bobSide && bobSide.participants.some(p => p.handle === 'alice@mazel'),
   `other party on bob's copy: ${JSON.stringify((bobSide || { participants: [] }).participants.filter(p => !p.me).map(p => p.handle))}`);
ok('alice\'s need must reach bob at all', bobHasAlice);

if (!bobHasAlice) {
  console.log(`FAIL branch-id squat: mallory@mazel pre-registered contextId ${predicted} at bob's portal, so bob's portal silently dropped alice@mazel's real branch-open for the same id. Alice's portal believes the branch is open with bob; bob's portal holds a branch with mallory.`);
}
done();
