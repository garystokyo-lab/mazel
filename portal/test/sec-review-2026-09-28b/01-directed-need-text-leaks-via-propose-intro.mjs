// H1. A directed need is "for one named person: it opens a branch with them and with nobody else"
// (applyCardChange) and §3.6/§4.3b say a held need's words never leave the owner's portal before
// both humans say yes. openBranch() honours that. proposeIntro() does not: it computes
// needTier = needTierOf(card, thread) and then sets heldBack = needTier === "matched-only", so a
// DIRECTED need is treated as public and its full text is put on the wire, in an intro.propose,
// to ANY candidate the agent names - including a portal the need was never for.
import { addPortal, call, J, ok, done, portals } from '../sec-review-2026-09-28/_harness.mjs';

const A = 'https://alice.test', B = 'https://cal.test', M = 'https://mallory.test';
addPortal(A, 'alice@mazel');
addPortal(B, 'cal@mazel');
addPortal(M, 'mallory@mazel');

const SECRET = 'a replacement CFO for Northwind before the board hears about it';

await call(B, 'update_card', { add_have: 'fractional-cfo', confirmed: true });
await call(M, 'update_card', { add_have: 'fractional-cfo', confirmed: true });
await call(A, 'add_known_card', { url: B + '/card' });
await call(A, 'add_known_card', { url: M + '/card' });

// The need is DIRECTED: it is for cal@mazel and nobody else.
await call(A, 'update_card', { add_need: 'directed-cfo', need_visibility: 'directed', need_to: 'cal@mazel' });
const f = await J(A, 'find', { need_text: SECRET, tags: ['directed-cfo', 'fractional-cfo'] });

// The branch guard works: only cal gets a branch.
const withs = JSON.parse(await call(A, 'thread_list')).threads.map(t => t.with.join(','));
ok('branches: a directed need opens a branch only with its named recipient', !withs.some(w => w.includes('mallory')), JSON.stringify(withs));

// Now the agent proposes the intro to the WRONG candidate. Nothing refuses it.
const cand = f.candidates.find(c => c.handle === 'mallory@mazel');
ok('mallory is offered as a candidate for a need that is not for her', !!cand, JSON.stringify(f.candidates.map(c => c.handle)));
const said = await call(A, 'propose_intro', { thread_id: f.thread_id, card_url: cand.card_url, ask: { kind: 'call', size: '20 minutes' }, confirmed: true });

// What landed on Mallory's portal.
const intros = [...portals[M].MAILBOX.m.entries()].filter(([k]) => k.startsWith('intro:')).map(([, v]) => JSON.parse(v));
const leaked = intros.find(i => String(i.needText || '').includes('Northwind'));
const inMail = [...portals[M].MAILBOX.m.values()].some(v => String(v).includes('Northwind'));

ok('a directed need\'s words must not reach a portal it does not name', !leaked && !inMail,
   leaked ? `intro ${leaked.id}.needText = "${leaked.needText}"` : 'only in the mailbox record');
if (leaked || inMail) {
  console.log(`FAIL directed-need text escaped: proposeIntro sent needText="${(leaked || {}).needText || SECRET}" to mallory@mazel, who is not the need's named recipient (cal@mazel).`);
  console.log(`     propose_intro said: ${said.slice(0, 120)}`);
}
done();
