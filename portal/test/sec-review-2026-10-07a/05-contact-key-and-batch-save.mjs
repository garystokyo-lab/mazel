// Item 4: the keyed hash per person and the batch save. Whether the secret or a key can leave the
// portal, whether an outsider can confirm a guess, whether a batch writes partial data.
import { addPortal, call, J, ok, done, portals, wire, keys, hold, pulse, worker, makeObject, mkKV } from './_h.mjs';
const A = 'https://avery-07a5.test', B = 'https://lea-07a5.test';
const obj = makeObject();
addPortal(A, 'avery@mazel', { PORTAL: obj.binding }); addPortal(B, 'lea@mazel');
await hold(A, B); await hold(B, A);
// ---- the batch ------------------------------------------------------------------------------------------
const mk = (n, from = 0) => Array.from({ length: n }, (_, i) => ({ name: `Person ${from + i}`, org: `p${from + i}.example`, email: `p${from + i}@p${from + i}.example`, have: ['widgets'], role: 'Makes widgets', witnesses: ['hubspot'], small_meetings: 2 }));
let refused = '';
try { refused = await call(A, 'contacts', { action: 'note', people: mk(51) }); } catch (e) { refused = e.message; }
ok('fifty-one is refused in words', /Not written, none of them/.test(refused), refused.slice(0, 60));
ok('and nothing at all was written', keys(A, 'ghost:').length === 0);
const fifty = await call(A, 'contacts', { action: 'note', people: mk(50) });
ok('fifty is written', /Wrote 50 of 50/.test(fifty) && keys(A, 'ghost:').length === 50);
// Malformed entries inside a batch: shapes an agent might send. None should throw half-way.
let odd = '';
try { odd = await call(A, 'contacts', { action: 'note', people: [{ name: 'Odd One', have: 5, witnesses: { a: 1 }, email: { not: 'a string' }, edge_score: 'ninety', last_inbound_at: {}, state: 'cooled', tone: 'cold' }, { name: '' }, null, { name: 'Odd Two', org: 'https://odd.example/path', people: [{ name: 'nested' }] }] }); } catch (e) { odd = 'threw: ' + e.message; }
ok('odd shapes inside a batch are written or skipped, never a half-batch error', /Wrote 2 of 4/.test(odd), odd.slice(0, 80));
// Two different people with the same name and no organisation.
await call(A, 'contacts', { action: 'note', name: 'Sam Lee', have: ['tax'], role: 'Tax adviser' });
await call(A, 'contacts', { action: 'note', name: 'Sam Lee', have: ['sailing'], role: 'Sailing instructor' });
const sams = JSON.parse(await call(A, 'list_ghosts', { q: 'sam lee' })).people;
ok('LOW: two different people with one name and no organisation become one record', sams.length === 2, `${sams.length} record(s): ${sams.map((s) => s.have.join('+')).join(' / ')}`);

// ---- the secret and the keys ---------------------------------------------------------------------------
const secret = portals[A].MAILBOX.m.get('config:contact-key');
ok('a secret exists on the portal once a contact with an address was saved', !!secret && secret.length === 64);
const ghost = JSON.parse(portals[A].MAILBOX.m.get(keys(A, 'ghost:')[0]));
ok('the record holds a key for the address and not the address', ghost.ekeys.length === 1 && !JSON.stringify(ghost).includes('@p'));
// A second pass with the same address, a different spelling of the name: the same record.
const beforeRepeat = keys(A, 'ghost:').length;
await call(A, 'contacts', { action: 'note', name: 'Person 0 (renamed)', email: 'P0@P0.EXAMPLE', have: ['widgets', 'gears'] });
ok('a repeat save by address finds the same person', keys(A, 'ghost:').length === beforeRepeat && JSON.parse(await call(A, 'list_ghosts', { q: 'renamed' })).people[0].have.includes('gears'), `${keys(A, 'ghost:').length} records`);
// The outsider's view: the same address hashed on another portal is a different key.
await call(B, 'contacts', { action: 'note', name: 'Person 0', email: 'p0@p0.example' });
const theirs = JSON.parse(portals[B].MAILBOX.m.get(keys(B, 'ghost:')[0])).ekeys[0];
ok('the same address on another portal gives a different key: nothing to look up', theirs !== ghost.ekeys[0]);
// Does the secret or a key leave through any read the owner's agent can make, or on the wire?
const outputs = [];
for (const [name, args] of [['my_card', {}], ['my_memory', {}], ['list_ghosts', {}], ['check_mailbox', {}], ['thread_list', {}], ['list_intros', {}], ['cards', { action: 'list' }], ['more_tools', {}], ['find', { need_text: 'a widget maker', tags: ['widgets'] }], ['migrate_store', { verify_only: true }], ['tribe', { action: 'status' }]]) {
  try { outputs.push(name + ' ' + await call(A, name, args)); } catch (e) { outputs.push(name + ' error ' + e.message); }
}
const all = outputs.join('\n');
ok('the secret is in no tool result', !all.includes(secret));
ok('a contact key is shown only to the owner, in the contacts list', all.includes(ghost.ekeys[0]) && outputs.filter((o) => o.includes(ghost.ekeys[0])).every((o) => o.startsWith('list_ghosts')));
ok('migrate_store names keys, never values', !outputs.find((o) => o.startsWith('migrate_store')).includes(secret));
await pulse(A);
const outbound = wire.filter((w) => !w.url.startsWith(A) && w.method === 'POST' && w.body.includes('avery@mazel')).map((w) => w.body).join('\n');
ok('neither the secret nor any contact key has been on the wire', !outbound.includes(secret) && !ghost.ekeys.some((k) => outbound.includes(k)));
// Public faces.
const card = await (await worker.fetch(new Request(A + '/card'), portals[A])).text();
const rec = await (await worker.fetch(new Request(A + '/.well-known/mazel/avery.json'), portals[A])).text();
ok('nor on the card or the handle record', !card.includes(secret) && !rec.includes(secret) && !card.includes(ghost.ekeys[0]));
done();
