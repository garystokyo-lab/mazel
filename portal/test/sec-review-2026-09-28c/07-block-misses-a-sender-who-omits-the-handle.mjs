// 28b M1 made thread_block write blocked:h:<handle> even with no pinned key, and the door reads it.
// The door reads it from metadata.handle - the sender's own self-description - and intro.propose
// is not signed (proposeIntro sends a bare action; applyInboundAction verifies nothing on it), so
// there is no key to block by. A blocked portal that leaves metadata.handle out (fromHandle then
// falls back to message.role, "ROLE_USER") passes every block check at the door, and its proposal
// lands in the mailbox and in list_intros with proposer.handle = the blocked handle, `verified: true`
// even, because the held card for that handle supplies `from`. Same for a plain note.
import { addPortal, call, ok, done, portals, a2a, noteMsg, openThread, mail } from '../sec-review-2026-09-28/_harness.mjs';

const B = 'https://bob.c7', S = 'https://spam.c7';
addPortal(B, 'bob@mazel'); addPortal(S, 'spam@mazel');
const { ctx } = await openThread(S, B, 'blocking-tag', 'bob@mazel');
await call(B, 'thread_manage', { action: 'block', context_id: ctx, confirmed: true }).catch(() => call(B, 'thread_block', { context_id: ctx, confirmed: true }));
ok('bob blocked spam@mazel portal-wide', [...portals[B].MAILBOX.m.keys()].some((k) => k === 'blocked:h:spam@mazel'));

const withHandle = await (await a2a(B, noteMsg('hello with my name on it', { handle: 'spam@mazel', cardUrl: S + '/card' }))).json();
ok('a note that names the blocked handle is refused', !!withHandle.error);

const before = (await mail(B)).length;
const propose = { type: 'intro.propose', v: 1, introId: 'c7-intro-1', proposer: { handle: 'spam@mazel', cardUrl: S + '/card', rpc: S + '/a2a' }, why: 'Buy my course.', needText: 'a mark', needTags: [], matchedTags: ['blocking-tag'], path: ['spam@mazel'], ask: { kind: 'call', size: '' } };
const anon = await (await a2a(B, noteMsg('Intro proposal from spam@mazel: buy my course.', { cardUrl: S + '/card', action: propose }))).json();
ok('a proposal from a blocked portal that omits metadata.handle must be refused too', !!anon.error, 'door answered ok');
const stored = JSON.parse(portals[B].MAILBOX.m.get('intro:c7-intro-1') || 'null');
ok('no intro from a blocked portal may be stored', !stored, stored ? `stored, from ${stored.from.handle}, verified=${stored.verified}` : '');
const after = (await mail(B)).length;
ok('nothing from a blocked portal may land in the mailbox', after === before, `mailbox ${before} -> ${after}`);
const note = await (await a2a(B, noteMsg('a plain note with no name', { cardUrl: S + '/card' }))).json();
ok('nor a note that only carries the card url', !!note.error, 'door answered ok');
if (!anon.error) console.log('FAIL block bypass: the door blocks by metadata.handle, which the sender writes; with it omitted (fromHandle = "ROLE_USER") a blocked portal\'s unsigned intro.propose was stored at bob\'s portal as proposer spam@mazel' + (stored ? `, verified=${stored.verified}` : '') + '.');
done();
