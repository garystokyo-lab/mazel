// M2. §3.6: a matched-only need "travels only as a fingerprint ... Text appears only after both
// humans say yes." openBranch()/needParts() honour that for a saved contact: the ghost's branch
// carries buckets, not words. invite_text (callTool, name === "invite_text") does not: it reads
// `needText = t.need_text` off the root thread with no tier check at all, and hands the agent a
// ready-to-send paragraph naming the held-back ask, addressed to a person who has said nothing.
// The same call spells out a DIRECTED need to somebody it does not name.
import { addPortal, call, J, ok, done } from '../sec-review-2026-09-28/_harness.mjs';

const A = 'https://alice6.test';
addPortal(A, 'alice@mazel');

const SECRET = 'a replacement CFO for Northwind before the board hears about it';

await call(A, 'note_ghost', { name: 'Dana Fox', org: 'foxcap.example', email: 'dana@foxcap.example',
  have: ['fractional-cfo'], role: 'CFO bench', witnesses: ['hubspot'], edge_score: 70, edge_signals: '3 deals' });

// matched-only: held on the portal, never as text.
await call(A, 'update_card', { add_need: 'quiet-cfo-search', need_visibility: 'matched-only' });
const f = await J(A, 'find', { need_text: SECRET, tags: ['quiet-cfo-search', 'fractional-cfo'] });
ok('the saved contact is offered as an invitation', (f.invites || []).length > 0, JSON.stringify((f.invites || []).map(i => i.name)));

// The branch really does hold the words back.
const tl = JSON.parse(await call(A, 'thread_list')).threads;
const ghostBranch = tl.find(t => t.with.includes('Dana Fox'));
const branchText = ghostBranch ? await call(A, 'thread_read', { context_id: ghostBranch.context_id }) : '';
ok('the contact\'s branch carries buckets, not words', !branchText.includes('Northwind'), branchText.slice(0, 120));

const draft = await call(A, 'invite_text', { ghost_id: f.invites[0].ghost_id, thread_id: f.thread_id });
ok('a matched-only need\'s words must not be drafted for an outsider', !draft.includes('Northwind'),
   draft.split('\n').find(l => l.includes('Northwind')) || '');
if (draft.includes('Northwind')) {
  console.log(`FAIL invite_text spelled out a matched-only need: "${draft.split('\n').find(l => l.includes('Northwind')).trim()}"`);
}

// And the directed case, to a contact the need does not name.
await call(A, 'update_card', { add_need: 'directed-cfo', need_visibility: 'directed', need_to: 'cal@mazel' });
const g = await J(A, 'find', { need_text: SECRET + ' (for cal only)', tags: ['directed-cfo', 'fractional-cfo'] });
const d2 = (g.invites || []).length ? await call(A, 'invite_text', { ghost_id: g.invites[0].ghost_id, thread_id: g.thread_id }) : '';
ok('a directed need\'s words must not be drafted for someone it does not name', !d2.includes('Northwind'),
   d2.split('\n').find(l => l.includes('Northwind')) || 'no invite offered');
if (d2.includes('Northwind')) {
  console.log(`FAIL invite_text spelled out a directed need to a contact who is not cal@mazel: "${d2.split('\n').find(l => l.includes('Northwind')).trim()}"`);
}
done();
