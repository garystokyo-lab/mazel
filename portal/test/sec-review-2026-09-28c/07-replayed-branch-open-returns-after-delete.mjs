// L1 (regression note on 2026-09-28b H2). The fix binds thread.open to its named recipient and
// sender, so a captured open no longer replays at other portals. At the named portal the only
// replay guard is `if (await loadConv(env, action.contextId)) return;` - the conversation itself.
// thread_delete removes it. So for the 48-hour freshness window, the branch the owner deleted
// comes back on a replay of the same bytes - with a fresh 📬 "Someone needs what you have" in the
// box and another doorbell ring - from anyone who kept a copy, including the opener's own portal
// on a retry. The previous report suggested a per-(key, contextId) replay store; it was not added.
import { worker, addPortal, call, J, ok, done, portals, wire } from '../sec-review-2026-09-28/_harness.mjs';

const A = 'https://alice7c.test', B = 'https://bob7c.test';
addPortal(A, 'alice@mazel');
addPortal(B, 'bob7c@mazel');
await call(B, 'update_card', { add_have: 'fractional-cfo', confirmed: true });
await call(A, 'add_known_card', { url: B + '/card' });
await call(B, 'add_known_card', { url: A + '/card' });

wire.length = 0;
await J(A, 'find', { need_text: 'a fractional cfo for Northwind', tags: ['fractional-cfo'] });
const open = wire.find(w => w.url === B + '/a2a' && w.body.includes('thread.open'));
ok('alice\'s branch-open reached bob', !!open);
const ctx = JSON.parse(open.body).params.message.metadata.action.contextId;
ok('bob holds the branch', !!portals[B].MAILBOX.m.get('conv:' + ctx));

await call(B, 'thread_delete', { context_id: ctx, confirmed: true });
ok('bob deleted his copy', !portals[B].MAILBOX.m.get('conv:' + ctx));
const boxBefore = [...portals[B].MAILBOX.m.values()].map(v => { try { return JSON.parse(v); } catch { return {}; } }).filter(m => m.box).length;
portals[B].MAILBOX.m.delete('bell:' + ctx);

// The same signed open again, minutes later, as a new message to the door (the door's seen:<messageId>
// marker only catches a byte-identical retry; the signature covers the action, not the envelope).
const again = JSON.parse(open.body); again.id = 'replay-' + Date.now(); again.params.message.messageId = 'replay-' + Date.now();
await worker.fetch(new Request(B + '/a2a', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(again) }), portals[B]);
const back = portals[B].MAILBOX.m.get('conv:' + ctx);
const boxAfter = [...portals[B].MAILBOX.m.values()].map(v => { try { return JSON.parse(v); } catch { return {}; } }).filter(m => m.box).length;
ok('a branch the owner deleted must not come back on a replay', !back);
ok('and the box must not get a second 📬 for it', boxAfter === boxBefore, `${boxBefore} -> ${boxAfter}`);

if (back) console.log(`FAIL replay after delete: bob deleted branch ${ctx.slice(0, 8)}…, the captured thread.open was posted again and the branch is back with a new box item.`);
done();
