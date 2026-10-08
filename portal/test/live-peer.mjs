// Live smoke against the permanent test peer. Read-mostly: it never writes to Avery's portal.
// Needs PEER_URL and PEER_TOKEN. Skips (exit 0) when they are absent so local runs stay green.
const P = process.env.PEER_URL, T = process.env.PEER_TOKEN;
if (!P || !T) { console.log('live-peer: PEER_URL/PEER_TOKEN not set, skipping'); process.exit(0); }
const tool = async (name, args={}) => {
  const r = await fetch(P + '/mcp', { method:'POST', headers:{ 'content-type':'application/json', authorization:'Bearer '+T }, body: JSON.stringify({ jsonrpc:'2.0', id:1, method:'tools/call', params:{ name, arguments:args } }) });
  const j = await r.json(); if (!j.result) throw new Error('no result: '+JSON.stringify(j).slice(0,200)); return j.result.content[0].text;
};
let pass=0, fail=0; const ok=(l,c,x='')=>{ console.log((c?'PASS ':'FAIL ')+l+(x?'  -> '+String(x).replace(/\n/g,' ').slice(0,120):'')); c?pass++:fail++; };
import { flat, HAAH } from './a2a-helpers.mjs';
const raw = await (await fetch(P + '/.well-known/agent-card.json')).json();
const card = flat(raw);
ok('peer serves an A2A v1.0 card with the HAAH extension', Array.isArray(raw.supportedInterfaces) && raw.capabilities && raw.capabilities.extensions.some(e=>e.uri===HAAH), raw.version);
ok('peer card answers with handle, url != rpc', card.handle==='testpeer@mazel' && card.url!==card.rpc && /^https:/.test(card.rpc), card.handle);
ok('peer has sailing-atlantic with a gloss', card.have.includes('sailing-atlantic') && card.glosses && /Atlantic/.test(card.glosses['sailing-atlantic']));
const home = await (await fetch(P + '/')).text();
ok('peer homepage exposes no token', !/token|\/mcp/i.test(home));
ok('unauthenticated inbox is refused', (await fetch(P + '/inbox')).status===401);
const tools = await (await fetch(P + '/mcp?token='+T, { method:'POST', headers:{'content-type':'application/json'}, body: JSON.stringify({jsonrpc:'2.0',id:1,method:'tools/list'}) })).json();
const names = tools.result.tools.map(t=>t.name);
ok('all 16 tools present', ['my_card','check_mailbox','fetch_peer_card','send_to_peer','update_card','add_known_card','list_known_cards','remove_known_card','find','propose_intro','respond_intro','list_threads','close_thread','reopen_thread','list_intros','clear_messages'].every(n=>names.includes(n)), names.length);
ok('every tool keyed on mazel', tools.result.tools.every(t=>/MAZEL:/.test(t.description)));
const known = JSON.parse(await tool('list_known_cards'));
ok('peer holds avery@mazel', known.some(c=>c.handle==='avery@mazel'));
const f = JSON.parse(await tool('find', { need_text:'someone who can build and run AI inside my own cloud', tags:['managed-ai-delivery'] }));
ok('find on the peer ranks avery with a why (✨ headline)', f.headline.startsWith('✨') && f.candidates[0] && f.candidates[0].handle==='avery@mazel' && /managed-ai-delivery/.test(f.candidates[0].why), f.candidates[0] && f.candidates[0].why);
ok('find returns one JSON shape with thread id', typeof f.thread_id==='string' && Array.isArray(f.candidates));
const nm = JSON.parse(await tool('find', { need_text:'a sushi chef in Osaka', tags:['sushi','osaka'] }));
ok('no match still JSON, empty candidates, headline explains', nm.candidates.length===0 && /Nothing in your cards fits/.test(nm.headline));
const mb = await tool('check_mailbox');
ok('mailbox reports 📭 or 📬', mb.startsWith('📭') || JSON.parse(mb).headline.startsWith('📬'));
console.log(`\nlive-peer: ${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
