// thread_delete removes convm:, outbox: and conv: for the copy, but leaves outcome:, tlink:,
// pulse: (the push-config the counterpart registered), blocked: and trust: behind. The spec says
// "Deleting yours leaves the other person's copy" and treats delete as removing your copy; these
// remnants keep the fact of the connection, a live reply link, and the outcome record after delete.
import { addPortal, call, J, ok, done, openThread, keys, portals } from './_harness.mjs';
const A = 'https://mazel.a.sec', B = 'https://mazel.b.sec';
addPortal(A, 'avery@mazel'); addPortal(B, 'sam@mazel');
const { ctx, introId } = await openThread(A, B, 'fractional-cfo', 'sam@mazel');
await call(A, 'thread_send', { context_id: ctx, text: 'hi', confirmed: true });
// A saves a contact with no portal and makes a reply-by-link for this thread.
const gid = (await call(A, 'note_ghost', { name: 'Dana Ruiz', org: 'northline', have: ['revenue-cycle'], edge_score: 70, witnesses: ['crm'] })).match(/id is (\w+)/)[1];
await call(A, 'thread_share', { context_id: ctx, contact_id: gid });
ok('before delete: outcome, tlink and the counterpart pulse-config all exist', keys(A, 'outcome:' + introId).length === 1 && keys(A, 'tlink:').length === 1 && keys(B, 'pulse:' + ctx + ':').length >= 1);
await call(A, 'thread_delete', { context_id: ctx, confirmed: true });
ok('the conversation and its messages are gone', !keys(A, 'conv:' + ctx).length && !keys(A, 'convm:' + ctx).length);
ok('FAIL: the outcome object for this connection is left behind', keys(A, 'outcome:' + introId).length === 0, keys(A, 'outcome:' + introId).join(','));
const tl = keys(A, 'tlink:');
ok('FAIL: a live reply-by-link for the deleted thread is left behind', tl.length === 0, `${tl.length} tlink record(s), contextId ${tl.length ? JSON.parse(portals[A].MAILBOX.m.get(tl[0])).contextId : '-'}`);
done();
