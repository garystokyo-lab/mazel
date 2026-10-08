// The eight 28b fixes, each pushed from a different angle than the regression at the end of
// sec-thread-test.mjs. PASS means the fix holds under that variation; any FAIL here is a finding
// in its own right (the numbered scripts in this directory carry the ones that failed).
import { addPortal, call, J, ok, done, portals, wire, stubs, relayReplies, worker, signingOf, newKeypair, signedAction, a2a, noteMsg, threadMsg, openThread, mail, conv, keys } from '../sec-review-2026-09-28/_harness.mjs';

const A = 'https://alice.c10', B = 'https://bob.c10', C = 'https://cal.c10', X = 'https://mallory.c10';
addPortal(A, 'alice@mazel'); addPortal(B, 'bob@mazel'); addPortal(C, 'cal@mazel'); addPortal(X, 'mallory@mazel');
for (const o of [B, C, X]) { await call(o, 'update_card', { add_have: 'fractional-cfo', confirmed: true }); await call(A, 'add_known_card', { url: o + '/card' }); await call(o, 'add_known_card', { url: A + '/card' }); }
relayReplies.directory.alice = await (await worker.fetch(new Request(A + '/.well-known/mazel/alice.json'), portals[A])).json();
relayReplies.directory.cal = await (await worker.fetch(new Request(C + '/.well-known/mazel/cal.json'), portals[C])).json();
const SECRET = 'a replacement CFO for Northwind before the board hears about it';

// ---- H1 variations: directed need, mixed-case need_to; proposed via router_for; the why line ----
await call(A, 'update_card', { add_need: 'directed-cfo', need_visibility: 'directed', need_to: 'Cal@Mazel' });
wire.length = 0;
const fd = await J(A, 'find', { need_text: SECRET, tags: ['directed-cfo', 'fractional-cfo'] });
const opened = wire.filter((w) => /"thread\.open"/.test(w.body)).map((w) => w.url);
ok('H1: a directed need with a mixed-case need_to still opens only with that person', opened.length === 1 && opened[0] === C + '/a2a', JSON.stringify(opened));
const mal = fd.candidates.find((c) => c.handle === 'mallory@mazel');
const viaRouter = await call(A, 'propose_intro', { thread_id: fd.thread_id, card_url: mal.card_url, router_for: 'bob@mazel', confirmed: true }).catch((e) => e.message);
ok('H1: proposing it to someone else as a router is refused before anything leaves', /directed at/.test(viaRouter) && !wire.some((w) => w.url.startsWith(X) && w.body.includes('Northwind')), String(viaRouter).slice(0, 80));
ok('H1: the directed need never reached the relay as text', !wire.some((w) => w.url.startsWith('https://relay.sec') && w.body.includes('Northwind')));

// ---- H2 variations: replay at the named recipient after close; tampered participants; a portal holding the opener at inner ----
const openMsg = JSON.parse(wire.find((w) => w.url === C + '/a2a' && /"thread\.open"/.test(w.body)).body).params.message;
const ctxD = openMsg.metadata.action.contextId;
await call(C, 'thread_close', { context_id: ctxD, confirmed: true });
await a2a(C, { ...openMsg, messageId: 'r-' + Math.random() });
ok('H2: a replay at the named recipient after close does not reopen it', conv(C, ctxD).state === 'closed');
const tampered = JSON.parse(JSON.stringify(openMsg)); tampered.messageId = 't-' + Math.random(); tampered.metadata.action.participants.push({ handle: 'bob@mazel', cardUrl: B + '/card', rpc: B + '/a2a', role: 'have' });
await a2a(B, tampered);
ok('H2: naming another portal in the participants breaks the signature, and it opens nothing there', !conv(B, ctxD));
await call(B, 'add_known_card', { url: A + '/card', tier: 'inner' });
await a2a(B, { ...openMsg, messageId: 'r2-' + Math.random() });
ok('H2: even a portal holding the opener at inner tier refuses an open that does not name it', !conv(B, ctxD));

// ---- the mirror of scripts 01/02: at the RECEIVING door the directory IS asked ----
const E = 'https://evil.c10'; const evil = await newKeypair();
const evilCard = { name: 'alice@mazel', supportedInterfaces: [{ url: E + '/a2a', protocolBinding: 'JSONRPC' }], capabilities: { extensions: [{ uri: 'https://mazel.ai/ext/haah/v1', params: { handle: 'alice@mazel', cardUrl: E + '/card', publicKey: evil.pub, need: [], have: [], glosses: {} } }] } };
stubs.push({ test: (u) => u === E + '/card', reply: async () => new Response(JSON.stringify(evilCard), { headers: { 'content-type': 'application/json' } }) });
const D = 'https://dee.c10'; addPortal(D, 'dee@mazel'); await call(D, 'update_card', { add_have: 'fractional-cfo', confirmed: true });
const ctxI = 'c10i' + 'f'.repeat(28);
const note = { messageId: 'm-i', contextId: ctxI, taskId: '', role: 'ROLE_USER', parts: [{ text: 'Looking for: x' }, { data: { need: { needId: 'n', tier: 'public', text: 'someone who does fractional-cfo', tags: ['fractional-cfo'] }, matched: ['fractional-cfo'], why: '' } }], metadata: { haah: { author: 'agent', from: 'alice@mazel', at: new Date().toISOString(), envelope: null }, action: { type: 'thread.message', v: 1 } }, extensions: [], referenceTaskIds: [] };
const fakeOpen = await signedAction(evil, { origin: E, handle: 'alice@mazel' }, { type: 'thread.open', contextId: ctxI, kind: 'need', firstWriter: 'alice@mazel', origin: { needId: 'n', tier: 'public' }, participants: [{ handle: 'alice@mazel', cardUrl: E + '/card', rpc: E + '/a2a', role: 'need' }, { handle: 'dee@mazel', cardUrl: D + '/card', rpc: D + '/a2a', role: 'have' }], note });
await a2a(D, noteMsg('a need', { handle: 'alice@mazel', cardUrl: E + '/card', action: fakeOpen }));
ok('receiving door: a thread.open from an impostor card under alice\'s handle is refused (keyFromCard asks the directory)', !conv(D, ctxI));

// ---- H4 variation: the same need cast by two portals to the same candidate gets two ids ----
await call(C, 'add_known_card', { url: B + '/card' }); await call(X, 'add_known_card', { url: B + '/card' });
await J(C, 'find', { need_text: 'someone who does fractional-cfo', tags: ['fractional-cfo'] });
await J(X, 'find', { need_text: 'someone who does fractional-cfo', tags: ['fractional-cfo'] });
const idsC = keys(C, 'conv:'), idsX = keys(X, 'conv:');
ok('H4: two openers of the same need to the same person land on different ids', idsC.length && idsX.length && !idsC.some((k) => idsX.includes(k)));

// ---- H5 variations: the need side\'s "human" message into a branch; a human message after 🌀 stays human ----
const fp = await J(B, 'find', { need_text: 'someone who does fractional-cfo', tags: ['fractional-cfo'] });
const branch = JSON.parse(await call(B, 'thread_list')).threads.find((t) => t.branch && !t.humans && t.with.includes('cal@mazel'));
const sB = await signingOf(B);
await a2a(C, await threadMsg(sB, { contextId: branch.context_id, from: 'bob@mazel', author: 'human', text: 'Bob personally, before anyone said yes.' }));
const calSide = (await J(C, 'thread_read', { context_id: branch.context_id })).messages.find((m) => /personally/.test(m.parts[0].text || ''));
ok('H5: a "human" message from the NEED side into an agents-only branch is stored as the agent\'s', calSide && calSide.author === 'agent', calSide && calSide.author);
const { ctx: real } = await openThread(A, B, 'h5-tag', 'bob@mazel');
await a2a(A, await threadMsg(sB, { contextId: real, from: 'bob@mazel', author: 'human', text: 'Bob, after both said yes.' }));
const aSide = (await J(A, 'thread_read', { context_id: real })).messages.find((m) => /after both/.test(m.parts[0].text || ''));
ok('H5: after 🌀 a person\'s message is a person\'s', aSide && aSide.author === 'human');

// ---- M1 variation: after a block, a SIGNED thread.open from the blocked portal is refused ----
await call(B, 'thread_block', { context_id: real, confirmed: true });   // bob blocks alice
const sA = await signingOf(A);
const ctxB = 'c10b' + 'e'.repeat(28);
const blockedOpen = await signedAction(sA, { origin: A, handle: 'alice@mazel' }, { type: 'thread.open', contextId: ctxB, kind: 'need', firstWriter: 'alice@mazel', origin: { needId: 'n', tier: 'public' }, participants: [{ handle: 'alice@mazel', cardUrl: A + '/card', rpc: A + '/a2a', role: 'need' }, { handle: 'bob@mazel', cardUrl: B + '/card', rpc: B + '/a2a', role: 'have' }], note: { ...note, contextId: ctxB } });
await a2a(B, noteMsg('a need', { handle: 'alice@mazel', cardUrl: A + '/card', action: blockedOpen }));
ok('M1: a signed branch-open from a blocked portal opens nothing', !conv(B, ctxB));

// ---- M2 variation: invite_text for a matched-only need through the contacts wrapper and through invite_text itself ----
await call(A, 'update_card', { add_need: 'quiet-cfo', need_visibility: 'matched-only' });
const fq = await J(A, 'find', { need_text: SECRET + ' quietly', tags: ['quiet-cfo', 'fractional-cfo'] });
const gid = (await call(A, 'note_ghost', { name: 'Outsider', have: ['fractional-cfo'], edge_score: 70 })).match(/Their id is (\w+)/)[1];
const r1 = await call(A, 'invite_text', { ghost_id: gid, thread_id: fq.thread_id }).catch((e) => e.message);
ok('M2: invite_text itself refuses a held need', /holding back/.test(r1) && !/Northwind/.test(r1));

// ---- L1 variation: a whitespace-only cap is the default ----
const G = 'https://gus.c10'; addPortal(G, 'gus@mazel', { DOORBELL_DAILY_CAP: '   ' });
portals[G].MAILBOX.m.set('push:one', JSON.stringify({ id: 'one', endpoint: 'https://push.c10/gus', keys: { p256dh: 'p', auth: 'a' }, created: new Date().toISOString() }));
let rings = 0; stubs.push({ test: (u) => u.startsWith('https://push.c10/'), reply: async () => { rings++; return new Response(null, { status: 201 }); } });
await call(G, 'note_ghost', { name: 'Someone', have: ['rare-craft'], edge_score: 80 });
await call(G, 'find', { need_text: 'someone who does rare-craft', tags: ['rare-craft'] });
ok('L1: a whitespace DOORBELL_DAILY_CAP means the default', rings === 1, String(rings));

// ---- H3 variation: a relay result whose card exists but is for a different handle is dropped ----
stubs.push({ test: (u) => u.startsWith('https://relay.sec/search'), reply: async () => new Response(JSON.stringify({ results: [{ handle: 'nobody@mazel', cardUrl: C + '/card', rpc: C + '/a2a', publicKey: 'k', have: ['fractional-cfo'] }] }), { headers: { 'content-type': 'application/json' } }) });
const Z = 'https://zoe.c10'; addPortal(Z, 'zoe@mazel');
const fz = await J(Z, 'find', { need_text: 'a fractional cfo', tags: ['fractional-cfo'] });
ok('H3: a relay result pointing at a real card under the wrong handle is dropped', !(fz.candidates || []).some((c) => c.handle === 'nobody@mazel' || c.handle === 'cal@mazel'));
done();
