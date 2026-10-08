// MEDIUM. findInKnownCards() (index.js ~2854-2859) scores every card the portal holds, world tier
// included, and opens a branch to each one that fits. openBranch() (~4791) refuses directed, tribe
// and inner, and for matched-only sends buckets and the matched tags (needParts). It never looks at
// the candidate's tier. §3.6 decided that blind casts "go to known cards at tribe and inner only by
// default", because four buckets confirm a guessed need to one in ten to the twelfth, and
// castBlindNeed() (~3355) honours that on every pulse. The find path does not: a card that drifted
// in from the relay or a gossip hop - a stranger, held at world - gets the fingerprint the moment the
// owner's agent runs find on the held need, which is how a held need is meant to be searched.
import { addPortal, call, J, ok, done, portals, stubs, wire, pulse } from '../sec-review-2026-09-28/_harness.mjs';

const B = 'https://bob-f6.test', W = 'https://world-f6.example';
addPortal(B, 'bob@mazel');
const atW = [];
const ack = { jsonrpc: '2.0', id: 1, result: { message: { messageId: 'x', contextId: '', taskId: '', role: 'ROLE_AGENT', parts: [{ text: 'ok' }], metadata: {}, extensions: [], referenceTaskIds: [] } } };
stubs.push({ test: (u) => u === W + '/a2a', reply: async (u, i) => { atW.push(JSON.parse(i.body)); return new Response(JSON.stringify(ack), { headers: { 'content-type': 'application/json' } }); } });
// A world-tier card, as rememberStranger() leaves one after a relay result or a gossip hit: never
// added by hand, key vouched by the directory, tier world.
const stableId = async (...p) => [...new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(p.join('|'))))].map((b) => b.toString(16).padStart(2, '0')).join('').slice(0, 32);
const id = await stableId('known', 'stranger@world-f6.example');
portals[B].MAILBOX.m.set('known:' + id, JSON.stringify({ id, url: W + '/card', handle: 'stranger@world-f6.example', rpc: W + '/a2a', description: 'CFO for hire.', need: [], have: ['fractional-cfo'], glosses: {}, publicKey: 'AAAA', tier: 'world', via: 'world', addedAt: new Date().toISOString(), fetchedAt: new Date().toISOString() }));
const held = await J(B, 'list_known_cards');
ok('precondition: the stranger is held at world tier', held.some((c) => c.handle === 'stranger@world-f6.example' && c.tier === 'world'));

await call(B, 'update_card', { add_need: 'fractional-cfo', need_visibility: 'matched-only' });
const f = await J(B, 'find', { need_text: 'a replacement CFO for Northwind before the board hears about it', tags: ['fractional-cfo'] });
const opens = atW.filter((m) => m.params && m.params.message.metadata.action && m.params.message.metadata.action.type === 'thread.open');
const fps = opens.map((m) => ((m.params.message.metadata.action.note.parts || []).find((p) => p.data) || {}).data).filter((d) => d && d.need && d.need.fp);
ok('a matched-only need\'s fingerprint goes only to cards held at tribe or inner (§3.6)', !fps.length, `${fps.length} thread.open(s) carrying buckets reached ${W}/a2a; tier ${fps[0] && fps[0].need.tier}, buckets ${JSON.stringify(fps[0] && fps[0].need.fp)}, tags ${JSON.stringify(fps[0] && fps[0].need.tags)}`);
ok('(the words themselves did not travel)', !atW.some((m) => /Northwind/.test(JSON.stringify(m))));
ok('(the stranger is offered as a candidate for the held need)', true, JSON.stringify((f.candidates || []).map((c) => `${c.handle} (${c.tier})`)));

// For contrast: the pulse's blind cast, which implements the §3.6 rule, sends nothing to world tier.
atW.length = 0; wire.length = 0;
await pulse(B);
ok('the pulse\'s blind cast keeps to tribe and inner', !atW.some((m) => m.params && m.params.message.metadata.action && m.params.message.metadata.action.type === 'find.blind'), `${atW.length} message(s) at the stranger's door on the pulse`);
done();
