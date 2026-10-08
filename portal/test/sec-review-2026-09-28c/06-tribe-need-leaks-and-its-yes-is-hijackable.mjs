// Two things about a need held at tribe (or inner) tier - a tier the memory file accepts
// (FIELD_TIERS) and openBranch() knows ("held that close never travels as a branch").
//
// (a) proposeIntro() holds words back only for matched-only (`heldBack = needTier === "matched-only"`,
//     unchanged by 28b, which added a directed refusal beside it). A tribe need is proposed with its
//     full text to any candidate find lists - and find scores every known card, world tier included.
//
// (b) Because no branch opened, the intro carries no contextId, and both sides fall back to
//     stableId("ctx", intro.id) with intro.id = stableId("intro", proposerOrigin, threadId, cardUrl):
//     every input is public. 28b H4 made branch ids random; this id is not one. A third party whose
//     card the responder holds opens a need-branch at that exact contextId first; the responder's
//     yes to the real proposer then "joins the branch the agents opened" (openThreadFromIntro) -
//     the squatter's - and boxes 🌀 "Both said yes: you and <squatter>". The real proposer's first
//     message is refused at the door as "not a participant".
import { addPortal, call, J, ok, done, portals, wire, signingOf, signedAction, a2a, noteMsg, lastIntro, mail, conv } from '../sec-review-2026-09-28/_harness.mjs';

const A = 'https://alice.c6', B = 'https://bob.c6', M = 'https://mallory.c6';
addPortal(A, 'alice@mazel'); addPortal(B, 'bob@mazel'); addPortal(M, 'mallory@mazel');
await call(B, 'update_card', { add_have: 'fractional-cfo', confirmed: true });
await call(A, 'add_known_card', { url: B + '/card', tier: 'world' });   // bob is a stranger to alice: world tier
await call(B, 'add_known_card', { url: A + '/card' });
await call(B, 'add_known_card', { url: M + '/card' });                  // mallory is an ordinary contact of bob's

// Alice's memory file holds the need at tribe tier (the file is hers to edit; the tier is one the parser accepts).
const SECRET = 'a replacement CFO for Northwind before the board hears about it';
await call(A, 'my_card');
const md = portals[A].MAILBOX.m.get('memory:card.md');
portals[A].MAILBOX.m.set('memory:card.md', md.replace('## Need\n', '## Need\n- [tribe] fractional-cfo - ' + SECRET + '\n'));
const card = JSON.parse(await call(A, 'my_card'));
ok('the need sits at tribe tier on alice\'s card', JSON.stringify(card).includes('"tribe"'), JSON.stringify(card.need || card.held || card).slice(0, 120));

wire.length = 0;
const f = await J(A, 'find', { need_text: SECRET, tags: ['fractional-cfo'] });
ok('a tribe need opens no branch and casts nothing', !wire.some((w) => w.body.includes('Northwind')) && (f.candidates || []).every((c) => !c.context_id));
const cand = (f.candidates || []).find((c) => c.handle === 'bob@mazel');
ok('(bob, a world-tier card, is listed as a candidate for it)', !!cand);

// (a) propose: the words go out, to a world-tier card.
await call(A, 'propose_intro', { thread_id: f.thread_id, card_url: cand.card_url, ask: { kind: 'call', size: '20 minutes' }, confirmed: true });
const sent = wire.filter((w) => w.url === B + '/a2a' && w.body.includes('intro.propose'));
ok('a tribe-tier need\'s words must not be proposed to a world-tier card', !sent.some((w) => w.body.includes('Northwind')), sent.length ? 'needText on the wire: ' + (JSON.parse(sent[0].body).params.message.metadata.action.needText || '').slice(0, 60) : 'nothing sent');
const introId = lastIntro(A, 'bob@mazel');
const received = JSON.parse(portals[B].MAILBOX.m.get('intro:' + introId) || 'null');
ok('(the intro carries no contextId, so both sides will derive one)', received && !received.contextId);

// (b) mallory computes the id both sides will derive, and squats it at bob's portal.
const stableId = async (...parts) => [...new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(parts.join('|'))))].map((b) => b.toString(16).padStart(2, '0')).join('').slice(0, 32);
const predicted = await stableId('ctx', await stableId('intro', A, f.thread_id, B + '/card'));
const s = await signingOf(M);
const note = { messageId: 'm-squat', contextId: predicted, taskId: '', role: 'ROLE_USER',
  parts: [{ text: 'Looking for: someone who does fractional-cfo.' }, { data: { need: { needId: 'n1', tier: 'public', text: 'someone who does fractional-cfo', tags: ['fractional-cfo'] }, matched: ['fractional-cfo'], why: '' } }],
  metadata: { haah: { author: 'agent', from: 'mallory@mazel', at: new Date().toISOString(), envelope: null }, action: { type: 'thread.message', v: 1 } }, extensions: ['https://mazel.ai/ext/haah/v1'], referenceTaskIds: [] };
const open = await signedAction(s, { origin: M, handle: 'mallory@mazel' }, { type: 'thread.open', contextId: predicted, kind: 'need', firstWriter: 'mallory@mazel', origin: { needId: 'n1', tier: 'public' },
  participants: [{ handle: 'mallory@mazel', cardUrl: M + '/.well-known/agent-card.json', rpc: M + '/a2a', role: 'need' }, { handle: 'bob@mazel', cardUrl: B + '/card', rpc: B + '/a2a', role: 'have' }], note });
await a2a(B, noteMsg('a need', { handle: 'mallory@mazel', cardUrl: M + '/.well-known/agent-card.json', action: open }));
ok('(mallory\'s branch sits at the predicted id on bob\'s portal)', !!conv(B, predicted));

// Bob says yes to ALICE.
await call(B, 'respond_intro', { intro_id: introId, decision: 'accepted', confirmed: true });
const both = (await mail(B)).filter((m) => m.box && m.box.kind === 'both_yes');
const c = conv(B, predicted);
ok('bob\'s yes to alice must open a thread with alice', c && c.participants.some((p) => p.handle === 'alice@mazel'), `participants: ${JSON.stringify((c || { participants: [] }).participants.map((p) => p.handle))}, humans=${c && c.humans}`);
ok('no 🌀 may name someone who never said yes', !both.some((b) => /mallory/.test(b.text)), JSON.stringify(both.map((b) => b.text.slice(0, 80))));
const aliceCtx = JSON.parse(portals[A].MAILBOX.m.get('intro:' + introId)).contextId;
ok('(alice\'s copy landed on the same id)', aliceCtx === predicted);
const r = await call(A, 'thread_send', { context_id: aliceCtx, text: 'Hi Bob - two slots: Tue 10, Thu 2.', confirmed: true });
ok('alice\'s first message must reach bob', /delivered/.test(r), r.slice(0, 120));
if (c && !c.participants.some((p) => p.handle === 'alice@mazel')) console.log(`FAIL ctx hijack: stableId("ctx", intro.id) is computable from public inputs; mallory pre-opened a branch at ${predicted.slice(0, 8)}… on bob's portal, bob's yes to alice joined it, bob's box says 🌀 with mallory, and alice's first message was refused: ${r.slice(0, 80)}`);
done();
