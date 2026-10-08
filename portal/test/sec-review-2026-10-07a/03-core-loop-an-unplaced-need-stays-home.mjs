// Item 2: until the owner answers public or private, no words about the need leave the portal by
// any path. find, the pulse, a reopen, the owner's own propose_intro on a candidate found locally;
// then a private answer, which must send a fingerprint and nothing else.
import { addPortal, call, J, ok, done, portals, wire, keys, hold, pulse } from './_h.mjs';
const A = 'https://avery-07a3.test', B = 'https://lea-07a3.test';
addPortal(A, 'avery@mazel'); addPortal(B, 'lea@mazel');
await call(A, 'update_card', { add_have: 'heat-exchangers', witnesses: ['hubspot'], confirmed: true });
await hold(B, A); await hold(A, B);
const WORDS = /heat exchangers|heat-exchangers|chillers/i;
const out = (since) => wire.slice(since).filter((w) => !w.url.startsWith(B) && w.method === 'POST' && w.body.includes('lea@mazel'));
const leaked = (since) => out(since).filter((w) => WORDS.test(w.body));

let mark = wire.length;
const f = await J(B, 'find', { need_text: 'someone who knows heat exchangers and chillers', tags: ['heat-exchangers'] });
ok('the first find asks where the need lives', f.where_it_lives && f.where_it_lives.ask_the_person_exactly, JSON.stringify(f.where_it_lives).slice(0, 80));
ok('and still shows the local candidate', (f.candidates || []).some((c) => c.handle === 'avery@mazel'));
ok('find: nothing with the need\'s words left the portal', leaked(mark).length === 0, leaked(mark).map((w) => w.url).join(' '));
mark = wire.length; await pulse(B); await pulse(B);
ok('pulse, twice: nothing with the need\'s words left', leaked(mark).length === 0, leaked(mark).map((w) => w.url).join(' '));
mark = wire.length; await call(B, 'thread_manage', { action: 'close_need', thread_id: f.thread_id }); await call(B, 'thread_manage', { action: 'reopen_need', thread_id: f.thread_id }); await pulse(B);
ok('close, reopen, pulse: nothing left', leaked(mark).length === 0);
mark = wire.length; await J(B, 'find', { need_text: 'someone who knows heat exchangers and chillers', tags: ['heat-exchangers'] });
ok('a second find before the answer: nothing left, and the question is asked again', leaked(mark).length === 0);
const anyTool = await call(B, 'check_mailbox');
ok('the question rides on an unrelated tool result until answered', /Still to settle|still_to_settle/.test(anyTool), anyTool.slice(0, 60));
// The owner's own yes to an intro, before answering where the need lives.
mark = wire.length;
const cand = (f.candidates || []).find((c) => c.handle === 'avery@mazel');
let proposed = '';
try { proposed = await call(B, 'propose_intro', { thread_id: f.thread_id, card_url: cand.card_url, ask: { kind: 'call', size: '20 minutes' }, confirmed: true }); } catch (e) { proposed = 'refused: ' + e.message; }
ok('LOW: propose_intro on an unplaced need sends the words before the owner has said where it lives', leaked(mark).length === 0, `${leaked(mark).length} messages carried the words (${proposed.slice(0, 60)})`);

// ---- a private answer: buckets only ------------------------------------------------------------
mark = wire.length;
await call(B, 'update_card', { add_need: 'heat-exchangers', need_visibility: 'matched-only', confirmed: true });
const sent = out(mark);
ok('the private answer releases something at once', sent.length > 0, sent.map((w) => w.url).join(' '));
ok('and none of it carries the words or the tag', leaked(mark).length === 0, leaked(mark).map((w) => w.body.slice(0, 100)).join(' | '));
ok('what travels is a fingerprint', sent.some((w) => /"fp":\[/.test(w.body)) && !sent.some((w) => /"needText"/.test(w.body)));
mark = wire.length; await pulse(B); await J(B, 'find', { need_text: 'someone who knows heat exchangers and chillers', tags: ['heat-exchangers'] });
// releaseSettled opens no branch for a private need ("a branch would carry the sentence"); the very next
// find opens one anyway (findInKnownCards, `if (settled) ... openBranch`), with the buckets beside a tag.
ok('LOW: later pulses and finds send only buckets too', leaked(mark).length === 0, leaked(mark).map((w) => { const m = JSON.parse(w.body).params.message; const n = (m.metadata.action.note || {}).parts || []; return `${m.metadata.action.type} to ${w.url}: ${JSON.stringify((n[1] || {}).data || {}).slice(0, 160)}`; }).join(' | '));

// ---- a need said in words the scorer throws away ----------------------------------------------
// suggestTag() builds the question's tag from the need's non-stopwords; with none, no question is
// recorded and the pulse treats the need as placed.
const C = 'https://cam-07a3.test'; addPortal(C, 'cam@mazel'); await hold(C, A);
mark = wire.length;
let f3 = null; try { f3 = await J(C, 'find', { need_text: 'someone who can help me with it all', tags: [] }); } catch (e) { f3 = { error: e.message }; }
await pulse(C);
const camOut = wire.slice(mark).filter((w) => !w.url.startsWith(C) && w.method === 'POST' && /help me with it all/.test(w.body));
ok('a need made only of stopwords is refused by find before it can be stored unasked', camOut.length === 0 && !!f3.error, f3.error ? `find refused: ${f3.error.slice(0, 60)}` : `${camOut.length} messages carried it; where_it_lives=${JSON.stringify(f3.where_it_lives).slice(0, 60)}`);
done();
