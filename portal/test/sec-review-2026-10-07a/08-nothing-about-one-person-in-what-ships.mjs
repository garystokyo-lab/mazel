// Item 7: nothing specific to a real person in shipped code, tool descriptions, install pages,
// fixtures, or the files the friend zip carries (build-friend-zip.sh: MAZEL.md, FRIEND-README.md,
// CHANGELOG.md, screenshots).
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
let pass = 0, fail = 0;
const ok = (l, c, x = '') => { console.log((c ? 'PASS ' : 'FAIL ') + l + (x ? '  -> ' + String(x).slice(0, 200) : '')); c ? pass++ : fail++; };
const ROOT = join(import.meta.dirname, '../../..');
const NAMES = /\b(Ariel|Jalali|Paragon|Sandler|paragoncto)\b/g;
const walk = (d) => readdirSync(d).flatMap((f) => { const p = join(d, f); return statSync(p).isDirectory() ? (f === 'node_modules' ? [] : walk(p)) : [p]; });
const shipped = [
  ...walk(join(ROOT, 'portal/src')), ...walk(join(ROOT, 'portal/create-mazel')).filter((p) => /\.(js|json|md)$/.test(p)),
  ...walk(join(ROOT, 'site')), ...walk(join(ROOT, 'portal/test/fixtures')), join(ROOT, 'portal/MAZEL.md'), join(ROOT, 'portal/FRIEND-README.md'), join(ROOT, 'portal/PUBLIC-README.md'), join(ROOT, 'portal/README.md'),
];
for (const f of shipped) { const hits = (readFileSync(f, 'utf8').match(NAMES) || []); ok(`no real name in ${f.replace(ROOT + '/', '')}`, hits.length === 0, [...new Set(hits)].join(',')); }
// The friend zip also carries CHANGELOG.md.
const cl = readFileSync(join(ROOT, 'CHANGELOG.md'), 'utf8');
const hits = cl.match(NAMES) || [];
ok('LOW: CHANGELOG.md, which build-friend-zip.sh ships to every friend, names nobody real', hits.length === 0, `${hits.length} mentions; e.g. "${(cl.match(/[^\n]*knows Dana[^\n]*/) || [''])[0].trim().slice(0, 120)}"`);
// Tool descriptions, as the agent sees them.
const src = readFileSync(join(ROOT, 'portal/src/index.js'), 'utf8');
ok('no decision in the worker is attributed to a named person', !/\((Ariel|[A-Z][a-z]+), 2026-/.test(src), (src.match(/\((Ariel|[A-Z][a-z]+), 2026-[^)]*\)/) || [''])[0]);
console.log(`${pass} passed, ${fail} failed`); process.exit(fail ? 1 : 0);
