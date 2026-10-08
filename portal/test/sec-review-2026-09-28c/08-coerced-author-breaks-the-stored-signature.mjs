// L2 (regression note on 2026-09-28b H5; lock 11 "human words pass verbatim", lock 12 "exists as a
// signed object"). The fix makes onThreadMessage() coerce author to "agent" in a branch the people
// have not joined - and does it by overwriting message.metadata.haah.author on the message it then
// stores. `author` is inside the signed fields. The stored object therefore carries a signature
// over bytes it no longer contains: verifyMessage() fails on this portal's own copy, thread_export
// hands out a message whose signature does not check, and nothing records what the sender actually
// claimed. A later reader cannot tell a coerced label from a tampered message. The label the
// portal shows can differ from the label that was signed; the signed bytes must not.
import { addPortal, call, J, ok, done, portals, signingOf, threadMsg, a2a, canonical } from '../sec-review-2026-09-28/_harness.mjs';

const A = 'https://alice8c.test', B = 'https://bob8c.test';
addPortal(A, 'alice@mazel');
addPortal(B, 'bob8c@mazel');
await call(B, 'update_card', { add_have: 'fractional-cfo', confirmed: true });
await call(A, 'add_known_card', { url: B + '/card' });
await call(B, 'add_known_card', { url: A + '/card' });

await J(A, 'find', { need_text: 'a fractional cfo for Northwind', tags: ['fractional-cfo'] });
const branch = JSON.parse(await call(A, 'thread_list')).threads.find(t => t.with.includes('bob8c@mazel'));
ok('a branch is open, agents only', branch && branch.humans === false);

const bSign = await signingOf(B);
const msg = await threadMsg(bSign, { contextId: branch.context_id, from: 'bob8c@mazel', author: 'human', text: 'Bob here, personally.' });
await a2a(A, msg);

const stored = JSON.parse(portals[A].MAILBOX.m.get(`convm:${branch.context_id}:00000002`) || 'null');
ok('the message was stored', !!stored);
const h = stored.message.metadata.haah;
ok('it is shown as an agent\'s (H5 holds)', h.author === 'agent', h.author);

// Verify the stored object exactly as verifyMessage() would: the signed fields, under the sender's key.
const unb64u = (s) => Uint8Array.from(atob(String(s).replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - s.length % 4) % 4)), c => c.charCodeAt(0));
const key = await crypto.subtle.importKey('raw', unb64u(bSign.pub), { name: 'Ed25519' }, false, ['verify']);
const signedFields = { contextId: stored.message.contextId, messageId: stored.message.messageId, parts: stored.message.parts, author: h.author, from: h.from, at: h.at };
const verifies = await crypto.subtle.verify({ name: 'Ed25519' }, key, unb64u(h.sig), new TextEncoder().encode(canonical(signedFields)));
ok('the stored message must still verify under the sender\'s key', verifies, `signature over author: "${h.author}" from ${h.from}`);
ok('what the sender actually claimed must be kept somewhere', verifies || h.claimedAuthor === 'human' || (stored.claimed && stored.claimed.author === 'human'), JSON.stringify(Object.keys(h)));

if (!verifies) console.log(`FAIL broken signature at rest: onThreadMessage rewrote metadata.haah.author from "human" to "agent" inside the signed object, so alice's own copy of bob's message no longer verifies, and thread_export would hand out a message that looks tampered with.`);
done();
