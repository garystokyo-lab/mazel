// LOW. addKnownCard() (index.js ~2492), the by-hand path: the 28d continuity guard fires only when
// `prev.publicKey && parsed.publicKey && prev.publicKey !== parsed.publicKey`. A card with NO key -
// a plain A2A agent card whose `name` is a handle this portal already holds - skips it, and the
// held card is overwritten with `publicKey: null` and the stranger's door. The gate then falls back
// to the directory for that handle's key (so nothing fabricated verifies), but every place that
// reads the held card's door - propose_intro, openThreadFromIntro, tierForPull, rosters - now has
// the stranger's, and the held tier stays. One pasted link ("here is Sarah's new card") does it.
// Low, owner-initiated, the same class as 28d L1; one line to close (a missing key is a different
// key).
import { addPortal, call, J, ok, done, portals, stubs, wire, relayReplies, worker, signingOf, keys } from '../sec-review-2026-09-28/_harness.mjs';

const A = 'https://alice-e6.test', S = 'https://sarah-e6.test', EVIL = 'https://evil-e6.example';
addPortal(A, 'alice@mazel'); addPortal(S, 'sarah@mazel');
await call(S, 'update_card', { add_have: 'fractional-cfo', confirmed: true });
relayReplies.directory.sarah = await (await worker.fetch(new Request(S + '/.well-known/mazel/sarah.json'), portals[S])).json();
relayReplies.directory.alice = await (await worker.fetch(new Request(A + '/.well-known/mazel/alice.json'), portals[A])).json();
const sSign = await signingOf(S);
await call(A, 'add_known_card', { url: S + '/card', tier: 'inner' });

// A plain A2A card, no Mazel extension, no key, named after sarah, at a stranger's address.
const jsonRes = (o) => new Response(JSON.stringify(o), { headers: { 'content-type': 'application/json' } });
stubs.push({ test: (u) => u === EVIL + '/card', reply: async () => jsonRes({ name: 'sarah@mazel', description: 'Sarah (new portal).', version: '1', supportedInterfaces: [{ url: EVIL + '/a2a', protocolBinding: 'JSONRPC', protocolVersion: '1.0', tenant: '' }], capabilities: {}, skills: [] }) });
const evilInbox = [];
stubs.push({ test: (u) => u.startsWith(EVIL + '/a2a'), reply: async (u, i) => { evilInbox.push(JSON.parse(i.body)); return jsonRes({ jsonrpc: '2.0', id: 1, result: { message: { messageId: 'x', contextId: '', taskId: '', role: 'ROLE_AGENT', parts: [{ text: 'ok' }], metadata: {}, extensions: [], referenceTaskIds: [] } } }); } });

let said = '';
try { said = await call(A, 'add_known_card', { url: EVIL + '/card' }); } catch (e) { said = 'refused: ' + e.message; }
const held = keys(A, 'known:').map((k) => JSON.parse(portals[A].MAILBOX.m.get(k))).find((c) => c.handle === 'sarah@mazel');
ok('a held key is never replaced by no key', held && held.publicKey === sSign.pub, held ? `key now ${held.publicKey === null ? 'null' : held.publicKey.slice(0, 12) + '…'}; tool said: ${said.slice(0, 80)}` : 'card gone');
ok('a held door is never replaced on the say-so of a keyless card', held && held.rpc === S + '/a2a', held ? `rpc now ${held.rpc}` : '');
ok('the tier the owner chose is kept', held && held.tier === 'inner', held ? held.tier : '');

// The consequence: the owner's next proposal to sarah goes to the stranger.
const f = await J(A, 'find', { need_text: 'a fractional cfo for Northwind', tags: ['fractional-cfo'] });
const cand = f.candidates.find((c) => c.handle === 'sarah@mazel');
if (cand) {
  await call(A, 'propose_intro', { thread_id: f.thread_id, card_url: cand.card_url, ask: { kind: 'call', size: '20 minutes' }, confirmed: true });
  ok('an intro proposal for a held handle reaches that person\'s door', !evilInbox.length && keys(S, 'intro:').length > 0, `at the stranger: ${evilInbox.length}; at sarah: ${keys(S, 'intro:').length}`);
}
done();
