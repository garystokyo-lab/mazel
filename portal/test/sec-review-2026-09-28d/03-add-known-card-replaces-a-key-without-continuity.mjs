// LOW. resolve_handle enforces continuity: if the portal already holds a key for a handle and the
// directory now shows a different one, it refuses unless a signed rotation chain leads from the old
// key to the new (resolveHandle, index.js ~2205). But add_known_card(url) takes a raw card url and
// stores parsed.publicKey with NO continuity check and NO directory check, overwriting the key held
// for that handle (addKnownCard, ~2492: `publicKey: parsed.publicKey`, no compare to prev). So a
// second add_known_card for a handle the owner already holds - a url an attacker talked them into,
// or a card whose host was swapped - silently repoints the pinned identity to a new key, with none
// of the continuity resolve_handle would apply. The key is the identity; replacing it should demand
// a rotation, on every path that pins it.
import { addPortal, call, ok, done, portals, stubs, newKeypair } from '../sec-review-2026-09-28/_harness.mjs';
import { HAAH } from '../a2a-helpers.mjs';

const A = 'https://alice-d3.test', S1 = 'https://sarah-real-d3.test', S2 = 'https://sarah-swap-d3.example';
addPortal(A, 'alice@mazel');

const real = await newKeypair(), other = await newKeypair();
const jsonRes = (o) => new Response(JSON.stringify(o), { headers: { 'content-type': 'application/json' } });
const cardAt = (rpcBase, cardBase, pub) => ({ name: 'sarah@mazel', description: 'Sarah, fractional CFO.', version: '1',
  supportedInterfaces: [{ url: rpcBase + '/a2a', protocolBinding: 'JSONRPC', protocolVersion: '1.0', tenant: '' }],
  capabilities: { extensions: [{ uri: HAAH, params: { handle: 'sarah@mazel', cardUrl: cardBase + '/card', need: [], have: ['fractional-cfo'], glosses: {}, publicKey: pub } }] } });
stubs.push({ test: (u) => u === S1 + '/card', reply: async () => jsonRes(cardAt(S1, S1, real.pub)) });
stubs.push({ test: (u) => u === S2 + '/card', reply: async () => jsonRes(cardAt(S2, S2, other.pub)) });

await call(A, 'add_known_card', { url: S1 + '/card', tier: 'inner' });
const before = [...portals[A].MAILBOX.m.entries()].filter(([k]) => k.startsWith('known:')).map(([, v]) => JSON.parse(v)).find(c => c.handle === 'sarah@mazel');
ok('sarah is held with her first key', before && before.publicKey === real.pub);

// A second add for the same handle at a different url, serving a different key.
await call(A, 'add_known_card', { url: S2 + '/card' });
const after = [...portals[A].MAILBOX.m.entries()].filter(([k]) => k.startsWith('known:')).map(([, v]) => JSON.parse(v)).find(c => c.handle === 'sarah@mazel');
ok('add_known_card must not silently replace a held key without a rotation chain', after && after.publicKey === real.pub,
   after ? `pinned key is now ${after.publicKey === other.pub ? "the new (unproven) key" : "unchanged"}; rpc ${after.rpc}` : 'card gone');
if (after && after.publicKey === other.pub) console.log(`FAIL key swapped with no continuity: add_known_card repointed sarah@mazel from her held key to an unproven one off a different url, something resolve_handle refuses. Every later intro and thread message now verifies against the new key.`);
done();
