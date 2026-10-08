// Item 6: every way a need.offer can arrive passes the one gate. Unsigned, signed by the wrong key,
// stale, from a verified stranger at world tier, through the streaming door.
import { addPortal, call, J, ok, done, portals, wire, keys, asks, hold, a2a, a2aRaw, noteMsg, offerFrom, ackOf, signingOf, signWith, signedAction, newKeypair, relayReplies, worker } from './_h.mjs';
const A = 'https://avery-07a7.test', B = 'https://lea-07a7.test', S = 'https://stranger-07a7.test';
addPortal(A, 'avery@mazel'); addPortal(B, 'lea@mazel'); addPortal(S, 'sal@mazel');
await hold(A, B); await hold(B, A);
await call(A, 'contacts', { action: 'note', name: 'Omar Haddad', org: 'coil.example', have: ['heat-exchangers'], role: 'Built heat exchangers', witnesses: ['gmail'], small_meetings: 7 });
const body = { type: 'need.offer', needId: 'n-x', tier: 'public', needText: 'someone who knows heat exchangers', needTags: ['heat-exchangers'] };
const count = () => keys(A, 'ghostask:').length + keys(A, 'seen-offer:').length + keys(A, 'msg:').length;
const base = count();
// 1. unsigned
let r = await a2a(A, noteMsg('hi', { handle: 'lea@mazel', action: { ...body, v: 1, handle: 'lea@mazel' } }));
ok('an unsigned offer is refused with an error and writes nothing', /error -32603/.test(await ackOf(r)) && count() === base);
// 2. signed by a key that is not Lea's, claiming Lea
const kp = await newKeypair();
r = await a2a(A, noteMsg('hi', { handle: 'lea@mazel', cardUrl: B + '/.well-known/agent-card.json', action: { ...(await signedAction(kp, { origin: B, handle: 'lea@mazel' }, body)), v: 1 } }));
ok('a forged signature under Lea\'s name is refused and writes nothing', /error -32603/.test(await ackOf(r)) && count() === base);
// 3. Lea's real key, stale
const s = await signingOf(B);
r = await a2a(A, noteMsg('hi', { handle: 'lea@mazel', cardUrl: B + '/.well-known/agent-card.json', action: { ...(await signWith(s, { v: 1, handle: 'lea@mazel', publicKey: s.pub, cardUrl: `${B}/.well-known/agent-card.json`, rpc: `${B}/a2a`, castAt: new Date(Date.now() - 3 * 86400000).toISOString(), ...body })), v: 1 } }));
ok('a three-day-old offer is a replay and is refused', /error -32603/.test(await ackOf(r)) && count() === base);
// 4. a stranger with a directory record, verified, held at world
for (const [o, n] of [[S, 'sal']]) relayReplies.directory[n] = await (await worker.fetch(new Request(`${o}/.well-known/mazel/${n}.json`), portals[o])).json();
r = await a2a(A, noteMsg('hi', { handle: 'sal@mazel', cardUrl: S + '/.well-known/agent-card.json', action: await offerFrom(S, { needId: 'n-s', needText: 'someone who knows heat exchangers', needTags: ['heat-exchangers'] }) }));
ok('a verified stranger\'s offer is acked and scored against nothing', /Delivered/.test(await ackOf(r)) && keys(A, 'ghostask:').length === 0, `ghostask ${keys(A, 'ghostask:').length}`);
ok('the stranger is now held at world, which is not enough to offer', (await J(A, 'cards', { action: 'list' })).some((c) => c.handle === 'sal@mazel' && c.tier === 'world'));
// 5. the honest case, through the streaming door
portals[A].PULSE_STREAMING = '1';
const offer = await offerFrom(B, { needId: 'n-ok', needText: 'someone who knows heat exchangers', needTags: ['heat-exchangers'] });
const msg = noteMsg('A need of mine.', { handle: 'lea@mazel', cardUrl: B + '/.well-known/agent-card.json', action: offer });
r = await a2aRaw(A, JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'SendStreamingMessage', params: { message: msg } }));
ok('the streaming door runs the same gate and the same scoring', r.status === 200 && keys(A, 'ghostask:').length === 1);
r = await a2aRaw(A, JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'SendStreamingMessage', params: { message: { ...msg, messageId: 'other' } } }));
ok('and the same replay rule', keys(A, 'ghostask:').length === 1);
// 6. a world-tier card the owner never chose cannot be made into an offerer by its own say-so
r = await a2a(A, noteMsg('hi', { handle: 'sal@mazel', cardUrl: S + '/.well-known/agent-card.json', action: await offerFrom(S, { needId: 'n-s2', needText: 'someone who knows heat exchangers', needTags: ['heat-exchangers'] }) }));
ok('a second offer from the stranger still scores against nothing', keys(A, 'ghostask:').length === 1);
// 7. fields a sender adds are dropped before anything reads them
r = await a2a(A, noteMsg('hi', { handle: 'lea@mazel', cardUrl: B + '/.well-known/agent-card.json', action: { ...(await offerFrom(B, { needId: 'n-extra', needText: 'someone who knows heat exchangers', needTags: ['heat-exchangers'] })), path: ['x@mazel', 'y@mazel'], hops: 3, to: 'avery@mazel' } }));
const stored = keys(A, 'ghostask:').map((k) => portals[A].MAILBOX.m.get(k)).join('');
ok('a path, a hop count or a recipient a sender adds is not kept', !/x@mazel|hops/.test(stored));
done();
