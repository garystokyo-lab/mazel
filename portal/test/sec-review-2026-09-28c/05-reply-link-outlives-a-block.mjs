// M3 (§4.3b "block (the other portal's messages are refused)"; thread_block: "refuses everything
// further ... silently"; thread_manage: "one step for someone being harassed").
//
// A saved contact with no portal is in a thread by reply link. thread_block on that thread sets
// conv.blocked and records nothing else (the contact has no handle and no key). handleReplyLink()
// checks the MAC, the expiry, and state === closed || lapsed - never conv.blocked. So the link
// keeps working after the block: each POST is stored as the contact's words, moves the thread to
// sent/replied, puts "💬 A reply from <name>" in the box and rings the doorbell, which for a reply
// is never capped. The one control the owner was given against a person who will not stop does
// nothing for the one kind of person who can only reach them this way.
import { worker, addPortal, call, J, ok, done, portals } from '../sec-review-2026-09-28/_harness.mjs';

const A = 'https://alice5c.test';
addPortal(A, 'alice@mazel');

await call(A, 'note_ghost', { name: 'Dana Fox', org: 'foxcap.example', have: ['fractional-cfo'], role: 'CFO bench', witnesses: ['hubspot'], edge_score: 70, edge_signals: '3 deals' });
const f = await J(A, 'find', { need_text: 'a fractional cfo for Northwind', tags: ['fractional-cfo'] });
const branch = JSON.parse(await call(A, 'thread_list')).threads.find(t => t.with.includes('Dana Fox'));
ok('a contact branch is open', !!branch);
const ctx = branch.context_id;

const share = await call(A, 'thread_share', { context_id: ctx });
const link = (share.match(/https:\/\/\S+\/t\/[a-f0-9]{32}\?s=[A-Za-z0-9_-]+/) || [])[0];
ok('a reply link was made', !!link, share.slice(0, 100));
const [path, s] = [link.split('?')[0], link.split('s=')[1]];
const post = (text) => worker.fetch(new Request(path, { method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ s, text }).toString() }), portals[A]);
const msgs = () => [...portals[A].MAILBOX.m.keys()].filter(k => k.startsWith(`convm:${ctx}:`)).length;
const replies = () => [...portals[A].MAILBOX.m.values()].map(v => { try { return JSON.parse(v); } catch { return {}; } }).filter(m => m.box && m.box.kind === 'reply' && m.box.contextId === ctx).length;

const r0 = await post('Happy to help - call me Tuesday.');
ok('before the block, a reply by link lands', r0.status === 302 && msgs() === 2, `HTTP ${r0.status}, messages ${msgs()}`);

await call(A, 'thread_block', { context_id: ctx, confirmed: true });
ok('the thread is blocked', JSON.parse(portals[A].MAILBOX.m.get('conv:' + ctx)).blocked === true);
portals[A].MAILBOX.m.delete('bell:' + ctx);   // past the ten-minute quiet window, as it would be

const mBefore = msgs(), bBefore = replies();
const r1 = await post('Why are you ignoring me. Answer.');
const r2 = await post('I know where your office is.');
ok('after the block, the link must refuse', r1.status !== 302 && r2.status !== 302, `HTTP ${r1.status}, ${r2.status}`);
ok('nothing is stored in the thread', msgs() === mBefore, `${mBefore} -> ${msgs()}`);
ok('nothing lands in the box and the bell does not ring', replies() === bBefore && !portals[A].MAILBOX.m.has('bell:' + ctx), `reply items ${bBefore} -> ${replies()}, bell: ${portals[A].MAILBOX.m.has('bell:' + ctx)}`);
const c = JSON.parse(portals[A].MAILBOX.m.get('conv:' + ctx));
ok('the page for the blocked link says nothing about why', r1.status === 410 || r1.status === 403 || r1.status === 404, `HTTP ${r1.status}`);

if (r1.status === 302) {
  console.log(`FAIL block ignored by reply link: after thread_block, two POSTs to ${path} were stored as Dana Fox's words (thread now ${msgs()} messages, state ${c.state}), boxed as replies and rang the doorbell.`);
}
done();
