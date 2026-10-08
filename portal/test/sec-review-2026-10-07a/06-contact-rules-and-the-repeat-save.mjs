// Item 5: the four rules between a match and a question. Rest after a yes, back off on silence,
// never-ask, the matching bar; and whether any path bypasses them. saveGhost() (index.js ~4382)
// rebuilds a contact from what the reader sent and carries over the fields it names; asked, heard,
// lastAskedAt and neverAsk are not among them.
import { addPortal, call, J, ok, done, portals, wire, keys, asks, mail, hold, a2a, noteMsg, offerFrom, placeAndFind } from './_h.mjs';
const A = 'https://avery-07a6.test', B = 'https://lea-07a6.test';
addPortal(A, 'avery@mazel'); addPortal(B, 'lea@mazel');
await hold(A, B); await hold(B, A);
const omar = { name: 'Omar Haddad', org: 'coil.example', email: 'omar@coil.example', have: ['heat-exchangers'], role: 'Built heat exchangers for twenty years', witnesses: ['calendar', 'gmail'], small_meetings: 7, deals: 1, best_stage: 'won', threads_sent: 14, threads_replied: 11 };
await call(A, 'contacts', { action: 'note', ...omar });
const g = () => JSON.parse(await0());
const await0 = () => portals[A].MAILBOX.m.get(keys(A, 'ghost:')[0]);
let n = 0;
const offer = async (text = 'someone who knows heat exchangers', tags = ['heat-exchangers']) => a2a(A, noteMsg('A need of mine.', { handle: 'lea@mazel', cardUrl: B + '/.well-known/agent-card.json', action: await offerFrom(B, { needId: `need-${++n}`, needText: text, needTags: tags }) }));
const newAsk = async (text, tags) => { const before = new Set((await asks(A)).map((m) => m.action.askId)); await offer(text, tags); return (await asks(A)).filter((m) => !before.has(m.action.askId)); };

// ---- the matching bar ------------------------------------------------------------------------
await call(A, 'contacts', { action: 'note', name: 'Generic Partner', org: 'gp.example', have: ['clients', 'partners'], role: 'Works with clients and partners', witnesses: ['gmail'], small_meetings: 9 });
const common = await newAsk('intros to clients and partners', ['client-intros']);
ok('BAR: a need made of words every contact shares matches nobody', common.length === 0, common.map((m) => m.text.slice(0, 60)).join('|'));
const exact = await newAsk();
ok('BAR: an exact tag clears it', exact.length === 1 && /Omar/.test(exact[0].text));

// ---- rest after a yes -------------------------------------------------------------------------
const askId = exact[0].action.askId;
await call(A, 'contacts', { action: 'route', ask_id: askId, confirmed: true });
ok('REST: the yes is counted on the contact', JSON.parse(await0()).asked === 1 && !!JSON.parse(await0()).lastAskedAt);
const resting = await newAsk('another need about heat exchangers');
ok('REST: the next need for the same contact raises no question', resting.length === 0);
const restingRec = keys(A, 'ghostask:').map((k) => JSON.parse(portals[A].MAILBOX.m.get(k))).find((a) => a.state === 'resting');
ok('REST: it is kept as resting, where the owner can ask anyway', !!restingRec);
const listed = JSON.parse(await call(A, 'list_ghosts', { q: 'omar' })).people[0];
ok('REST: the contacts list says so, with the match waiting', listed.held === 'resting' && (listed.matches_waiting || []).length >= 1, `${listed.held}: ${listed.held_why}`);

// ---- the repeat save ----------------------------------------------------------------------------
// The same contact, read again by the agent on its next seeding pass, as note_ghost's own
// description tells it to do ("a second pass finds the same person").
await call(A, 'contacts', { action: 'note', ...omar, threads_sent: 15 });
const after = JSON.parse(await0());
ok('FINDING: a repeat save keeps the count of asks and when the contact was last asked', after.asked === 1 && !!after.lastAskedAt, `asked=${after.asked} lastAskedAt=${after.lastAskedAt}`);
const afterRest = await newAsk('a third need about heat exchangers');
ok('FINDING: so the rest period survives the agent re-reading the mailbox', afterRest.length === 0, `${afterRest.length} new question(s) raised inside the rest period`);

// ---- back off on silence ----------------------------------------------------------------------------
// Two yeses with nothing heard back; then a third need.
for (const m of afterRest) await call(A, 'contacts', { action: 'route', ask_id: m.action.askId, confirmed: true });
let rec = JSON.parse(await0());
// Make the second ask count regardless of the finding above.
if ((rec.asked || 0) < 2) { portals[A].MAILBOX.m.set(keys(A, 'ghost:')[0], JSON.stringify({ ...rec, asked: 2, heard: 0, lastAskedAt: new Date(Date.now() - 20 * 86400000).toISOString() })); rec = JSON.parse(await0()); }
else portals[A].MAILBOX.m.set(keys(A, 'ghost:')[0], JSON.stringify({ ...rec, lastAskedAt: new Date(Date.now() - 20 * 86400000).toISOString() }));
const silent = await newAsk('a fourth need about heat exchangers');
ok('SILENCE: two asks with nothing heard and the contact is out of matching, rest or no rest', silent.length === 0, `${silent.length} raised`);
const found = await J(A, 'find', { need_text: 'someone who knows heat exchangers', tags: ['heat-exchangers'] });
ok('SILENCE: and out of the owner\'s own find', !(found.invites || []).some((i) => /Omar/.test(i.name)));
await call(A, 'contacts', { action: 'heard', ghost_id: 'Omar Haddad' });
const heard = await newAsk('a fifth need about heat exchangers');
ok('SILENCE: a reply recorded brings them back', heard.length === 1);
await call(A, 'contacts', { action: 'note', ...omar });
const afterSave = JSON.parse(await0());
ok('FINDING: a repeat save keeps asked and heard', afterSave.asked >= 2 && afterSave.heard === 1, `asked=${afterSave.asked} heard=${afterSave.heard}`);

// ---- never ask ----------------------------------------------------------------------------------------
portals[A].MAILBOX.m.set(keys(A, 'ghost:')[0], JSON.stringify({ ...JSON.parse(await0()), asked: 0, heard: 0, lastAskedAt: null }));
await call(A, 'contacts', { action: 'never_ask', ghost_id: 'Omar Haddad' });
ok('NEVER: the flag is set', JSON.parse(await0()).neverAsk === true);
ok('NEVER: an arriving need raises nothing', (await newAsk('a sixth need about heat exchangers')).length === 0);
ok('NEVER: the owner\'s own find does not suggest them', !((await J(A, 'find', { need_text: 'someone who knows heat exchangers', tags: ['heat-exchangers'] })).invites || []).some((i) => /Omar/.test(i.name)));
// The paths around it.
const t = await placeAndFind(A, 'heat-exchangers', 'someone who knows heat exchangers');
let invite = ''; try { invite = await call(A, 'contacts', { action: 'invite_text', ghost_id: JSON.parse(await0()).id, thread_id: t.thread_id }); } catch (e) { invite = 'refused: ' + e.message; }
ok('LOW: invite_text still drafts an invitation to a never-ask contact', /refused/.test(invite), invite.slice(0, 80));
ok('LOW: and the owner\'s own invitation does not count as an ask, so the rest period never starts from it', JSON.parse(await0()).asked > 0 || JSON.parse(await0()).lastAskedAt, `asked=${JSON.parse(await0()).asked}`);
// The repeat save, once more.
await call(A, 'contacts', { action: 'note', ...omar, threads_replied: 12 });
ok('FINDING: never-ask survives the agent re-reading the mailbox', JSON.parse(await0()).neverAsk === true, `neverAsk=${JSON.parse(await0()).neverAsk}`);
const afterNever = await newAsk('a seventh need about heat exchangers');
ok('FINDING: and a need arriving after that raises no question', afterNever.length === 0, `${afterNever.length} question(s) raised about a never-ask contact`);
done();
