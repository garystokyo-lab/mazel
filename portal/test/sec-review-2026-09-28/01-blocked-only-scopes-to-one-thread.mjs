// Blocking a thread is per-thread only. thread_block writes blocked:<pubkey> and trust:<pubkey>,
// but no inbound path ever reads blocked:. The blocked party's plain notes and new intro proposals
// still land in the owner's mailbox. Uses only the portal's own MCP tools.
import { addPortal, call, J, mail, ok, done, openThread, keys, portals } from './_harness.mjs';
const A = 'https://mazel.a.sec', B = 'https://mazel.b.sec';
addPortal(A, 'avery@mazel'); addPortal(B, 'sam@mazel');
const { ctx } = await openThread(A, B, 'fractional-cfo', 'sam@mazel');
await call(B, 'thread_send', { context_id: ctx, text: 'hello', confirmed: true });
await call(A, 'thread_block', { context_id: ctx, report: true, confirmed: true });
ok('A blocked B in this thread and filed a report', keys(A, 'blocked:').length === 1 && keys(A, 'trust:').length === 1);

const inThread = await call(B, 'thread_send', { context_id: ctx, text: 'still here?', confirmed: true });
ok('inside the blocked thread B is refused', /refused|queued/.test(inThread));

// Now B, blocked and reported, reaches A's public door outside the thread.
const before = (await mail(A)).length;
await call(B, 'send_to_peer', { rpc: A + '/a2a', text: 'blocked-but-still-here-9f3' });
const landed = (await mail(A)).some(m => /blocked-but-still-here-9f3/.test(m.text || ''));
ok('FAIL means the blocked portal reached the mailbox anyway', !landed, landed ? 'note from a blocked portal is in the mailbox' : 'note refused');

// And a brand-new intro proposal from the blocked portal.
await call(A, 'update_card', { add_have: 'halcyon', confirmed: true });
await call(B, 'add_known_card', { url: A + '/card' });   // refresh: pick up the new have
const f = await J(B, 'find', { need_text: 'someone at halcyon', tags: ['halcyon'] });
const c = f.candidates.find(x => x.handle === 'avery@mazel');
await call(B, 'propose_intro', { thread_id: f.thread_id, card_url: c.card_url, confirmed: true });
const live = keys(A, 'intro:').map(k => JSON.parse(portals[A].MAILBOX.m.get(k))).filter(i => i.direction === 'received' && i.from.handle === 'sam@mazel' && i.state === 'proposed');
ok('FAIL means the blocked portal can still open new intros', live.length === 0, `${live.length} live proposal(s) from the blocked portal`);
done();
