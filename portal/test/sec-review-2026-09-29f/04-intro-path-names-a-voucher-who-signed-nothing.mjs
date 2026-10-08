// MEDIUM. applyInboundAction() stores action.path as sent (index.js ~3056); list_intros returns it
// raw (~3284); handleIntroLink renders it as "Path: a → b" on the yes page (~5480); check_mailbox
// narrows it to handle-shaped strings but shows them unfenced (~1904); respondIntro() signs it
// onward with the answerer appended (~3157). §4.3 says a router's name "travels with the intro" as
// the record of THEIR yes to route. On the wire, path is a list of handles the proposer typed:
// nothing any hop signed. So a proposal can claim a real person vouched for it, and the person
// deciding sees "Path: sarah@mazel → mallory@mazel" on the page with the yes button. 29e H1 dropped
// the `router` object for exactly this reason; `path` is the same claim in a different field.
import { addPortal, call, J, ok, done, portals, worker, relayReplies, signingOf, signWith, a2a, noteMsg, keys, mail } from '../sec-review-2026-09-28/_harness.mjs';

const M = 'https://mallory-f4.test', B = 'https://bob-f4.test', S = 'https://sarah-f4.test';
addPortal(M, 'mallory@mazel'); addPortal(B, 'bob@mazel'); addPortal(S, 'sarah@mazel');
for (const [o, n] of [[M, 'mallory'], [B, 'bob'], [S, 'sarah']]) relayReplies.directory[n] = await (await worker.fetch(new Request(`${o}/.well-known/mazel/${n}.json`), portals[o])).json();
await call(B, 'add_known_card', { url: M + '/card' });   // mallory is a card bob holds; sarah is someone bob trusts and mallory knows it

const ms = await signingOf(M);
const introId = 'f4' + 'd'.repeat(30);
const prop = await signWith(ms, { v: 1, type: 'intro.propose', handle: 'mallory@mazel', publicKey: ms.pub, cardUrl: M + '/.well-known/agent-card.json', rpc: M + '/a2a', castAt: new Date().toISOString(),
  introId, why: 'Sarah suggested we talk about the Northwind CFO seat.', needText: 'a fractional cfo', needTags: ['fractional-cfo'], matchedTags: ['fractional-cfo'],
  path: ['sarah@mazel', 'mallory@mazel'], proposer: { handle: 'mallory@mazel', cardUrl: M + '/.well-known/agent-card.json', rpc: M + '/a2a' }, ask: { kind: 'call', size: '20 minutes' }, contextId: 'f4' + 'e'.repeat(30) });
await a2a(B, noteMsg('Intro proposal from mallory@mazel. Path: sarah@mazel -> mallory@mazel.', { handle: 'mallory@mazel', cardUrl: M + '/.well-known/agent-card.json', action: prop }));
const intro = JSON.parse(portals[B].MAILBOX.m.get('intro:' + introId) || 'null');
ok('precondition: the proposal is stored (mallory signed it, and bob holds her)', !!intro && intro.state === 'proposed');
ok('sarah\'s portal signed nothing and holds nothing', keys(S, 'intro:').length === 0 && keys(S, 'conv:').length === 0);

ok('a hop on an intro\'s path is someone who signed something', !(intro && (intro.path || []).includes('sarah@mazel')), intro ? `path on file: ${intro.path.join(' → ')}` : '');
const row = (await J(B, 'list_intros')).find((i) => i.intro_id === introId);
ok('list_intros names as a voucher only someone who signed', !(row && (row.path || []).includes('sarah@mazel')), row ? `path: ${JSON.stringify(row.path)}, why: ${row.why}` : '');
const link = await call(B, 'respond_intro_link', { intro_id: introId, decision: 'accepted' });
const url = (link.match(/https:\/\/\S+/) || [''])[0];
const page = await (await worker.fetch(new Request(url), portals[B])).text();
ok('the page with the yes button names as a voucher only someone who signed', !/sarah@mazel/.test(page), (page.match(/Path<\/dt><dd>[^<]*/) || ['no Path line'])[0]);
const m = (await mail(B)).find((x) => x.action && x.action.introId === introId);
ok('check_mailbox shows a path of people who signed', !(m && (m.action.path || []).includes('sarah@mazel')), m ? `action.path: ${JSON.stringify(m.action.path)}` : '');
done();
