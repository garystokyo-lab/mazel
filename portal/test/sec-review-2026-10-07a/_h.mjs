// Harness for the 2026-10-07a security review. In-memory KV per portal, a fetch stub that routes
// cross-portal calls to the right env, a SQLite-backed storage object stub with the shape Cloudflare
// gives one, and a signer that speaks as any portal whose KV this harness owns. Nothing here touches
// src/index.js.
import rawWorker, { Portal } from '../../src/index.js';
import { legacy as legacyWorker } from '../a2a-helpers.mjs';
export const worker = legacyWorker(rawWorker);
export const raw = rawWorker;

// KV, with a write counter by prefix so a test can say what one inbound message cost.
export const mkKV = () => {
  const m = new Map(); const puts = {}; const ttl = new Map();
  const kv = {
    m, puts, ttl,
    get: async (k) => m.get(k) ?? null,
    put: async (k, v, o) => { m.set(k, v); if (o && o.expirationTtl) ttl.set(k, o.expirationTtl); else ttl.delete(k); const p = k.split(':')[0]; puts[p] = (puts[p] || 0) + 1; },
    delete: async (k) => { m.delete(k); ttl.delete(k); },
    list: async ({ prefix }) => ({ keys: [...m.keys()].filter((k) => k.startsWith(prefix)).sort().map((name) => ({ name })), list_complete: true }),
    reset: () => { for (const k of Object.keys(puts)) delete puts[k]; },
  };
  return kv;
};
// Real Workers KV lists at most a thousand keys per call and hands back a cursor for the rest.
export const mkPagedKV = (pageSize = 1000) => {
  const kv = mkKV();
  kv.list = async ({ prefix, cursor }) => {
    const all = [...kv.m.keys()].filter((k) => k.startsWith(prefix || '')).sort();
    const start = cursor ? Number(cursor) : 0;
    const page = all.slice(start, start + pageSize);
    const complete = start + pageSize >= all.length;
    return { keys: page.map((name) => ({ name })), list_complete: complete, ...(complete ? {} : { cursor: String(start + pageSize) }) };
  };
  return kv;
};

// The storage object, stubbed the way do-store-test stubs it, against the real Portal class.
function sqlStub() {
  const rows = new Map();
  return {
    exec(q, ...a) {
      const sql = q.replace(/\s+/g, ' ').trim();
      if (sql.startsWith('CREATE TABLE')) return [];
      if (sql.startsWith('SELECT v, exp FROM kv WHERE k = ?')) { const r = rows.get(a[0]); return r ? [{ v: r.v, exp: r.exp }] : []; }
      if (sql.startsWith('INSERT INTO kv')) { if (a[1] === null || a[1] === undefined) throw new Error('NOT NULL constraint failed: kv.v'); rows.set(a[0], { v: a[1], exp: a[2] }); return []; }
      if (sql.startsWith('DELETE FROM kv WHERE k = ?')) { rows.delete(a[0]); return []; }
      if (sql.startsWith('SELECT k, exp FROM kv WHERE k >= ? AND k < ?')) return [...rows.entries()].filter(([k]) => k >= a[0] && k < a[1]).sort((x, y) => (x[0] < y[0] ? -1 : 1)).map(([k, r]) => ({ k, exp: r.exp }));
      throw new Error('the Portal object issued SQL this stub does not know: ' + sql);
    },
    _rows: rows,
  };
}
export const makeObject = () => {
  const sql = sqlStub();
  const o = new Portal({ storage: { sql } });
  let failAfter = Infinity, writes = 0;
  const stub = { fetch: (url, init) => { const b = JSON.parse(init.body); if (b.op === 'put' && ++writes > failAfter) return Promise.resolve(new Response('object unavailable', { status: 503 })); return o.fetch(new Request(url, init)); } };
  return { stub, sql, rows: sql._rows, setFailAfter: (n) => { failAfter = n; writes = 0; }, binding: { idFromName: () => 'portal', get: () => stub } };
};

export const R = 'https://relay.sec07';
export const portals = {};
export const wire = [];
export const relayReplies = { directory: {} };
export const addPortal = (origin, handle, extra = {}) => { portals[origin] = { HANDLE: handle, PERSONA: `${handle.split('@')[0]} runs a small firm.`, NEED: '', HAVE: '', INBOX_TOKEN: 't-' + handle, MAILBOX: mkKV(), RELAY_URL: R, PORTAL_ORIGIN: origin, ...extra }; return portals[origin]; };
let ipSeq = 0;
globalThis.fetch = async (u, i = {}) => {
  const url = String(u instanceof Request ? u.url : u);
  const body = String(i.body || '');
  wire.push({ url, body, method: i.method || 'GET', at: Date.now() });
  if (url.startsWith(R)) {
    const m = url.match(/\/\.well-known\/mazel\/([a-z0-9._-]+)\.json$/);
    if (m) { const rec = relayReplies.directory[m[1]]; return rec ? new Response(JSON.stringify(rec), { headers: { 'content-type': 'application/json' } }) : new Response('{"error":"no such handle"}', { status: 404 }); }
    return new Response(JSON.stringify({ ok: true, hits: [], results: [] }), { headers: { 'content-type': 'application/json' } });
  }
  const o = new URL(url).origin;
  if (portals[o]) {
    // Each portal-to-portal call comes from its own address, so the per-IP ceiling never trips a test.
    const headers = new Headers(i.headers || {}); if (!headers.get('CF-Connecting-IP')) headers.set('CF-Connecting-IP', `10.0.${(ipSeq >> 8) & 255}.${ipSeq++ & 255}`);
    return worker.fetch(new Request(url, { ...i, headers }), portals[o]);
  }
  return new Response('no', { status: 503 });
};
export const mcp = async (o, body, token = portals[o].INBOX_TOKEN) => (await worker.fetch(new Request(o + '/mcp', { method: 'POST', headers: { 'content-type': 'application/json', ...(token ? { authorization: 'Bearer ' + token } : {}) }, body: JSON.stringify(body) }), portals[o]));
export const call = async (o, name, args) => {
  const j = JSON.parse(await (await mcp(o, { jsonrpc: '2.0', id: 1, method: 'tools/call', params: { name, arguments: args || {} } })).text());
  if (j.error) throw new Error(j.error.message);
  if (j.result.isError) throw new Error(j.result.content[0].text);
  return j.result.content[0].text;
};
export const J = async (...a) => JSON.parse(await call(...a));
export const pulse = async (o) => { let p; await worker.scheduled({}, portals[o], { waitUntil: (x) => { p = x; } }); await p; };
let pass = 0, fail = 0;
export const ok = (l, c, x = '') => { console.log((c ? 'PASS ' : 'FAIL ') + l + (x ? '  -> ' + String(x).replace(/\n/g, ' ').slice(0, 180) : '')); c ? pass++ : fail++; };
export const done = () => { console.log(`${pass} passed, ${fail} failed`); process.exit(fail ? 1 : 0); };
export const keys = (o, prefix) => [...portals[o].MAILBOX.m.keys()].filter((k) => k.startsWith(prefix));
export const mail = async (o) => { const t = await call(o, 'check_mailbox'); return t.startsWith('📭') ? [] : JSON.parse(t).messages; };
export const asks = async (o) => (await mail(o)).filter((m) => (m.action || {}).type === 'ghost.ask');
// A need placed on the card, then found: the way every cast in the suites goes since v0.5.9-live.
export const placeAndFind = async (o, tag, text, visibility = 'public') => {
  try { await call(o, 'update_card', { add_need: tag, ...(visibility !== 'public' ? { need_visibility: visibility } : {}), confirmed: true }); } catch { /* already there */ }
  return J(o, 'find', { need_text: text, tags: [tag] });
};
export const hold = (a, b) => call(a, 'add_known_card', { url: b + '/card' });
export const wireFrom = (origin, since = 0) => wire.slice(since).filter((w) => w.url.startsWith(origin) === false && w.method === 'POST' && w.body.includes(`"handle":"${portals[origin].HANDLE}"`));
export const wireTo = (origin, since = 0) => wire.slice(since).filter((w) => w.url.startsWith(origin) && w.method === 'POST');

// ---- crypto, same bytes as the portal ----
export const b64u = (buf) => btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
export const canonical = (v) => v === null || typeof v !== 'object' ? JSON.stringify(v) : Array.isArray(v) ? '[' + v.map(canonical).join(',') + ']' : '{' + Object.keys(v).sort().map((k) => JSON.stringify(k) + ':' + canonical(v[k])).join(',') + '}';
export const signingOf = async (o) => { if (!portals[o].MAILBOX.m.get('config:signing')) await worker.fetch(new Request(o + '/card'), portals[o]); return JSON.parse(portals[o].MAILBOX.m.get('config:signing')); };
export const signWith = async (s, payload) => { const key = await crypto.subtle.importKey('jwk', s.priv, { name: 'Ed25519' }, false, ['sign']); const sig = await crypto.subtle.sign({ name: 'Ed25519' }, key, new TextEncoder().encode(canonical(payload))); return { ...payload, sig: b64u(sig), kid: s.kid }; };
export const newKeypair = async () => { const pair = await crypto.subtle.generateKey({ name: 'Ed25519' }, true, ['sign', 'verify']); const priv = await crypto.subtle.exportKey('jwk', pair.privateKey); const pub = b64u(await crypto.subtle.exportKey('raw', pair.publicKey)); const h = await crypto.subtle.digest('SHA-256', Uint8Array.from(atob(pub.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - pub.length % 4) % 4)), (c) => c.charCodeAt(0))); return { priv, pub, kid: b64u(h).slice(0, 16) }; };
export const signedAction = async (s, { origin, handle }, extra) => signWith(s, { v: 1, handle, publicKey: s.pub, cardUrl: `${origin}/.well-known/agent-card.json`, rpc: `${origin}/a2a`, castAt: new Date().toISOString(), ...extra });
export const a2a = (o, message, headers = {}) => worker.fetch(new Request(o + '/a2a', { method: 'POST', headers: { 'content-type': 'application/json', 'CF-Connecting-IP': `10.9.${(ipSeq >> 8) & 255}.${ipSeq++ & 255}`, ...headers }, body: JSON.stringify({ jsonrpc: '2.0', id: message.messageId || 'x', method: 'SendMessage', params: { message } }) }), portals[o]);
export const a2aRaw = (o, body, headers = {}) => worker.fetch(new Request(o + '/a2a', { method: 'POST', headers: { 'content-type': 'application/json', 'CF-Connecting-IP': `10.9.${(ipSeq >> 8) & 255}.${ipSeq++ & 255}`, ...headers }, body }), portals[o]);
export const noteMsg = (text, { handle, cardUrl, action, messageId } = {}) => ({ messageId: messageId || 'm-' + Math.random().toString(16).slice(2), contextId: '', taskId: '', role: 'ROLE_USER', parts: [{ text }], metadata: { ...(handle ? { handle } : {}), ...(cardUrl ? { cardUrl } : {}), ...(action ? { action } : {}) }, extensions: ['https://mazel.ai/ext/haah/v1'], referenceTaskIds: [] });
// An offer exactly as offerNeed signs one, from a portal whose key this harness holds.
export const offerFrom = async (o, { needId, needText, needTags, fp }) => {
  const s = await signingOf(o);
  const body = fp ? { type: 'need.offer', needId, tier: 'matched-only', fp } : { type: 'need.offer', needId, tier: 'public', needText, needTags };
  return { ...(await signedAction(s, { origin: o, handle: portals[o].HANDLE }, body)), v: 1 };
};
export const ackOf = async (res) => { const j = await res.json(); return j.error ? `error ${j.error.code}: ${j.error.message}` : ((j.result.message || {}).parts || []).map((p) => p.text).join(' '); };
