// Evidence for section 2 of the report (passes today): the tool surface is 27 names, old names are
// refused, merged parts are unreachable by name, the wire is nine types and anything else is a note,
// push configs are answered and never stored.
import { addPortal, call, ok, done, portals, worker, a2a, noteMsg } from '../sec-review-2026-09-28/_harness.mjs';
import raw from '../../src/index.js';   // the portal itself, not the legacy() wrapper the suites use
const B = 'https://bob-g0.test';
addPortal(B, 'bob@mazel');
const list = JSON.parse(await (await worker.fetch(new Request(B + '/mcp', { method: 'POST', headers: { 'content-type': 'application/json', authorization: 'Bearer ' + portals[B].INBOX_TOKEN }, body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'tools/list' }) }), portals[B])).text()).result.tools.map((t) => t.name);
const hidden = JSON.parse(await call(B, 'more_tools')).tools.map((t) => t.name);
ok('19 listed tools', list.length === 19, list.join(','));
ok('8 hidden tools', hidden.length === 8, hidden.join(','));
ok('27 callable names in all', list.length + hidden.length === 27);
const refused = [];
for (const n of ['list_known_cards', 'add_known_card', 'resolve_handle', 'my_identity', 'clear_messages', 'fetch_peer_card', 'check_mutual', 'route_ghost', 'carriers', 'thread_block', 'tribe_join', 'list_threads', 'note_ghost']) {
  try { await raw.fetch(new Request(B + '/mcp', { method: 'POST', headers: { 'content-type': 'application/json', authorization: 'Bearer ' + portals[B].INBOX_TOKEN }, body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'tools/call', params: { name: n, arguments: {} } }) }), portals[B]).then(async (r) => { const j = await r.json(); if (!(j.result && j.result.isError && /unknown tool/.test(j.result.content[0].text))) refused.push(n + ': ' + (j.result ? j.result.content[0].text.slice(0, 60) : JSON.stringify(j))); }); } catch (e) { refused.push(n + ': threw ' + e.message); }
}
ok('every old or internal name is refused as unknown', !refused.length, refused.join(' | '));
// Wire: an unknown action type is a note; the removed types are not handled.
for (const t of ['find.request', 'thread.leave', 'thread.lapsed', 'gossip.forward']) {
  const r = await (await a2a(B, noteMsg('hi', { action: { type: t, v: 1, needId: 'x', contextId: 'y' } }))).json();
  ok(`${t} on the wire is taken as a plain note`, !!r.result);
}
const stored = [...portals[B].MAILBOX.m.entries()].filter(([k]) => k.startsWith('msg:')).map(([, v]) => JSON.parse(v));
ok('stored as type note, from nobody in particular', stored.length === 4 && stored.every((m) => m.action.type === 'note' && m.fromHandle === 'unverified'), JSON.stringify(stored.map((m) => [m.action.type, m.fromHandle])));
// Push configs: answered, nothing kept.
const pc = await (await worker.fetch(new Request(B + '/a2a', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'CreateTaskPushNotificationConfig', params: { config: { url: 'https://evil.example/hook', token: 'secret', taskId: '*' } } }) }), portals[B])).json();
ok('a push config is answered', !!pc.result);
ok('and nothing about it is stored', ![...portals[B].MAILBOX.m.keys()].some((k) => /pulse|push|cfg/.test(k)), [...portals[B].MAILBOX.m.keys()].filter((k) => /pulse|push|cfg/.test(k)).join(','));
done();
