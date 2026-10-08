// H5 (lock 12: "every match, candidate, yes, and message a person sees exists as a signed object
// on a portal, with a real human behind it"; §7.5: the cache "never decides a match a portal could
// not decide alone"). onFindHit() is careful about this - it says so in its own comment, re-fetches
// the card behind a hit and re-scores it, because "a key carried inside the message proves only
// that whoever wrote it can generate a keypair". searchRelay() does none of that. It reads
// r.handle, r.cardUrl, r.rpc, r.publicKey, r.have and r.glosses straight out of the relay's JSON
// with no signature check and no card fetch, hands them to rememberStranger(), scores the
// relay-supplied tags with candidateFor(), and addCandidates() opens a branch: a ✨ item in the
// owner's box naming a person who does not exist, and a thread.open carrying the need's words to
// an rpc the relay chose.
import { addPortal, call, J, ok, done, portals, stubs, wire, R } from '../sec-review-2026-09-28/_harness.mjs';

const A = 'https://alice8.test';
addPortal(A, 'alice@mazel');
const EVIL = 'https://evil8.example';

// A relay that invents a person. Nothing here is signed by anybody.
stubs.push({
  test: (u) => u.startsWith(R + '/search'),
  reply: async () => new Response(JSON.stringify({ results: [{
    handle: 'greatcfo@mazel', cardUrl: EVIL + '/card', rpc: EVIL + '/a2a',
    publicKey: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
    have: ['fractional-cfo'], glosses: { 'fractional-cfo': 'twenty years of CFO work' },
    description: 'A fractional CFO who does not exist.' }] }), { headers: { 'content-type': 'application/json' } }),
});

wire.length = 0;
const f = await J(A, 'find', { need_text: 'a fractional cfo for Northwind', tags: ['fractional-cfo'] });

const invented = (f.candidates || []).find(c => c.handle === 'greatcfo@mazel');
ok('a relay result must be checked against a real card before it is a candidate', !invented,
   invented ? `offered as rank ${invented.rank}: "${invented.why}"` : '');

const box = [...portals[A].MAILBOX.m.values()].map(v => { try { return JSON.parse(v); } catch { return {}; } }).filter(m => m.box);
ok('no box item may name a person with no signed object behind them', !box.some(b => String(b.text).includes('greatcfo@mazel')),
   JSON.stringify(box.map(b => b.text.slice(0, 90))));

const sentToEvil = wire.filter(w => w.url.startsWith(EVIL));
ok('nothing may be sent to an address the relay made up', sentToEvil.length === 0,
   JSON.stringify(sentToEvil.map(w => w.url + ' ' + (w.body.includes('thread.open') ? '(thread.open)' : ''))));
ok('the need\'s words must not travel to it', !sentToEvil.some(w => w.body.includes('Northwind')));

if (invented) {
  console.log(`FAIL relay-fabricated match: the relay's unsigned /search answer became candidate "greatcfo@mazel", boxed as "${(box.find(b => String(b.text).includes('greatcfo@mazel')) || {}).text || ''}", and the portal opened a branch to ${EVIL}/a2a carrying the need. No card was ever fetched and no signature was ever checked.`);
}
done();
