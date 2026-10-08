// Shared harness for the 2026-09-28 security review. Same shape as ../thread-test.mjs: in-memory KV,
// worker.fetch with an env per portal, a fetch stub that routes cross-portal calls to the right env.
// Nothing here touches index.js; the signing helper re-implements canonical + Ed25519 so a test can
// speak as a portal whose key it holds (the harness owns every portal's KV).
import rawWorker from '../../src/index.js';
import { legacy as legacyWorker } from '../a2a-helpers.mjs';
const worker = legacyWorker(rawWorker);
export { worker };
export const mkKV = () => { const m = new Map(); return { m, get: async k => m.get(k) ?? null, put: async (k, v) => m.set(k, v), delete: async k => m.delete(k), list: async ({ prefix }) => ({ keys: [...m.keys()].filter(k => k.startsWith(prefix)).sort().map(name => ({ name })), list_complete: true }) }; };
export const R = 'https://relay.sec';
export const portals = {};
export const wire = [];
export const down = new Set();
export const stubs = [];           // [{ test: (url) => bool, reply: async (url, init) => Response }]
export const relayReplies = { directory: {} };   // name -> record object served at R/.well-known/mazel/<name>.json
export const addPortal = (origin, handle, extra = {}) => { portals[origin] = { HANDLE: handle, PERSONA: `${handle} persona.`, NEED: '', HAVE: '', INBOX_TOKEN: 't-' + handle, MAILBOX: mkKV(), RELAY_URL: R, PORTAL_ORIGIN: origin, ...extra }; return portals[origin]; };
globalThis.fetch = async (u, i = {}) => {
  const url = String(u instanceof Request ? u.url : u);
  const body = String(i.body || '');
  wire.push({ url, body, method: i.method || 'GET' });
  for (const s of stubs) if (s.test(url)) return s.reply(url, i);
  if (url.startsWith(R)) {
    const m = url.match(/\/\.well-known\/mazel\/([a-z0-9._-]+)\.json$/);
    if (m) { const rec = relayReplies.directory[m[1]]; return rec ? new Response(JSON.stringify(rec), { headers: { 'content-type': 'application/json' } }) : new Response('{"error":"no such handle"}', { status: 404 }); }
    if (/relay\.json$/.test(url)) return new Response(JSON.stringify({ publicKey: relayReplies.publicKey || 'none' }), { headers: { 'content-type': 'application/json' } });
    return new Response(JSON.stringify({ ok: true, hits: [], results: [] }), { headers: { 'content-type': 'application/json' } });
  }
  const o = new URL(url).origin;
  if (down.has(o)) return new Response('unreachable', { status: 503 });
  if (portals[o]) return worker.fetch(new Request(url, i), portals[o]);
  return new Response('no', { status: 503 });
};
export const call = async (o, name, args) => {
  const j = JSON.parse(await (await worker.fetch(new Request(o + '/mcp', { method: 'POST', headers: { 'content-type': 'application/json', authorization: 'Bearer ' + portals[o].INBOX_TOKEN }, body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'tools/call', params: { name, arguments: args || {} } }) }), portals[o])).text());
  if (j.error) throw new Error(j.error.message);
  if (j.result.isError) throw new Error(j.result.content[0].text);
  return j.result.content[0].text;
};
export const J = async (...a) => JSON.parse(await call(...a));
export const pulse = async (o) => { let p; await worker.scheduled({}, portals[o], { waitUntil: (x) => { p = x; } }); return p; };
let pass = 0, fail = 0;
export const ok = (l, c, x = '') => { console.log((c ? 'PASS ' : 'FAIL ') + l + (x ? '  -> ' + String(x).replace(/\n/g, ' ').slice(0, 160) : '')); c ? pass++ : fail++; };
export const done = () => { console.log(`${pass} passed, ${fail} failed`); process.exit(fail ? 1 : 0); };
export const conv = (o, id) => JSON.parse(portals[o].MAILBOX.m.get('conv:' + id) || 'null');
export const keys = (o, prefix) => [...portals[o].MAILBOX.m.keys()].filter(k => k.startsWith(prefix));
export const mail = async (o) => { const t = await call(o, 'check_mailbox'); return t.startsWith('📭') ? [] : JSON.parse(t).messages; };
export const lastIntro = (o, to) => [...portals[o].MAILBOX.m.entries()].filter(([k, v]) => k.startsWith('intro:') && JSON.parse(v).direction === 'sent' && JSON.parse(v).handle === to).map(([, v]) => JSON.parse(v)).sort((a, b) => (b.created || '').localeCompare(a.created || ''))[0].id;

// ---- crypto, same bytes as the portal ----
export const b64u = (buf) => btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
export const canonical = (v) => v === null || typeof v !== 'object' ? JSON.stringify(v) : Array.isArray(v) ? '[' + v.map(canonical).join(',') + ']' : '{' + Object.keys(v).sort().map(k => JSON.stringify(k) + ':' + canonical(v[k])).join(',') + '}';
export const signingOf = async (o) => { if (!portals[o].MAILBOX.m.get('config:signing')) await worker.fetch(new Request(o + '/card'), portals[o]); return JSON.parse(portals[o].MAILBOX.m.get('config:signing')); };
export const signWith = async (s, payload) => { const key = await crypto.subtle.importKey('jwk', s.priv, { name: 'Ed25519' }, false, ['sign']); const sig = await crypto.subtle.sign({ name: 'Ed25519' }, key, new TextEncoder().encode(canonical(payload))); return { ...payload, sig: b64u(sig), kid: s.kid }; };
export const newKeypair = async () => { const pair = await crypto.subtle.generateKey({ name: 'Ed25519' }, true, ['sign', 'verify']); const priv = await crypto.subtle.exportKey('jwk', pair.privateKey); const pub = b64u(await crypto.subtle.exportKey('raw', pair.publicKey)); const h = await crypto.subtle.digest('SHA-256', Uint8Array.from(atob(pub.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - pub.length % 4) % 4)), c => c.charCodeAt(0))); return { priv, pub, kid: b64u(h).slice(0, 16) }; };
// A signed action the way signedCast makes one, for a portal (or a bare keypair with a claimed handle).
export const signedAction = async (s, { origin, handle }, extra) => signWith(s, { v: 1, handle, publicKey: s.pub, cardUrl: `${origin}/.well-known/agent-card.json`, rpc: `${origin}/a2a`, castAt: new Date().toISOString(), ...extra });
// POST an A2A SendMessage at a portal's door, as a peer would.
export const a2a = (o, message, headers = {}) => worker.fetch(new Request(o + '/a2a', { method: 'POST', headers: { 'content-type': 'application/json', ...headers }, body: JSON.stringify({ jsonrpc: '2.0', id: message.messageId || 'x', method: 'SendMessage', params: { message } }) }), portals[o]);
export const noteMsg = (text, { handle, cardUrl, action, messageId } = {}) => ({ messageId: messageId || 'm-' + Math.random().toString(16).slice(2), contextId: '', taskId: '', role: 'ROLE_USER', parts: [{ text }], metadata: { ...(handle ? { handle } : {}), ...(cardUrl ? { cardUrl } : {}), ...(action ? { action } : {}) }, extensions: ['https://mazel.ai/ext/haah/v1'], referenceTaskIds: [] });
// A thread message signed by `s`, claiming `from`, exactly as buildMessage lays it out.
export const threadMsg = async (s, { contextId, from, text, author = 'human', at = new Date().toISOString(), messageId = crypto.randomUUID() }) => {
  const parts = [{ text }];
  const m = { messageId, contextId, taskId: '', role: 'ROLE_USER', parts, metadata: { haah: { author, from, at, envelope: null }, action: { type: 'thread.message', v: 1 } }, extensions: ['https://mazel.ai/ext/haah/v1'], referenceTaskIds: [] };
  const { sig, kid } = await signWith(s, { contextId, messageId, parts, author, from, at });
  m.metadata.haah.sig = sig; m.metadata.haah.kid = kid;
  return m;
};
// The ordinary road to a thread: A finds B on a tag, proposes, B accepts. Returns the contextId.
export const openThread = async (A, B, tag, handleB) => {
  await call(B, 'update_card', { add_have: tag, confirmed: true });
  await call(A, 'add_known_card', { url: B + '/card' });
  await call(B, 'add_known_card', { url: A + '/card' });
  // A need has to be placed before its words leave the portal, which a proposal does.
  await call(A, 'update_card', { add_need: tag, confirmed: true });
  const f = await J(A, 'find', { need_text: `someone who does ${tag}`, tags: [tag] });
  const c = f.candidates.find(x => x.handle === handleB);
  await call(A, 'propose_intro', { thread_id: f.thread_id, card_url: c.card_url, ask: { kind: 'call', size: '20 minutes' }, confirmed: true });
  const introId = lastIntro(A, handleB);
  await call(B, 'respond_intro', { intro_id: introId, decision: 'accepted', confirmed: true });
  const tl = await call(A, 'thread_list');
  // Since v0.5.8 the people join the branch the agents opened: origin need, humans true.
  const found = tl.startsWith('No') ? [] : JSON.parse(tl).threads.filter(t => t.with.includes(handleB) && t.state === 'open' && (t.origin === 'direct' || (t.origin === 'need' && t.humans))).sort((x, y) => (y.updated || '').localeCompare(x.updated || ''));
  if (!found.length) {
    const ia = [...portals[A].MAILBOX.m.entries()].filter(([k]) => k === 'intro:' + introId).map(([, v]) => { const i = JSON.parse(v); return [i.state, i.delivered, i.queued, i.lastError]; });
    const ib = [...portals[B].MAILBOX.m.entries()].filter(([k]) => k === 'intro:' + introId).map(([, v]) => { const i = JSON.parse(v); return [i.state, i.lastError]; });
    const { writeFileSync } = await import('node:fs'); writeFileSync('/tmp/openthread-diag.json', JSON.stringify({ A, B, handleB, introA: ia, introB: ib, threads: JSON.parse(tl.startsWith('No') ? '{"threads":[]}' : tl).threads.map(t => [t.context_id.slice(0, 8), t.with, t.state, t.origin]) }, null, 1));
    throw new Error(`openThread(${A}, ${B}): no direct open thread with ${handleB}; see /tmp/openthread-diag.json`);
  }
  const ctx = found[0].context_id;
  return { ctx, introId };
};
