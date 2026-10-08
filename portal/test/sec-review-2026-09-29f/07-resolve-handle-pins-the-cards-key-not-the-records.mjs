// LOW. resolveHandleTool() (index.js ~2456-2461): resolveHandle() verifies the directory record and
// its key, then addKnownCard({ url: rec.cardUrl }) - a by-hand add - fetches the card at that url and
// stores whatever key THAT CARD carries, never comparing it to rec.publicKey (the by-hand path only
// compares against a key already held, ~2529). The tool text says it "verifies the record is signed
// by the key it names, then stores the card behind it"; the record's key is checked and then not
// used. A card host that disagrees with the record - a stale cache, a re-registered workers.dev
// name, a taken-over host - gets its key pinned under the handle, by hand, at tribe tier. From then
// on pinIdentity() short-circuits the directory for that handle, and a proposal signed by the
// card's key verifies as the person. cardIdentity(), the gate's own path, refuses this exact card.
import { addPortal, call, ok, done, portals, worker, relayReplies, stubs, newKeypair, signWith, a2a, noteMsg } from '../sec-review-2026-09-28/_harness.mjs';

const A = 'https://alice-f7.test', S = 'https://sarah-f7.test', EVIL = 'https://evil-f7.example';
addPortal(A, 'alice@mazel'); addPortal(S, 'sarah@mazel');
relayReplies.directory.sarah = await (await worker.fetch(new Request(`${S}/.well-known/mazel/sarah.json`), portals[S])).json();
// The host the record points at now serves sarah's card with a different key and a different door.
const evil = await newKeypair();
const real = await (await worker.fetch(new Request(S + '/card'), portals[S])).json();
const swapped = JSON.parse(JSON.stringify(real));
swapped.capabilities.extensions[0].params.publicKey = evil.pub;
swapped.supportedInterfaces[0].url = EVIL + '/a2a';
stubs.push({ test: (u) => u === S + '/.well-known/agent-card.json' || u === S + '/card', reply: async () => new Response(JSON.stringify(swapped), { headers: { 'content-type': 'application/json' } }) });

const said = await call(A, 'resolve_handle', { handle: 'sarah@mazel' });
const known = [...portals[A].MAILBOX.m.entries()].filter(([k]) => k.startsWith('known:')).map(([, v]) => JSON.parse(v)).find((c) => c.handle === 'sarah@mazel');
const recKey = relayReplies.directory.sarah.publicKey;
ok('resolve_handle pins the key the record names, or nothing', !known || known.publicKey === recKey, known ? `pinned ${known.publicKey.slice(0, 10)}… at ${known.tier}; the record says ${recKey.slice(0, 10)}…; door ${known.rpc}` : said.slice(0, 120));

// The pinned key is held by hand now, so the gate takes it as sarah without asking the directory.
const introId = 'f7' + 'd'.repeat(30);
const prop = await signWith(evil, { v: 1, type: 'intro.propose', handle: 'sarah@mazel', publicKey: evil.pub, cardUrl: S + '/.well-known/agent-card.json', rpc: EVIL + '/a2a', castAt: new Date().toISOString(),
  introId, why: 'Sarah here; let us talk about the Northwind seat.', needText: '', needTags: [], matchedTags: [], path: ['sarah@mazel'], proposer: { handle: 'sarah@mazel', cardUrl: S + '/.well-known/agent-card.json', rpc: EVIL + '/a2a' }, ask: { kind: 'call', size: '' }, contextId: 'f7' + 'e'.repeat(30) });
await a2a(A, noteMsg('Intro proposal from sarah@mazel.', { handle: 'sarah@mazel', cardUrl: S + '/.well-known/agent-card.json', action: prop }));
const intro = JSON.parse(portals[A].MAILBOX.m.get('intro:' + introId) || 'null');
ok('a proposal signed by a key the directory does not name for sarah is refused', !intro, intro ? `stored as from ${intro.from.handle}, verified: ${intro.verified}; the answer would go to ${intro.from.rpc}` : '');
done();
