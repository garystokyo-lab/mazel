// HIGH. The inbound gate's rule (index.js ~4155): "A card is a person only through (2) ... the
// card at the address the action gives, whose handle is that handle and whose key the directory's
// signed record for that handle names." pinIdentity() short-circuits (2) when the portal already
// HOLDS a non-world card for the handle: it returns that held key with no directory check. That is
// correct for cards the owner added by hand. But onTribeRoster() -> addKnownCard(url, tier:'tribe',
// by_hand:false) stores a tribe-tier card for ANY handle the organizer lists, taking the key from
// whatever card sits at the organizer-supplied url, with NO directory verification and NO continuity
// check. So a tribe organizer (a party the owner cleared only by accepting an invite) can plant an
// attacker-chosen key for a THIRD party's handle. pinIdentity then trusts the planted key over the
// directory, and the organizer can sign an intro.respond "as sarah" that verifies -> a fabricated
// "🌀 you and sarah both said yes", the real sarah never involved. Lock 12 break.
import { addPortal, call, J, ok, done, portals, stubs, newKeypair, signWith, signedAction, signingOf, a2a, noteMsg, lastIntro } from '../sec-review-2026-09-28/_harness.mjs';
import { HAAH } from '../a2a-helpers.mjs';

const A = 'https://alice-d1.test', ORG = 'https://org-d1.test', EVIL = 'https://evil-d1.example';
addPortal(A, 'alice@mazel');
addPortal(ORG, 'organizer@mazel');

// The impostor's card for a handle nobody here holds and the directory does not vouch for.
const ek = await newKeypair();
const evilCard = { name: 'sarah@mazel', description: 'Sarah, fractional CFO for hospital groups.', version: '1',
  supportedInterfaces: [{ url: EVIL + '/a2a', protocolBinding: 'JSONRPC', protocolVersion: '1.0', tenant: '' }],
  capabilities: { extensions: [{ uri: HAAH, params: { handle: 'sarah@mazel', cardUrl: EVIL + '/card', need: [], have: ['fractional-cfo'], glosses: { 'fractional-cfo': 'twenty years a CFO' }, publicKey: ek.pub } }] } };
const evilInbox = [];
const jsonRes = (o) => new Response(JSON.stringify(o), { headers: { 'content-type': 'application/json' } });
stubs.push({ test: (u) => u === EVIL + '/card' || u === EVIL + '/.well-known/agent-card.json', reply: async () => jsonRes(evilCard) });
stubs.push({ test: (u) => u.startsWith(EVIL + '/a2a'), reply: async (u, i) => { evilInbox.push(JSON.parse(i.body)); return jsonRes({ jsonrpc: '2.0', id: 1, result: { message: { messageId: 'x', contextId: '', taskId: '', role: 'ROLE_AGENT', parts: [{ text: 'ok' }], metadata: {}, extensions: [], referenceTaskIds: [] } } }); } });

// Alice joins the organizer's tribe the ordinary way.
await call(A, 'add_known_card', { url: ORG + '/card' });     // the organizer's card comes with the invitation
await call(ORG, 'add_known_card', { url: A + '/card' });
const tribeId = (await call(ORG, 'tribe_create', { name: 'Health Systems Circle', purpose: 'operators' })).match(/id is (\S+)/)[1];
await call(ORG, 'tribe_invite', { tribe_id: tribeId, handle: 'alice@mazel', confirmed: true });
const inviteId = [...portals[A].MAILBOX.m.entries()].filter(([k]) => k.startsWith('intro:')).map(([, v]) => JSON.parse(v)).find(i => i.direction === 'received' && i.origin === 'tribe').id;
await call(A, 'respond_intro', { intro_id: inviteId, decision: 'accepted', confirmed: true });

// The organizer now sends a roster that lists a third party's handle at the impostor's card.
const roster = await signedAction(await signingOf(ORG), { origin: ORG, handle: 'organizer@mazel' },
  { type: 'tribe.roster', tribeId, tribeName: 'Health Systems Circle', members: [{ handle: 'sarah@mazel', cardUrl: EVIL + '/card', rpc: EVIL + '/a2a' }] });
await a2a(A, noteMsg('roster', { handle: 'organizer@mazel', cardUrl: ORG + '/card', action: roster }));

const planted = [...portals[A].MAILBOX.m.entries()].filter(([k]) => k.startsWith('known:')).map(([, v]) => JSON.parse(v)).find(c => c.handle === 'sarah@mazel');
ok('a roster must not plant a key for a handle the directory never vouched for', !planted || planted.publicKey !== ek.pub,
   planted ? `alice now holds sarah@mazel at ${planted.tier} tier with the impostor's key ${String(planted.publicKey).slice(0, 12)}…, rpc ${planted.rpc}` : '');

// Drive it to the fabricated 🌀: sarah is now a candidate; Alice proposes; the impostor answers.
const f = await J(A, 'find', { need_text: 'a fractional cfo for Northwind', tags: ['fractional-cfo'] });
const cand = (f.candidates || []).find(c => c.handle === 'sarah@mazel');
if (cand) {
  await call(A, 'propose_intro', { thread_id: f.thread_id, card_url: cand.card_url, ask: { kind: 'call', size: '20 minutes' }, confirmed: true });
  const introId = lastIntro(A, 'sarah@mazel');
  const yes = await signWith(ek, { type: 'intro.respond', v: 1, introId, decision: 'accepted', note: 'Happy to. - S', castAt: new Date().toISOString(), handle: 'sarah@mazel', publicKey: ek.pub, cardUrl: EVIL + '/card', rpc: EVIL + '/a2a', path: ['alice@mazel', 'sarah@mazel'] });
  await a2a(A, noteMsg('sarah@mazel accepted', { handle: 'sarah@mazel', cardUrl: EVIL + '/card', action: yes }));
  const intro = JSON.parse(portals[A].MAILBOX.m.get('intro:' + introId) || 'null');
  const bothYes = [...portals[A].MAILBOX.m.values()].map(v => { try { return JSON.parse(v); } catch { return {}; } }).filter(m => m.box && m.box.kind === 'both_yes');
  ok('an intro.respond signed by a planted key must not connect as the real person', !intro || intro.state !== 'connected', intro && `intro state ${intro.state}`);
  ok('no 🌀 may be boxed for a person who never said yes', !bothYes.length, JSON.stringify(bothYes.map(b => b.text.slice(0, 80))));
  if (intro && intro.state === 'connected') console.log(`FAIL fabricated 🌀 via tribe roster: the organizer planted the impostor's key for sarah@mazel through onTribeRoster (no directory check), Alice's portal pinned it, and an intro.respond signed by that key was accepted as sarah's yes. The real sarah was never involved.`);
} else {
  console.log('FAIL note: sarah@mazel did not become a candidate; the planted card may not have scored, but the key-planting assertion above stands.');
}
done();
