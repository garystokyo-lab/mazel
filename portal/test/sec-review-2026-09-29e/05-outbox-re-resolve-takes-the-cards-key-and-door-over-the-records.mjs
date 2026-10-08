// LOW. reResolveRpc() (index.js ~2215), the moved-portal path used by deliverResilient and the
// outbox sweep: it resolves the handle (record signed, continuity against the held key: good),
// then fetches rec.cardUrl and stores `publicKey: parsed.publicKey || held.publicKey` and
// `rpc: parsed.rpc` from the CARD, on the held card and on every thread participant with that
// handle - never comparing the card's key to rec.publicKey, never checking the card's handle, and
// discarding rec.rpc. The continuity check is against the record; what gets stored is the card. A
// card host that disagrees with the signed record (a stale or poisoned cache, a taken-over host)
// therefore rebinds a by-hand held card's key and door with no rotation chain, on a path the owner
// never sees (it runs inside a failed send). Low: it needs the person's own card host to serve
// something their record does not say; but it is the one remaining path that writes a key without
// the directory naming it, and it rebinds cards held by hand, which addKnownCard now refuses to do.
import { addPortal, call, J, ok, done, portals, stubs, wire, relayReplies, worker, newKeypair, signingOf, keys, lastIntro } from '../sec-review-2026-09-28/_harness.mjs';
import { HAAH } from '../a2a-helpers.mjs';

const A = 'https://alice-e5.test', S = 'https://sarah-e5.test', EVIL = 'https://evil-e5.example';
addPortal(A, 'alice@mazel'); addPortal(S, 'sarah@mazel');
await call(S, 'update_card', { add_have: 'fractional-cfo', confirmed: true });
relayReplies.directory.alice = await (await worker.fetch(new Request(A + '/.well-known/mazel/alice.json'), portals[A])).json();
relayReplies.directory.sarah = await (await worker.fetch(new Request(S + '/.well-known/mazel/sarah.json'), portals[S])).json();   // honest: sarah's key, sarah's door
const sSign = await signingOf(S);

// Alice holds sarah by hand, from the real card.
await call(A, 'add_known_card', { url: S + '/card' });
const before = keys(A, 'known:').map((k) => JSON.parse(portals[A].MAILBOX.m.get(k))).find((c) => c.handle === 'sarah@mazel');
ok('precondition: alice holds sarah\'s real key and door', before && before.publicKey === sSign.pub && before.rpc === S + '/a2a', before ? `${before.rpc}` : '');

// Then sarah's door goes dark, and the card served at the address her record names disagrees with
// the record: a different key and a different door.
const jsonRes = (o) => new Response(JSON.stringify(o), { headers: { 'content-type': 'application/json' } });
const other = await newKeypair();
const realCard = await (await worker.fetch(new Request(S + '/.well-known/agent-card.json'), portals[S])).json();
const doctored = { ...realCard, supportedInterfaces: [{ url: EVIL + '/a2a', protocolBinding: 'JSONRPC', protocolVersion: '1.0', tenant: '' }],
  capabilities: { extensions: [{ uri: HAAH, params: { ...realCard.capabilities.extensions[0].params, publicKey: other.pub } }] } };
const evilInbox = [];
stubs.push({ test: (u) => u.startsWith(S + '/a2a'), reply: async () => new Response('gone', { status: 503 }) });
stubs.push({ test: (u) => u === S + '/.well-known/agent-card.json', reply: async () => jsonRes(doctored) });
stubs.push({ test: (u) => u.startsWith(EVIL + '/a2a'), reply: async (u, i) => { evilInbox.push(JSON.parse(i.body)); return jsonRes({ jsonrpc: '2.0', id: 1, result: { message: { messageId: 'x', contextId: '', taskId: '', role: 'ROLE_AGENT', parts: [{ text: 'ok' }], metadata: {}, extensions: [], referenceTaskIds: [] } } }); } });

const f = await J(A, 'find', { need_text: 'a fractional cfo for Northwind', tags: ['fractional-cfo'] });
const cand = f.candidates.find((c) => c.handle === 'sarah@mazel');
await call(A, 'propose_intro', { thread_id: f.thread_id, card_url: cand.card_url, ask: { kind: 'call', size: '20 minutes' }, confirmed: true });
const after = keys(A, 'known:').map((k) => JSON.parse(portals[A].MAILBOX.m.get(k))).find((c) => c.handle === 'sarah@mazel');
ok('a held key changes only through a signed rotation chain, never from a card the record does not vouch for', after && after.publicKey === sSign.pub, after ? `held key is now ${after.publicKey === other.pub ? 'the card\'s unproven key' : after.publicKey.slice(0, 12) + '…'}` : 'card gone');
ok('a moved portal is followed to the record\'s door, not the card\'s', after && after.rpc === S + '/a2a', after ? `rpc now ${after.rpc} (record says ${S}/a2a)` : '');
ok('nothing is delivered to a door the record does not name', !evilInbox.length, `${evilInbox.length} message(s) at ${EVIL}`);
if (after && after.publicKey === other.pub) console.log(`FAIL re-resolve rebinding: one failed send made reResolveRpc store the card's key ${other.pub.slice(0, 12)}… and door ${after.rpc} for sarah@mazel, a card alice added by hand, although the signed record names ${sSign.pub.slice(0, 12)}… at ${S}/a2a and no rotation chain exists.`);
done();
