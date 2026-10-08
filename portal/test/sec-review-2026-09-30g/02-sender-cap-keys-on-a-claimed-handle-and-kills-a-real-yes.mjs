// MEDIUM. handleSend() (index.js ~660-662): the per-sender daily cap is keyed on metadata.handle -
// the handle the message CLAIMS - and counted before the gate runs. A hundred unsigned notes from
// anyone, each claiming "alice@mazel", spend alice's allowance at bob's door for the day; alice's
// real, signed answer then meets a JSON-RPC error, and sweepOutbox() (~3979) treats any JSON-RPC
// error as a refusal since 29f M2: the queued yes is dropped and alice's owner is told "their portal
// refused it". Bob never learns an answer was sent. The same counter key (a2a:from:<handle>) is
// shared with the thread path (~587), so her thread messages to bob are refused for the day too.
import { addPortal, call, J, ok, done, portals, a2a, noteMsg, mail, pulse, lastIntro, keys } from '../sec-review-2026-09-28/_harness.mjs';

const A = 'https://alice-g2.test', B = 'https://bob-g2.test';
addPortal(A, 'alice@mazel'); addPortal(B, 'bob@mazel');
await call(A, 'update_card', { add_have: 'fractional-cfo', witnesses: ['hubspot'], confirmed: true });
await call(A, 'add_known_card', { url: B + '/card' });
await call(B, 'add_known_card', { url: A + '/card' });
const f = await J(B, 'find', { need_text: 'a fractional cfo', tags: ['fractional-cfo'] });
await call(B, 'propose_intro', { thread_id: f.thread_id, card_url: f.candidates[0].card_url, confirmed: true });
const introId = lastIntro(B, 'alice@mazel');
ok('precondition: alice holds bob\'s proposal', !!portals[A].MAILBOX.m.get('intro:' + introId));

// A stranger, one IP, a hundred unsigned notes at bob's door, each claiming to be alice.
let acked = 0;
for (let i = 0; i < 100; i++) { const r = await (await a2a(B, noteMsg('hello ' + i, { handle: 'alice@mazel' }), { 'CF-Connecting-IP': '203.0.113.9' })).json(); if (r.result) acked++; }
ok('(the hundred unsigned notes are taken as mail from nobody)', acked === 100, `${acked} acked`);

// Alice's real yes, signed by her own key, to bob's door.
const said = await call(A, 'respond_intro', { intro_id: introId, decision: 'accepted', confirmed: true });
ok('a signed answer from the real alice is not refused because strangers claimed her name', /both said yes/.test(said), said.slice(0, 160));
const atB = JSON.parse(portals[B].MAILBOX.m.get('intro:' + introId));
ok('bob\'s portal holds her yes', atB.state === 'connected', `bob: ${atB.state}`);
// The outbox waits a minute before its first retry; move the clock rather than wait.
for (const k of keys(A, 'outbox:')) { const o = JSON.parse(portals[A].MAILBOX.m.get(k)); o.nextAt = new Date(0).toISOString(); portals[A].MAILBOX.m.set(k, JSON.stringify(o)); }
await pulse(A);
const told = (await mail(A)).find((m) => m.mine && /could not be delivered/.test(m.text || ''));
ok('alice\'s owner is not told bob refused an answer bob never saw', !told, told ? told.text.slice(0, 200) : '');
const atA = JSON.parse(portals[A].MAILBOX.m.get('intro:' + introId));
ok('the yes is not dropped from the outbox', atA.queued === true || atA.state === 'connected', `alice's copy: state ${atA.state}, queued ${atA.queued}, lastError ${String(atA.lastError || '').slice(0, 80)}`);
done();
