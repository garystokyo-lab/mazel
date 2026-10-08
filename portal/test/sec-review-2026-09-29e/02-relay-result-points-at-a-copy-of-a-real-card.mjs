// HIGH. cardIdentity() (index.js ~4211) authenticates a search result by fetching the card at the
// address the relay named and checking that its handle and KEY match the directory record. Since
// 28d it takes the door and card address from the record. But it still returns the fetched card's
// CONTENT (`card: parsed`): searchRelay() then scores person.card.have / glosses / description and
// stores them under the real handle (rememberStranger). A public key is public, so anyone can host
// a copy of sarah's card with haves she does not have; a relay result pointing at the copy makes
// the real sarah a candidate for anything, ✨ "Found someone for your need: sarah, on X" lands in
// the box, a branch carrying the need goes to sarah's real door, and the world-tier card this
// portal holds for sarah now says she does X. A fabricated match under a real handle (lock 12).
// Who can put such a result on the relay: the relay itself, or - for any handle whose directory
// is not the relay (name@company.com, §6.4) - any anonymous caster, because relay cast() only ties
// a handle to a key when the relay's own directory holds that name.
import { addPortal, call, J, ok, done, portals, stubs, wire, R, relayReplies, worker, signingOf, keys } from '../sec-review-2026-09-28/_harness.mjs';
import { HAAH } from '../a2a-helpers.mjs';
import relay from '../../../relay/src/index.js';
import { mkKV, newKeypair, signWith } from '../sec-review-2026-09-28/_harness.mjs';

const A = 'https://alice-e2.test', S = 'https://contoso-e2.test', EVIL = 'https://evil-e2.example', MAL = 'https://mallory-e2.test';
addPortal(A, 'alice@mazel'); addPortal(S, 'sarah@contoso-e2.test'); addPortal(MAL, 'mallory@mazel');
// The real sarah: a real portal on her company's domain, which serves her own directory record. She is a pediatric nurse.
await call(S, 'update_card', { add_have: 'pediatric-nursing', confirmed: true });
relayReplies.directory.alice = await (await worker.fetch(new Request(A + '/.well-known/mazel/alice.json'), portals[A])).json();
const realCard = await (await worker.fetch(new Request(S + '/.well-known/agent-card.json'), portals[S])).json();
const sKey = realCard.capabilities.extensions.find((e) => e.uri === HAAH).params.publicKey;

// The copy: sarah's handle, sarah's real public key, and a have she never claimed.
const copy = { ...realCard, description: 'Sarah, fractional CFO for hospital groups.', capabilities: { extensions: [{ uri: HAAH, params: { ...realCard.capabilities.extensions[0].params, cardUrl: EVIL + '/card', have: ['fractional-cfo'], glosses: { 'fractional-cfo': 'twenty years a CFO' } } }] } };
const jsonRes = (o) => new Response(JSON.stringify(o), { headers: { 'content-type': 'application/json' } });
stubs.push({ test: (u) => u === EVIL + '/card' || u === EVIL + '/.well-known/agent-card.json', reply: async () => jsonRes(copy) });

// The real relay code, in process, with its own store: mallory (any key) casts a card-cast under
// sarah's handle that points at the copy. The relay's cast() accepts it: contoso is not its directory.
const relayEnv = { RELAY: mkKV() };
stubs.push({ test: (u) => u.startsWith(R + '/'), reply: async (u, i) => relay.fetch(new Request(u, i), relayEnv) });
const ms = await signingOf(MAL);
const cast = await signWith(ms, { v: 1, kind: 'card', visibility: 'public', handle: 'sarah@contoso-e2.test', publicKey: ms.pub, cardUrl: EVIL + '/card', rpc: EVIL + '/a2a', castAt: new Date().toISOString(), have: ['fractional-cfo'], glosses: { 'fractional-cfo': 'twenty years a CFO' }, description: 'Sarah, fractional CFO for hospital groups.' });
const cr = await (await fetch(R + '/cast', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(cast) })).json();
ok('precondition: the relay took an anonymous card-cast under a handle its directory does not hold', cr.ok === true, JSON.stringify(cr).slice(0, 120));

wire.length = 0;
const f = await J(A, 'find', { need_text: 'a fractional cfo for a hospital group', tags: ['fractional-cfo'] });
const cand = (f.candidates || []).find((c) => c.handle === 'sarah@contoso-e2.test');
const known = keys(A, 'known:').map((k) => JSON.parse(portals[A].MAILBOX.m.get(k))).find((c) => c.handle === 'sarah@contoso-e2.test');
const boxes = [...portals[A].MAILBOX.m.values()].map((v) => { try { return JSON.parse(v); } catch { return {}; } }).filter((m) => m.box && m.box.kind === 'found_for_you' && /sarah@contoso/.test(m.text));
ok('a real handle must not become a candidate on the strength of a card nobody at that handle serves', !cand, cand ? `candidate: ${cand.why}` : '');
ok('no ✨ may land in the box for a match the person\'s own card does not make', !boxes.length, boxes.map((b) => b.text.slice(0, 100)).join(' | '));
ok('a card held under a real handle carries only what that handle\'s own card says', !known || !(known.have || []).includes('fractional-cfo'), known ? `stored have: ${known.have.join(', ')}; key matches directory: ${known.publicKey === sKey}` : '');
ok('the need must not travel to sarah as a branch she was matched to by someone else\'s copy', !keys(S, 'conv:').length, `${keys(S, 'conv:').length} branch(es) on the real sarah's portal`);
if (cand) console.log(`FAIL fabricated match: the relay result pointed at ${EVIL}/card, cardIdentity() matched its key to sarah's directory record and returned the COPY's content; alice's box says "${(boxes[0] || {}).text || ''}" and her world-tier card for sarah now lists fractional-cfo. The cast that did it was signed by mallory's key and accepted because contoso is not the relay's directory.`);
done();
