// The /a2a door refuses a stranger's note at MAX_MAILBOX (400) and counts it per-IP AND per-sender.
// A thread message takes neither brake: handleSend's thread branch (index.js ~line 573) checks only
// the per-IP counter, and each human thread message writes a doorbell record into msg: with no
// MAX_MAILBOX check (ringDoorbell -> putObj). A counterpart grows the owner's mailbox past the
// ceiling that stops everyone else. Product tools only: B talks through its own thread_send.
import { addPortal, call, ok, done, openThread, keys, a2a, noteMsg, portals } from './_harness.mjs';
const A = 'https://mazel.a.sec', B = 'https://mazel.b.sec';
addPortal(A, 'avery@mazel'); addPortal(B, 'sam@mazel');
const { ctx } = await openThread(A, B, 'fractional-cfo', 'sam@mazel');

// A thread message moves no per-sender counter (only the per-IP one is checked for thread traffic).
const fromVal = () => { const k = keys(A, 'cap:a2a:from:sam'); return k.length ? Number(portals[A].MAILBOX.m.get(k[0])) : 0; };
const v0 = fromVal();
for (let i = 0; i < 10; i++) await call(B, 'thread_send', { context_id: ctx, text: 'flood ' + i, confirmed: true });
ok('FAIL: ten thread messages moved no per-sender counter', fromVal() > v0, `per-sender counter for sam: ${v0} -> ${fromVal()} across 10 thread messages`);

// Fill A's mailbox to the hard ceiling a stranger's note is refused at.
for (let i = 0; i < 400; i++) portals[A].MAILBOX.m.set(`msg:${1700000000000 + i}:filler-${i}`, JSON.stringify({ id: 'f' + i, text: 'filler', receivedAt: 'x' }));
const stranger = await a2a(A, noteMsg('hi', { handle: 'stranger@mazel' }));
ok('a stranger note is refused at MAX_MAILBOX', /mailbox is full/.test(await stranger.text()));

const heldBefore = keys(A, 'msg:').length;
const r = await call(B, 'thread_send', { context_id: ctx, text: 'ping past the ceiling', confirmed: true });
const heldAfter = keys(A, 'msg:').length;
ok('B\'s thread message was accepted at A\'s full mailbox', /delivered/.test(r));
ok('FAIL: it wrote another msg: doorbell record past the ceiling', heldAfter <= heldBefore, `msg: ${heldBefore} -> ${heldAfter}`);
done();
