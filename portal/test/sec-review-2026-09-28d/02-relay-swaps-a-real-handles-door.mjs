// MEDIUM. The gate authenticates a relay result's KEY against the directory but takes the RPC and
// the cardUrl from the card the relay named. searchRelay() -> pinIdentity(r.handle, r.cardUrl) ->
// cardIdentity(): it fetches r.cardUrl, checks the card's handle and (via resolveHandle) that the
// card's key equals the directory record's key, then returns { publicKey, rpc: parsed.rpc,
// cardUrl } - parsed.rpc being whatever THAT card says, and the authentic rpc from the directory
// record (rec.rpc) is fetched and thrown away. sarah's real public key is public, so an attacker
// serves a card that carries her real key but the attacker's own door. The key check passes;
// rememberStranger() then stores sarah@mazel pointed at the attacker's rpc. openBranch delivers the
// public need's words there at once, and the owner's intro proposal follows. A lying or
// misconfigured relay silently becomes the man in the middle for a real handle, and the key check
// gives false assurance. (Contrast 28c/01,02: a WRONG key is correctly refused; a right key with a
// wrong door is not.)
import { addPortal, call, J, ok, done, portals, stubs, wire, R, relayReplies, signWith, signingOf, a2a, noteMsg, lastIntro } from '../sec-review-2026-09-28/_harness.mjs';
import { HAAH } from '../a2a-helpers.mjs';

const A = 'https://alice-d2.test', S = 'https://sarah-d2.test', EVIL = 'https://evil-d2.example';
addPortal(A, 'alice@mazel');
addPortal(S, 'sarah@mazel');
await call(S, 'update_card', { add_have: 'fractional-cfo', confirmed: true });

// The directory vouches for the real sarah, at her real door.
const sSign = await signingOf(S);
relayReplies.directory.sarah = await signWith(sSign, { handle: 'sarah@mazel', publicKey: sSign.pub, cardUrl: S + '/.well-known/agent-card.json', rpc: S + '/a2a', timestamp: new Date().toISOString() });
// (fixture, added after the 28c gate: sarah's portal now verifies alice through the directory before it stores her proposal, so alice publishes too)
relayReplies.directory.alice = await (await (await import('../sec-review-2026-09-28/_harness.mjs')).worker.fetch(new Request(A + '/.well-known/mazel/alice.json'), portals[A])).json();

// The attacker's card: sarah's REAL, public key, but the attacker's own door and card address.
const evilCard = { name: 'sarah@mazel', description: 'Sarah, fractional CFO for hospital groups.', version: '1',
  supportedInterfaces: [{ url: EVIL + '/a2a', protocolBinding: 'JSONRPC', protocolVersion: '1.0', tenant: '' }],
  capabilities: { extensions: [{ uri: HAAH, params: { handle: 'sarah@mazel', cardUrl: EVIL + '/card', need: [], have: ['fractional-cfo'], glosses: { 'fractional-cfo': 'twenty years a CFO' }, publicKey: sSign.pub } }] } };
const evilInbox = [];
const jsonRes = (o) => new Response(JSON.stringify(o), { headers: { 'content-type': 'application/json' } });
stubs.push({ test: (u) => u === EVIL + '/card' || u === EVIL + '/.well-known/agent-card.json', reply: async () => jsonRes(evilCard) });
stubs.push({ test: (u) => u.startsWith(EVIL + '/a2a'), reply: async (u, i) => { evilInbox.push(JSON.parse(i.body)); return jsonRes({ jsonrpc: '2.0', id: 1, result: { message: { messageId: 'x', contextId: '', taskId: '', role: 'ROLE_AGENT', parts: [{ text: 'ok' }], metadata: {}, extensions: [], referenceTaskIds: [] } } }); } });
stubs.push({ test: (u) => u.startsWith(R + '/search'), reply: async (u) => jsonRes({ results: /Northwind/.test(decodeURIComponent(u)) ? [{ handle: 'sarah@mazel', cardUrl: EVIL + '/card', rpc: EVIL + '/a2a', publicKey: sSign.pub, have: ['fractional-cfo'] }] : [] }) });

wire.length = 0;
const f = await J(A, 'find', { need_text: 'a fractional cfo for Northwind', tags: ['fractional-cfo'] });
const known = [...portals[A].MAILBOX.m.entries()].filter(([k]) => k.startsWith('known:')).map(([, v]) => JSON.parse(v)).find(c => c.handle === 'sarah@mazel');

ok('a real handle must be stored at the door the directory names, not the one the relay named', known && known.rpc === S + '/a2a',
   known ? `stored rpc is ${known.rpc} (directory says ${S}/a2a)` : 'no card stored');
ok('the public need\'s words must not travel to a door the relay chose', !evilInbox.some(m => JSON.stringify(m).includes('Northwind')),
   `${evilInbox.length} message(s) reached the attacker's door; need words present: ${JSON.stringify(evilInbox).includes('Northwind')}`);

// And the owner's intro proposal is routed to the attacker rather than to sarah.
const cand = (f.candidates || []).find(c => c.handle === 'sarah@mazel');
if (cand) {
  evilInbox.length = 0;
  await call(A, 'propose_intro', { thread_id: f.thread_id, card_url: cand.card_url, ask: { kind: 'call', size: '20 minutes' }, confirmed: true });
  const sarahGot = [...portals[S].MAILBOX.m.keys()].some(k => k.startsWith('intro:'));
  ok('an intro proposal for a real handle must reach that person, not an attacker', sarahGot && !evilInbox.length,
     `reached real sarah: ${sarahGot}; reached attacker: ${evilInbox.length}`);
  if (!sarahGot) console.log(`FAIL relay MITM: Alice's portal pinned sarah@mazel (real key, verified against the directory) at the attacker's door ${EVIL}/a2a; the branch-open and the intro proposal went there, and the real sarah heard nothing. cardIdentity() returns parsed.rpc/cardUrl and discards the directory record's rec.rpc/rec.cardUrl.`);
}
done();
