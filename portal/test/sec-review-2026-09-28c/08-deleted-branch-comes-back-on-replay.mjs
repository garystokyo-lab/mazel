// 28b H2 bound thread.open to its named recipient. At that recipient the only replay guard is
// "loadConv(contextId) already exists" (onThreadOpen) plus the door's seen:<messageId> marker.
// thread_delete removes the conv, and a replay with a fresh messageId is a new message to the door.
// So for the two days a branch-open stays fresh, anyone holding a copy - the counterpart's portal
// by design, or a log - can put a branch the owner deleted back, with a new 📬 and a new ring.
import { addPortal, call, J, ok, done, portals, wire, a2a, mail } from '../sec-review-2026-09-28/_harness.mjs';

const A = 'https://alice.c8', B = 'https://bob.c8';
addPortal(A, 'alice@mazel'); addPortal(B, 'bob@mazel');
await call(B, 'update_card', { add_have: 'fractional-cfo', confirmed: true });
await call(A, 'add_known_card', { url: B + '/card' });
await call(B, 'add_known_card', { url: A + '/card' });
wire.length = 0;
await J(A, 'find', { need_text: 'a fractional cfo for a hospital group', tags: ['fractional-cfo'] });
const open = wire.find((w) => w.url === B + '/a2a' && /"thread\.open"/.test(w.body));
const ctx = JSON.parse(open.body).params.message.metadata.action.contextId;
ok('bob holds the branch', !!portals[B].MAILBOX.m.get('conv:' + ctx));
await call(B, 'thread_delete', { context_id: ctx, confirmed: true });
ok('bob deleted his copy', !portals[B].MAILBOX.m.get('conv:' + ctx));
const boxBefore = (await mail(B)).filter((m) => m.box && m.box.contextId === ctx).length;

const replay = JSON.parse(open.body).params.message;
replay.messageId = 'replay-' + Math.random().toString(16).slice(2);
await a2a(B, replay);
const back = !!portals[B].MAILBOX.m.get('conv:' + ctx);
const boxAfter = (await mail(B)).filter((m) => m.box && m.box.contextId === ctx).length;
ok('a branch the owner deleted must not come back on a replayed open', !back, back ? 'conv re-created' : '');
ok('and must not be boxed again', boxAfter === boxBefore, `📬 items for it: ${boxBefore} -> ${boxAfter}`);
if (back) console.log(`FAIL replay after delete: the same signed thread.open (fresh for 48h) with a new messageId re-created conv ${ctx.slice(0, 8)}… at bob's portal after thread_delete, and boxed it again.`);
done();
