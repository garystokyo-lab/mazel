// Verification of DOORBELL_DAILY_CAP (§4.3c) plus one Low finding.
// Spec: "Doorbell rings immediately for replies and 🌀; agent-found items ring once each up to a
// daily cap (config, default 3), the rest wait in the box and are named in the next ring."
// boxItem() reads `Number(env.DOORBELL_DAILY_CAP ?? DOORBELL_DAILY_CAP_DEFAULT)`. `??` only
// catches null/undefined, so an env var that is present but EMPTY - which is what an unset
// wrangler var or a blank dashboard field looks like - becomes Number("") === 0, and the doorbell
// is silently switched off for every agent-found item, with no waiting count ever surfaced either
// unless something else rings.
import { addPortal, call, J, ok, done, portals } from '../sec-review-2026-09-28/_harness.mjs';

const mk = async (origin, handle, extra) => { addPortal(origin, handle, extra); return origin; };
const haves = ['fractional-cfo', 'lab-ops', 'channel-sales', 'data-and-crm-migrations', 'healthcare-ai-delivery'];
const peers = [];
for (let i = 0; i < 5; i++) { const o = `https://peer7-${i}.test`; await mk(o, `peer${i}@mazel`); await call(o, 'update_card', { add_have: haves[i], confirmed: true }); peers.push(o); }

const rings = (o) => [...portals[o].MAILBOX.m.entries()].filter(([k]) => k === 'bell:last').map(([, v]) => JSON.parse(v));
const capSpent = (o) => [...portals[o].MAILBOX.m.keys()].filter(k => k.startsWith('cap:bell:found:'));
const waiting = (o) => [...portals[o].MAILBOX.m.entries()].filter(([k]) => k.startsWith('bell:waiting:')).map(([, v]) => Number(v))[0] || 0;

// ---- default cap of 3 ----
const A = await mk('https://a7.test', 'a7@mazel');
for (const p of peers) await call(A, 'add_known_card', { url: p + '/card' });
await J(A, 'find', { need_text: 'people across all five areas', tags: haves });
const spent = Number(portals[A].MAILBOX.m.get(capSpent(A)[0]) || 0);
ok('agent-found items ring up to the default cap of 3', spent === 3, `cap counter = ${spent}`);
ok('the rest wait in the box and are counted', waiting(A) === 2, `waiting = ${waiting(A)}`);
const box = [...portals[A].MAILBOX.m.values()].map(v => { try { return JSON.parse(v); } catch { return {}; } }).filter(m => m.box);
ok('every found item is still in the box, rung or not', box.length === 5, String(box.length));
ok('the last ring names how many are waiting', rings(A).length === 1 && rings(A)[0].waiting === 0, JSON.stringify(rings(A).map(r => r.waiting)));

// ---- an explicit cap is honoured ----
const B = await mk('https://b7.test', 'b7@mazel', { DOORBELL_DAILY_CAP: '1' });
for (const p of peers) await call(B, 'add_known_card', { url: p + '/card' });
await J(B, 'find', { need_text: 'people across all five areas', tags: haves });
ok('DOORBELL_DAILY_CAP=1 rings once', Number(portals[B].MAILBOX.m.get(capSpent(B)[0]) || 0) === 1, String(capSpent(B).length));
ok('and the other four wait', waiting(B) === 4, String(waiting(B)));

// ---- a cap of 0 is silence, as configured ----
const C = await mk('https://c7.test', 'c7@mazel', { DOORBELL_DAILY_CAP: '0' });
for (const p of peers) await call(C, 'add_known_card', { url: p + '/card' });
await J(C, 'find', { need_text: 'people across all five areas', tags: haves });
ok('DOORBELL_DAILY_CAP=0 never rings for agent-found items', rings(C).length === 0 && waiting(C) === 5, `rings ${rings(C).length}, waiting ${waiting(C)}`);

// ---- a reply always rings, cap or no cap: boxItem returns ringBell() before the cap is consulted ----

// ---- the Low: an empty env var silently means zero ----
const D = await mk('https://d7.test', 'd7@mazel', { DOORBELL_DAILY_CAP: '' });
for (const p of peers) await call(D, 'add_known_card', { url: p + '/card' });
await J(D, 'find', { need_text: 'people across all five areas', tags: haves });
const rang = rings(D).length;
ok('an empty DOORBELL_DAILY_CAP must fall back to the default of 3, not to silence', rang > 0,
   `rings ${rang}, waiting ${waiting(D)}, cap counter ${Number(portals[D].MAILBOX.m.get(capSpent(D)[0]) || 0)}`);
if (!rang) console.log(`FAIL DOORBELL_DAILY_CAP="" is read as 0: Number("") is 0 and 0 >= 0, so the doorbell went silent for all 5 agent-found items and ${waiting(D)} sat waiting with nothing to announce them.`);
done();
