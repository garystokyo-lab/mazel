// Item 1: a forwarded offer. onNeedOffer (index.js ~5690) refuses a second copy of the same offer at
// the same portal (seen-offer:<needId>:<handle>) and accepts an offer only from a card this portal
// holds. It never asks whether the offer was for this portal: the signed body carries no recipient,
// so a receiver that holds the caster's card cannot tell an offer the caster sent it from one
// somebody else passed along. Lea offers a need to Avery, whom she holds. Cam holds Lea's card, but
// Lea does not hold Cam's and never offered him anything. Avery (or anyone who saw the bytes) posts
// the same signed envelope at Cam's door.
import { addPortal, call, J, ok, done, portals, wire, keys, asks, placeAndFind, hold, a2aRaw, ackOf } from './_h.mjs';
const A = 'https://avery-07a1.test', B = 'https://lea-07a1.test', C = 'https://cam-07a1.test';
addPortal(A, 'avery@mazel'); addPortal(B, 'lea@mazel'); addPortal(C, 'cam@mazel');
await hold(B, A);          // Lea holds Avery: Avery is who she offers to
await hold(A, B);          // Avery holds Lea: the gate at Avery's door knows her key
await hold(C, B);          // Cam holds Lea; Lea does not hold Cam
for (const o of [A, C]) await call(o, 'contacts', { action: 'note', name: `Omar at ${o.includes('avery') ? 'Coil' : 'Vane'}`, org: o.includes('avery') ? 'coil.example' : 'vane.example', have: ['heat-exchangers'], role: 'Built heat exchangers and chillers for twenty years', witnesses: ['gmail'], small_meetings: 7, deals: 1, best_stage: 'won', threads_sent: 14, threads_replied: 11 });

// ---- a public need ---------------------------------------------------------------------------
let mark = wire.length;
const f = await placeAndFind(B, 'heat-exchangers', 'someone who knows heat exchangers and chillers');
const toA = wire.slice(mark).find((w) => w.url === A + '/a2a' && w.body.includes('need.offer'));
ok('precondition: Lea offered the need to Avery, whom she holds', !!toA);
ok('precondition: Lea sent nothing to Cam, whom she does not hold', !wire.slice(mark).some((w) => w.url.startsWith(C) && w.body.includes('need.offer')));
ok('precondition: the offer raised one question at Avery', (await asks(A)).length === 1);
// 1. Replay at the same door: refused (holds).
const beforeA = keys(A, 'ghostask:').length;
await a2aRaw(A, toA.body);
ok('a replay at the door it was sent to raises nothing', keys(A, 'ghostask:').length === beforeA);
// 2. Forwarded to a door the caster never chose.
const camBefore = keys(C, 'ghostask:').length;
const res = await a2aRaw(C, toA.body);
const ack = await ackOf(res);
ok('the forwarded copy is acked at Cam\'s door like an honest offer', /Delivered/.test(ack), ack);
const camAsks = await asks(C);
ok('FINDING: a forwarded offer is accepted by a portal the caster never offered it to', keys(C, 'ghostask:').length === camBefore, `ghostask records at Cam: ${camBefore} -> ${keys(C, 'ghostask:').length}`);
ok('FINDING: and it becomes a question for Cam about one of Cam\'s contacts', camAsks.length === 0, camAsks.map((m) => m.text.slice(0, 120)).join(' | '));
ok('FINDING: the body has nothing that says who it was for', !/"to"|"recipient"|"for"/.test(JSON.stringify(JSON.parse(toA.body).params.message.metadata.action)), Object.keys(JSON.parse(toA.body).params.message.metadata.action).join(','));

// ---- a need being held back: the fingerprint leaves the circle the owner drew ------------------
mark = wire.length;
await call(B, 'update_card', { remove_need: 'heat-exchangers', confirmed: true });
const f2 = await placeAndFind(B, 'cold-chain-logistics', 'cold chain logistics for frozen vaccines and refrigerated trucks', 'matched-only');
const blind = wire.slice(mark).find((w) => w.url === A + '/a2a' && w.body.includes('need.offer') && w.body.includes('"fp"'));
ok('precondition: the held need went to Avery as buckets only', !!blind && !blind.body.includes('vaccines') && !blind.body.includes('cold-chain'), blind ? 'fp only' : 'no blind offer');
ok('precondition: Cam is outside the circle Lea drew for it', !wire.slice(mark).some((w) => w.url.startsWith(C) && w.body.includes('"fp"')));
for (const o of [C]) await call(o, 'contacts', { action: 'note', name: 'Priya at Frost', org: 'frost.example', have: ['cold-chain-logistics'], role: 'Runs cold chain logistics for frozen vaccines in refrigerated trucks', witnesses: ['gmail'], small_meetings: 5, threads_sent: 9, threads_replied: 8 });
const camBefore2 = keys(C, 'ghostask:').length;
await a2aRaw(C, blind.body);
const camAsks2 = (await asks(C)).filter((m) => /Priya/.test(m.text));
ok('FINDING: the buckets of a held-back need are accepted and scored by a portal outside the circle the owner drew (§3.6)', keys(C, 'ghostask:').length === camBefore2 && camAsks2.length === 0, camAsks2.map((m) => m.text.slice(0, 140)).join(' | '));
done();
