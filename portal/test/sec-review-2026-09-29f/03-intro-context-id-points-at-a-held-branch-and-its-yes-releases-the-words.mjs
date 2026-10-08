// HIGH. openThreadFromIntro() (index.js ~3934-3963), the `already` join. A proposal carries the
// contextId of the thread the people will share; the responder's portal stores whatever hex32 the
// proposer wrote (applyInboundAction ~3055) and, on the owner's yes, joins the conversation at that
// id as long as its counterpart is the proposer. If that conversation is a branch the OWNER's own
// portal opened for a matched-only need - firstWriter is the owner, needTier matched-only - the
// join releases the need's words into it: "The need, now that you both said yes: ...". Nothing
// ties the contextId on the proposal to the need the proposal is about. So anyone who received a
// blind branch (buckets and matched tags, by design) proposes an intro about something else, naming
// that branch, and the owner's yes to the something else says the held-back need out loud (§3.6).
import { addPortal, call, J, ok, done, portals, worker, relayReplies, signingOf, signWith, a2a, noteMsg, conv, mail, wire } from '../sec-review-2026-09-28/_harness.mjs';

const A = 'https://alice-f3.test', B = 'https://bob-f3.test';
addPortal(A, 'alice@mazel'); addPortal(B, 'bob@mazel');
for (const [o, n] of [[A, 'alice'], [B, 'bob']]) relayReplies.directory[n] = await (await worker.fetch(new Request(`${o}/.well-known/mazel/${n}.json`), portals[o])).json();
await call(A, 'update_card', { add_have: 'fractional-cfo', confirmed: true });
await call(B, 'add_known_card', { url: A + '/card' });
await call(A, 'add_known_card', { url: B + '/card' });

// Bob holds a need back. His portal opens a branch to alice carrying buckets and the matched tag only.
await call(B, 'update_card', { add_need: 'fractional-cfo', need_visibility: 'matched-only' });
const f = await J(B, 'find', { need_text: 'a replacement CFO for Northwind before the board hears about it', tags: ['fractional-cfo'] });
const branchId = portals[B].MAILBOX.m.get(`branchof:${f.thread_id}:alice@mazel`);
const bc = conv(B, branchId);
ok('precondition: bob\'s portal opened a matched-only branch to alice, buckets only', !!bc && bc.needTier === 'matched-only' && bc.firstWriter === 'bob@mazel' && !bc.humans, bc ? `branch ${branchId.slice(0, 8)}, tier ${bc.needTier}` : 'no branch');
const onWire = wire.filter((w) => w.url === A + '/a2a' && /Northwind/.test(w.body)).length;
ok('precondition: the words did not travel with the branch', onWire === 0, `${onWire} message(s) with the words`);
ok('(alice\'s portal holds the branch, so she knows its id)', !!conv(A, branchId));

// Alice proposes an intro about something else entirely - and names bob's branch as its thread.
const as = await signingOf(A);
const introId = 'f3' + 'c'.repeat(30);
const prop = await signWith(as, { v: 1, type: 'intro.propose', handle: 'alice@mazel', publicKey: as.pub, cardUrl: A + '/.well-known/agent-card.json', rpc: A + '/a2a', castAt: new Date().toISOString(),
  introId, why: 'You need a hockey coach in Tokyo; alice@mazel has hockey.', needText: 'a hockey coach in Tokyo', needTags: ['hockey'], matchedTags: ['hockey'], path: ['alice@mazel'],
  proposer: { handle: 'alice@mazel', cardUrl: A + '/.well-known/agent-card.json', rpc: A + '/a2a' }, ask: { kind: 'call', size: '20 minutes' }, contextId: branchId });
await a2a(B, noteMsg('Intro proposal from alice@mazel: hockey in Tokyo.', { handle: 'alice@mazel', cardUrl: A + '/.well-known/agent-card.json', action: prop }));
const intro = JSON.parse(portals[B].MAILBOX.m.get('intro:' + introId) || 'null');
ok('precondition: bob\'s portal holds a proposal about hockey that points at the branch', !!intro && intro.contextId === branchId && /hockey/.test(intro.why), intro ? `contextId ${String(intro.contextId).slice(0, 8)}, why: ${intro.why}` : 'no intro');

// Bob says yes to hockey.
wire.length = 0;
const said = await call(B, 'respond_intro', { intro_id: introId, decision: 'accepted', confirmed: true });
const leaked = wire.filter((w) => w.url === A + '/a2a' && /Northwind/.test(w.body));
ok('a held-back need\'s words leave only on a yes to that need', !leaked.length, `${leaked.length} message(s) to alice carrying the Northwind need; bob said yes to: "${intro && intro.why}"`);
const bothYes = (await mail(B)).filter((m) => m.box && m.box.kind === 'both_yes').map((m) => m.text.slice(0, 70));
ok('(what bob is shown for it)', true, `${said.slice(0, 60)} | box: ${bothYes.join(' | ')}`);
const ac = conv(A, branchId);
ok('(alice\'s copy of the branch now carries the words)', true, ac ? `alice's branch: humans ${ac.humans}, ${ac.seq} messages` : '');
done();
