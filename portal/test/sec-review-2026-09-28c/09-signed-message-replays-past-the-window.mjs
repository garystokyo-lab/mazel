// 28b noted this without a script: onThreadMessage() has no freshness check and dedupes only against
// the newest 200 messages (readMessages limit 200). A signed human message, captured once, is
// accepted again after 200 newer messages: stored as a new reply, boxed 💬, unread bumped, the
// doorbell rung - the person's own words, re-said at a time they did not say them. Here the
// 200 are the owner's own agent notes, so no per-sender door cap gets in the way.
import { addPortal, call, J, ok, done, portals, signingOf, threadMsg, a2a, openThread, mail } from '../sec-review-2026-09-28/_harness.mjs';

const A = 'https://alice.c9', B = 'https://bob.c9';
addPortal(A, 'alice@mazel'); addPortal(B, 'bob@mazel');
const { ctx } = await openThread(A, B, 'replay-tag', 'bob@mazel');
await call(A, 'thread_send', { context_id: ctx, text: 'Hi Bob.', confirmed: true });
const sB = await signingOf(B);
const captured = await threadMsg(sB, { contextId: ctx, from: 'bob@mazel', author: 'human', text: 'Yes - wire the deposit to the account I gave you.' });
const first = await (await a2a(A, captured)).json();
ok('bob\'s message lands once', !first.error);
const again = await (await a2a(A, captured)).json();
ok('a straight repeat is recognised', /Already/.test(JSON.stringify(again)));

for (let i = 0; i < 200; i++) await call(A, 'thread_note', { context_id: ctx, text: 'agent note ' + i });
const before = (await J(A, 'thread_read', { context_id: ctx })).total;
const replies0 = (await mail(A)).filter((m) => m.box && m.box.kind === 'reply' && m.box.contextId === ctx).length;
const late = await (await a2a(A, captured)).json();
const after = (await J(A, 'thread_read', { context_id: ctx })).total;
const replies1 = (await mail(A)).filter((m) => m.box && m.box.kind === 'reply' && m.box.contextId === ctx).length;
ok('the same signed message must not be accepted twice, however far back it sits', /Already/.test(JSON.stringify(late)) && after === before, `door said ${JSON.stringify(late.result && late.result.message.parts[0].text)}; messages ${before} -> ${after}`);
ok('and must not become a new 💬 in the box', replies1 === replies0, `reply items ${replies0} -> ${replies1}`);
if (after !== before) console.log(`FAIL message replay: bob's signed message (messageId ${captured.messageId.slice(0, 8)}…) was accepted a second time once 200 newer messages pushed it out of the dedupe window; it is now message ${after} in alice's thread, boxed as a fresh reply.`);
done();
