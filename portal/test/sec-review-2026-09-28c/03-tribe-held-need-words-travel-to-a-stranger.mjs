// M1 (§3.2 tiers; the H1 fix of 2026-09-28b, incompletely applied).
//
// A need in the memory file can be held at tribe or inner ("[tribe] board-cfo"): needAt() keeps it
// off every card projection below that tier, and openBranch() refuses to open a branch for it at
// all ("held that close never travels as a branch"). proposeIntro() and invite_text know only two
// held tiers. proposeIntro() holds the words back when the tier is exactly "matched-only" and
// refuses when it is "directed" to somebody else; for "tribe" and "inner" it sends needText, the
// tags and a why that quotes the need - to whichever candidate find produced, including a
// world-tier stranger. invite_text refuses matched-only and mis-directed needs and spells a
// tribe-held one out to a saved contact who is in no tribe. The previous report's fix said to key
// the hold on `needTier !== "public"`; the commit kept `=== "matched-only"`.
import { addPortal, call, J, ok, done, portals, wire } from '../sec-review-2026-09-28/_harness.mjs';
import { memoryDoc } from '../a2a-helpers.mjs';

const A = 'https://alice3c.test', W = 'https://wally3c.test';
addPortal(A, 'alice@mazel');
addPortal(W, 'wally3c@mazel');

const SECRET = 'a CFO for Northwind before the board meets on the 14th';
portals[A].MAILBOX.m.set('memory:card.md', memoryDoc({ handle: 'alice@mazel', persona: 'Alice runs Northwind.', have: ['ops'],
  need: [{ tag: 'board-cfo', tier: 'tribe', gloss: 'held for the tribe only' }] }));

await call(W, 'update_card', { add_have: 'fractional-cfo', confirmed: true });
await call(A, 'add_known_card', { url: W + '/card', tier: 'world' });     // a stranger who drifted in from the world

wire.length = 0;
const f = await J(A, 'find', { need_text: SECRET, tags: ['board-cfo', 'fractional-cfo'] });
const cand = (f.candidates || []).find(c => c.handle === 'wally3c@mazel');
ok('the stranger is a candidate on the tribe-held need', !!cand, JSON.stringify((f.candidates || []).map(c => c.handle)));
const branches = JSON.parse((await call(A, 'thread_list')).startsWith('No') ? '{"threads":[]}' : await call(A, 'thread_list')).threads.filter(t => t.with.includes('wally3c@mazel'));
ok('openBranch already refuses a branch for a tribe-held need', branches.length === 0, String(branches.length));
ok('and nothing has reached the stranger so far', !wire.some(w => w.url === W + '/a2a' && w.body.includes('Northwind')));

// The agent proposes, with the person's yes. The tier check is the portal's job, not the agent's.
let out = '';
try { out = await call(A, 'propose_intro', { thread_id: f.thread_id, card_url: cand.card_url, ask: { kind: 'call', size: '20 minutes' }, confirmed: true }); }
catch (e) { out = 'refused: ' + e.message; }
const toW = wire.filter(w => w.url === W + '/a2a');
const leaked = toW.filter(w => w.body.includes('Northwind'));
ok('a tribe-held need\'s words must not travel to a world-tier stranger', leaked.length === 0,
   leaked.length ? `intro.propose to ${W}: ${(JSON.parse(leaked[0].body).params.message.metadata.action || {}).needText}` : out.slice(0, 100));
const wIntro = [...portals[W].MAILBOX.m.entries()].filter(([k]) => k.startsWith('intro:')).map(([, v]) => JSON.parse(v))[0];
ok('the stranger\'s portal holds no copy of the words', !JSON.stringify(wIntro || {}).includes('Northwind'), wIntro ? `why: ${wIntro.why}` : '');

// And the same tier, through invite_text, to a saved contact who is in no tribe.
await call(A, 'note_ghost', { name: 'Dana Fox', org: 'foxcap.example', have: ['fractional-cfo'], role: 'CFO bench', witnesses: ['hubspot'], edge_score: 70, edge_signals: '3 deals' });
const f2 = await J(A, 'find', { need_text: SECRET, tags: ['board-cfo', 'fractional-cfo'] });
let draft = '';
try { draft = await call(A, 'invite_text', { ghost_id: f2.invites[0].ghost_id, thread_id: f2.thread_id }); } catch (e) { draft = 'refused: ' + e.message; }
ok('a tribe-held need must not be spelled out for a contact outside the tribe', !draft.includes('Northwind'), draft.split('\n').find(l => l.includes('Northwind')) || draft.slice(0, 80));

if (leaked.length || draft.includes('Northwind')) {
  console.log(`FAIL tribe-held need leaked: proposeIntro holds words back only for matched-only, so "${SECRET}" ${leaked.length ? `went to ${W} in an intro.propose` : ''}${draft.includes('Northwind') ? ' and was drafted for a contact in no tribe' : ''}.`);
}
done();
