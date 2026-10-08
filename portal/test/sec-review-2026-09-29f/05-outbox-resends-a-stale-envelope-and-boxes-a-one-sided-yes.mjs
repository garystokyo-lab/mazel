// MEDIUM. sweepOutbox() (index.js ~4043-4064) re-sends a queued signed action byte for byte, for up
// to seven days, and treats the door's ack as delivery: onQueuedIntroDelivered() (~3120) then flips
// the intro to connected, opens the thread, and writes "🌀 Your answer ... finally got through: you
// both said yes, and the thread is open" into the mailbox. But castAt is inside the signature and
// the receiving gate refuses anything older than CAST_FRESH_MS (two days) - silently, with a normal
// ack (verifyInbound returns null, applyInboundAction returns, handleSend acks). So from day three
// to day seven a queued yes "delivers" to a portal that drops it: the responder's portal shows a 🌀
// and a thread that exists on one portal only, and the proposer's intro stays proposed for ever.
// A 🌀 with no shared object behind it (lock 12), produced by two honest portals and a slow weekend.
import { addPortal, call, J, ok, done, portals, worker, relayReplies, signingOf, signWith, down, mail, pulse, lastIntro, keys } from '../sec-review-2026-09-28/_harness.mjs';

const A = 'https://alice-f5.test', B = 'https://bob-f5.test';
addPortal(A, 'alice@mazel'); addPortal(B, 'bob@mazel');
for (const [o, n] of [[A, 'alice'], [B, 'bob']]) relayReplies.directory[n] = await (await worker.fetch(new Request(`${o}/.well-known/mazel/${n}.json`), portals[o])).json();
await call(B, 'update_card', { add_have: 'fractional-cfo', confirmed: true });
await call(A, 'add_known_card', { url: B + '/card' });
await call(B, 'add_known_card', { url: A + '/card' });
const f = await J(A, 'find', { need_text: 'someone who does fractional-cfo', tags: ['fractional-cfo'] });
const cand = f.candidates.find((c) => c.handle === 'bob@mazel');
await call(A, 'propose_intro', { thread_id: f.thread_id, card_url: cand.card_url, ask: { kind: 'call', size: '20 minutes' }, confirmed: true });
const introId = lastIntro(A, 'bob@mazel');

// Alice's portal is unreachable when bob says yes, so the yes waits in bob's outbox.
down.add(A);
const said = await call(B, 'respond_intro', { intro_id: introId, decision: 'accepted', confirmed: true });
ok('precondition: bob\'s yes is queued while alice\'s portal is down', /queued/.test(said) && keys(B, 'outbox:').length === 1, said.slice(0, 80));

// Three days pass. The queued record is what bob's portal signed on the day: same bytes, castAt
// three days old (re-signed here with bob's own key so the signature over that castAt is genuine).
const okey = keys(B, 'outbox:')[0];
const o = JSON.parse(portals[B].MAILBOX.m.get(okey));
const { sig, kid, ...payload } = o.action;
const threeDaysAgo = new Date(Date.now() - 3 * 24 * 3600e3).toISOString();
o.action = await signWith(await signingOf(B), { ...payload, castAt: threeDaysAgo });
o.firstAt = threeDaysAgo; o.nextAt = new Date(Date.now() - 1000).toISOString(); o.attempts = 4;
portals[B].MAILBOX.m.set(okey, JSON.stringify(o));
down.delete(A);

await pulse(B);
const introA = JSON.parse(portals[A].MAILBOX.m.get('intro:' + introId));
const introB = JSON.parse(portals[B].MAILBOX.m.get('intro:' + introId));
ok('the outbox knows the door dropped it', keys(B, 'outbox:').length === 1 || introA.state === 'connected', `outbox after the pulse: ${keys(B, 'outbox:').length} record(s); alice's intro: ${introA.state}`);
ok('a yes is connected on both portals or on neither', (introA.state === 'connected') === (introB.state === 'connected'), `alice: ${introA.state}; bob: ${introB.state}`);
const told = (await mail(B)).filter((m) => /finally got through/.test(m.text || '')).map((m) => m.text);
ok('no 🌀 is shown for a thread the other portal never opened', !told.some((t) => /🌀/.test(t)) || introA.state === 'connected', told.join(' | '));   // (patched after the fix: with a re-signed retry the other portal did open it)
const threadsB = keys(B, 'conv:').length, threadsA = keys(A, 'conv:').filter((k) => { const c = JSON.parse(portals[A].MAILBOX.m.get(k)); return c.humans; }).length;
ok('(threads with humans in them, per side)', true, `bob: ${threadsB}, alice: ${threadsA}`);
done();
