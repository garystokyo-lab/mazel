// Item 3: migrate_store. Who can call it; a stranger's replay; a half-finished copy; a store that
// lists a thousand keys at a time, which is what Workers KV does.
import { addPortal, call, J, ok, done, portals, mkPagedKV, mkKV, makeObject, mcp, worker } from './_h.mjs';
const A = 'https://avery-07a4.test';
const obj = makeObject();
addPortal(A, 'avery@mazel', { MAILBOX: mkPagedKV(1000), PORTAL: obj.binding });     // KV mode, object bound, not switched
const kv = portals[A].MAILBOX;
// A portal with a real history: twelve hundred keys, some with a TTL.
for (let i = 0; i < 1150; i++) kv.m.set(`msg:${String(i).padStart(5, '0')}:x`, JSON.stringify({ id: i, text: 'hello' })), kv.ttl.set(`msg:${String(i).padStart(5, '0')}:x`, 2592000);
for (let i = 0; i < 50; i++) kv.m.set(`thread:t${i}`, JSON.stringify({ id: `t${i}`, status: 'open', need_text: 'n', tags: [], candidates: [], expires: new Date(Date.now() + 1e9).toISOString() }));
kv.m.set('config:contact-key', 'deadbeef'.repeat(8));
await call(A, 'my_card');
const total = kv.m.size;

// ---- who can call it -----------------------------------------------------------------------------
const noTok = await mcp(A, { jsonrpc: '2.0', id: 1, method: 'tools/call', params: { name: 'migrate_store', arguments: {} } }, null);
ok('a stranger without the connector key cannot call migrate_store', noTok.status === 401 || noTok.status === 403, `HTTP ${noTok.status}`);
const badTok = await mcp(A, { jsonrpc: '2.0', id: 1, method: 'tools/call', params: { name: 'migrate_store', arguments: {} } }, 'wrong');
ok('nor with a wrong key', badTok.status === 401 || badTok.status === 403, `HTTP ${badTok.status}`);
ok('and the object took nothing from either attempt', obj.rows.size === 0);
const listed = JSON.parse(await (await mcp(A, { jsonrpc: '2.0', id: 1, method: 'tools/list' })).text()).result.tools.map((t) => t.name);
ok('the tool is off the listed surface', !listed.includes('migrate_store'));

// ---- a copy that lists a thousand keys at a time ---------------------------------------------------
const r = await J(A, 'migrate_store', {});
ok('the report says the copy is complete and equal', r.equal === true, `equal=${r.equal} source_keys=${r.source_keys} kv_keys=${r.kv_keys} object_keys=${r.object_keys}`);
ok('FINDING: but the object holds fewer keys than KV, and the report could not see it', obj.rows.size === total - 0, `KV holds ${total} keys; the object holds ${obj.rows.size}; the report counted kv_keys=${r.kv_keys}`);
const missing = [...kv.m.keys()].filter((k) => !obj.rows.has(k) && k !== 'card:public');
ok('FINDING: the keys past the first page were never copied', missing.length === 0, `${missing.length} missing, e.g. ${missing.slice(0, 3).join(', ')}`);
ok('FINDING: running it again does not find them either (same first page)', (await J(A, 'migrate_store', {})).equal === false, 'second run also reports equal');
// ---- TTLs -------------------------------------------------------------------------------------------
const copied = [...obj.rows.entries()].filter(([k]) => k.startsWith('msg:'));
ok('LOW: a mailbox message that expired in thirty days on KV is copied with no expiry', copied.some(([, v]) => v.exp), `${copied.filter(([, v]) => !v.exp).length} of ${copied.length} copied msg: rows have exp=null`);

// ---- a half-finished copy, then a second run ----------------------------------------------------------
const B = 'https://lea-07a4.test';
const obj2 = makeObject();
addPortal(B, 'lea@mazel', { MAILBOX: mkKV(), PORTAL: obj2.binding });
for (let i = 0; i < 40; i++) portals[B].MAILBOX.m.set(`thread:t${i}`, JSON.stringify({ id: `t${i}` }));
await call(B, 'my_card');
obj2.setFailAfter(10);
let err = '';
try { await call(B, 'migrate_store', {}); } catch (e) { err = e.message; }
ok('a copy the object stops answering mid-way fails loudly rather than reporting success', !!err, err.slice(0, 80));
ok('and what was copied before the stop is there, nothing else', obj2.rows.size > 0 && obj2.rows.size < portals[B].MAILBOX.m.size, `${obj2.rows.size} of ${portals[B].MAILBOX.m.size}`);
obj2.setFailAfter(Infinity);
const again = await J(B, 'migrate_store', {});
ok('a second run completes it and says so', again.equal === true && again.missing_on_target.length === 0, JSON.stringify({ equal: again.equal, written: again.written, same: again.already_identical }));
ok('KV was never written by any of it', Object.keys(portals[B].MAILBOX.puts).every((p) => !['thread', 'msg'].includes(p)), JSON.stringify(portals[B].MAILBOX.puts));
// ---- the way back ------------------------------------------------------------------------------------
portals[B].STORE = 'do';
await call(B, 'update_card', { add_have: 'written-in-the-object', witnesses: ['hubspot'], confirmed: true });
const back = await J(B, 'migrate_store', { direction: 'to-kv' });
ok('a copy back carries what was written in the object since', back.equal === true && (portals[B].MAILBOX.m.get('memory:card.md') || '').includes('written-in-the-object'));
ok('and leaves the published card where it was', !obj2.rows.has('card:public'));
done();
