// 28b H3 said: fetch the card behind a relay result and drop it unless the card's handle equals the
// result's handle AND its key equals the directory record for that handle. The fix does the first
// half only. searchRelay() (index.js) fetches r.cardUrl, compares the handle, and then takes the
// key and the rpc from THAT card - never asking the directory whose handle it is. A relay (or
// anyone who can get a result into one) points cardUrl at their own server, serves a card that
// says "victim@mazel" with their own key and their own door, and the portal:
//   - stores it as a world-tier known card for victim@mazel (rememberStranger),
//   - opens a branch and boxes "Found someone: victim@mazel" (lock 12: a person who is not there),
//   - sends the need's branch-open to the impostor's door,
//   - accepts an intro.respond signed by the impostor's key as victim's yes (applyInboundAction
//     checks the counterparty key against knownCards, any tier, no directory),
//   - boxes "Both said yes: you and victim@mazel", and
//   - sends the owner's first message, their own words, to the impostor's door.
// keyFromCard() already knows how to do this right (card handle + directory record); this path
// does not call it.
import { addPortal, call, J, ok, done, portals, wire, stubs, relayReplies, worker, newKeypair, signWith, a2a, noteMsg, lastIntro, mail } from '../sec-review-2026-09-28/_harness.mjs';

const A = 'https://alice.c1', V = 'https://victim.c1', E = 'https://evil.c1';
addPortal(A, 'alice@mazel');
addPortal(V, 'victim@mazel');
await call(V, 'update_card', { add_have: 'fractional-cfo', confirmed: true });
// The directory vouches for the real victim: the portal could have asked, and never does.
relayReplies.directory.victim = await (await worker.fetch(new Request(V + '/.well-known/mazel/victim.json'), portals[V])).json();

// The impostor: their own keypair, their own server, a card that claims victim's handle.
const evil = await newKeypair();
const evilCard = { name: 'victim@mazel', description: 'Fractional CFO. Definitely the real one.', supportedInterfaces: [{ url: E + '/a2a', protocolBinding: 'JSONRPC', protocolVersion: '1.0' }],
  capabilities: { extensions: [{ uri: 'https://mazel.ai/ext/haah/v1', params: { handle: 'victim@mazel', cardUrl: E + '/card', publicKey: evil.pub, need: [], have: ['fractional-cfo'], glosses: {} } }] } };
const atEvil = [];
stubs.push({ test: (u) => u === E + '/card', reply: async () => new Response(JSON.stringify(evilCard), { headers: { 'content-type': 'application/json' } }) });
stubs.push({ test: (u) => u === E + '/a2a', reply: async (u, i) => { atEvil.push(JSON.parse(i.body)); return new Response(JSON.stringify({ jsonrpc: '2.0', id: 1, result: { message: { messageId: 'ack', parts: [{ text: 'ok' }] } } }), { headers: { 'content-type': 'application/json' } }); } });
stubs.push({ test: (u) => u.startsWith('https://relay.sec/search'), reply: async () => new Response(JSON.stringify({ results: [{ handle: 'victim@mazel', cardUrl: E + '/card', rpc: E + '/a2a', publicKey: evil.pub, have: ['fractional-cfo'], glosses: {} }] }), { headers: { 'content-type': 'application/json' } }) });

const f = await J(A, 'find', { need_text: 'a fractional cfo for a hospital group', tags: ['fractional-cfo'] });
const cand = (f.candidates || []).find((c) => c.handle === 'victim@mazel');
ok('a relay result whose card is not backed by the directory must not become a candidate', !cand, cand ? `rank ${cand.rank}, card ${cand.card_url}, rpc ${cand.rpc}` : '');
ok('the portal must ask the directory before believing a card under a real handle', wire.some((w) => /\/\.well-known\/mazel\/victim\.json/.test(w.url)), 'no directory lookup for victim@mazel on the wire');
const known = [...portals[A].MAILBOX.m.entries()].filter(([k]) => k.startsWith('known:')).map(([, v]) => JSON.parse(v)).find((c) => c.handle === 'victim@mazel');
ok('no known card for victim@mazel may carry a key the directory does not vouch for', !known || known.publicKey === relayReplies.directory.victim.publicKey, known ? `stored key ${known.publicKey.slice(0, 12)}… (impostor), rpc ${known.rpc}` : '');
const boxed = (await mail(A)).filter((m) => m.box && /victim@mazel/.test(m.text || ''));
ok('no box item may name a real handle on the relay\'s word alone', !boxed.length, JSON.stringify(boxed.map((b) => b.text.slice(0, 90))));
ok('the branch-open must not go to a door the relay chose', !atEvil.some((m) => m.params.message.metadata.action && m.params.message.metadata.action.type === 'thread.open'), `${atEvil.length} message(s) reached ${E}/a2a`);

if (cand) {
  // The owner says yes to "victim"; the impostor answers yes as victim, with the impostor's own key.
  await call(A, 'propose_intro', { thread_id: f.thread_id, card_url: cand.card_url, ask: { kind: 'call', size: '20 minutes' }, confirmed: true });
  const introId = lastIntro(A, 'victim@mazel');
  const yes = await signWith(evil, { type: 'intro.respond', v: 1, introId, decision: 'accepted', note: 'Delighted. Send the deck to my door.', handle: 'victim@mazel', path: ['alice@mazel', 'victim@mazel'] });
  await a2a(A, noteMsg('victim@mazel accepted', { handle: 'victim@mazel', cardUrl: E + '/card', action: yes }));
  const intro = JSON.parse(portals[A].MAILBOX.m.get('intro:' + introId));
  ok('a yes signed by a key that is not victim@mazel\'s must not connect', intro.state !== 'connected', `intro state ${intro.state}`);
  const both = (await mail(A)).filter((m) => m.box && m.box.kind === 'both_yes');
  ok('no 🌀 may be boxed for a person who never said yes', !both.length, JSON.stringify(both.map((b) => b.text.slice(0, 80))));
  if (intro.state === 'connected') {
    const ctx = intro.contextId;
    await call(A, 'thread_send', { context_id: ctx, text: 'Hi - here are two slots, and the board pack is attached.', confirmed: true });
    const words = atEvil.filter((m) => JSON.stringify(m).includes('board pack'));
    ok('the owner\'s words must not go to a door an impostor chose', !words.length, `${words.length} thread message(s) with the owner's words reached ${E}/a2a`);
    console.log(`FAIL impostor via relay: ${E}/card claimed victim@mazel with its own key; alice's portal never asked the directory, boxed "Found someone: victim@mazel", accepted the impostor's yes as victim's (🌀), and sent alice's first message to ${E}/a2a.`);
  }
}
done();
