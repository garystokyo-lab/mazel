// HIGH (same root as 02, second instance). addKnownCard(by_hand: false) - the roster path - now
// requires the card at the organizer's url to carry the directory's key and takes the DOOR from
// the record (28d H1 fix), but it still stores that card's need / have / glosses / description
// (index.js ~2540: `need: parsed.need, have: parsed.have, ...`). So an organizer lists a real
// member's handle at a copy of their card with invented haves, and the member lands at TRIBE tier
// with those haves: they become a candidate for needs they cannot answer, ✨ lands, and tribe-held
// needs travel to them on the strength of tags the organizer wrote. The key check passes because a
// public key is public. What a handle has is that handle's card's to say - the card at rec.cardUrl.
import { addPortal, call, J, ok, done, portals, stubs, relayReplies, worker, signedAction, signingOf, a2a, noteMsg, keys } from '../sec-review-2026-09-28/_harness.mjs';
import { HAAH } from '../a2a-helpers.mjs';

const A = 'https://alice-e2b.test', ORG = 'https://org-e2b.test', S = 'https://sarah-e2b.test', EVIL = 'https://evil-e2b.example';
addPortal(A, 'alice@mazel'); addPortal(ORG, 'organizer@mazel'); addPortal(S, 'sarah@mazel');
await call(S, 'update_card', { add_have: 'pediatric-nursing', confirmed: true });
for (const [o, n] of [[A, 'alice'], [ORG, 'organizer'], [S, 'sarah']]) relayReplies.directory[n] = await (await worker.fetch(new Request(`${o}/.well-known/mazel/${n}.json`), portals[o])).json();
const realCard = await (await worker.fetch(new Request(S + '/.well-known/agent-card.json'), portals[S])).json();
const copy = { ...realCard, description: 'Sarah, fractional CFO for hospital groups.', capabilities: { extensions: [{ uri: HAAH, params: { ...realCard.capabilities.extensions[0].params, cardUrl: EVIL + '/card', have: ['fractional-cfo'], glosses: { 'fractional-cfo': 'twenty years a CFO' } } }] } };
const jsonRes = (o) => new Response(JSON.stringify(o), { headers: { 'content-type': 'application/json' } });
stubs.push({ test: (u) => u === EVIL + '/card', reply: async () => jsonRes(copy) });

// Alice joins the organizer's tribe the ordinary way.
await call(A, 'add_known_card', { url: ORG + '/card' });
await call(ORG, 'add_known_card', { url: A + '/card' });
const tribeId = (await call(ORG, 'tribe_create', { name: 'Health Systems Circle', purpose: 'operators' })).match(/id is (\S+)/)[1];
await call(ORG, 'tribe_invite', { tribe_id: tribeId, handle: 'alice@mazel', confirmed: true });
const inviteId = keys(A, 'intro:').map((k) => JSON.parse(portals[A].MAILBOX.m.get(k))).find((i) => i.direction === 'received' && i.origin === 'tribe').id;
await call(A, 'respond_intro', { intro_id: inviteId, decision: 'accepted', confirmed: true });

// The roster lists the real sarah at the copy.
const roster = await signedAction(await signingOf(ORG), { origin: ORG, handle: 'organizer@mazel' }, { type: 'tribe.roster', tribeId, tribeName: 'Health Systems Circle', members: [{ handle: 'sarah@mazel', cardUrl: EVIL + '/card', rpc: EVIL + '/a2a' }] });
await a2a(A, noteMsg('roster', { handle: 'organizer@mazel', cardUrl: ORG + '/card', action: roster }));
const held = keys(A, 'known:').map((k) => JSON.parse(portals[A].MAILBOX.m.get(k))).find((c) => c.handle === 'sarah@mazel');
ok('precondition: the roster stored sarah with the directory\'s key and door', held && held.publicKey === relayReplies.directory.sarah.publicKey && held.rpc === S + '/a2a', held ? `${held.tier}, ${held.rpc}` : 'not stored');
ok('what a member has comes from the card their record names, not from where the roster pointed', held && !(held.have || []).includes('fractional-cfo'), held ? `have: ${held.have.join(', ')} (her card says pediatric-nursing)` : '');

const f = await J(A, 'find', { need_text: 'a fractional cfo for a hospital group', tags: ['fractional-cfo'] });
const cand = (f.candidates || []).find((c) => c.handle === 'sarah@mazel');
ok('a tribe member is not a candidate on haves the organizer wrote for them', !cand, cand ? `${cand.tier}: ${cand.why}` : '');
if (cand) console.log(`FAIL roster-planted haves: sarah@mazel is a ${cand.tier}-tier candidate for fractional-cfo on alice's portal; her own card says pediatric-nursing. The roster's card copy passed the key check and its content was stored.`);
done();
