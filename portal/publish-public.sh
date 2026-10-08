#!/usr/bin/env bash
# Mirror the public half of this repo into mazelai/portal: what the Deploy to Cloudflare button
# forks, what `npx create-mazel` is published from, and what anyone can read and test.
# The spec, the cards and the recovered tree stay in the private repo and never come here.
#
#   ./portal/publish-public.sh [checkout-dir] ["commit message"]
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
PUB="${1:-$HOME/mazel-work/portal-public}"

[ -d "$PUB/.git" ] || git clone https://github.com/mazelai/portal.git "$PUB"
git -C "$PUB" pull --ff-only origin main >/dev/null 2>&1 || true

# Same layout as the private repo, so every relative import and the test runner keep working.
rm -rf "$PUB/portal" "$PUB/relay"
mkdir -p "$PUB/portal"
cp -R "$SRC/portal/src" "$SRC/portal/test" "$SRC/portal/create-mazel" "$SRC/portal/bin" "$PUB/portal/"
cp "$SRC/portal/wrangler.json" "$SRC/portal/package.json" "$PUB/portal/"
cp -R "$SRC/relay" "$PUB/relay"
cp "$SRC/LICENSE" "$PUB/LICENSE"
cp "$SRC/portal/PUBLIC-README.md" "$PUB/README.md"

# The live-peer suite talks to a private test portal, so it does not travel.
rm -f "$PUB/portal/test/live-peer.mjs"
sed -i.bak 's/ live-peer;/;/' "$PUB/portal/test/run.sh" && rm -f "$PUB/portal/test/run.sh.bak"
rm -rf "$PUB/portal/create-mazel/node_modules" "$PUB/portal/test/node_modules"
# Review folders are working notes, not product: they quote one person's portal and name them.
rm -rf "$PUB"/portal/test/sec-review-*
# Nothing in the public mirror names a real person. The mirror is the thing strangers read and fork.
if grep -rilE "ariel|paragon|jalali|workday|betterbeing" "$PUB" --exclude-dir=.git >/dev/null 2>&1; then
  echo "refusing to publish: something in the mirror names a real person:" >&2
  grep -rilE "ariel|paragon|jalali|workday|betterbeing" "$PUB" --exclude-dir=.git | head -5 >&2
  exit 1
fi

# Deploy to Cloudflare looks for wrangler.json at the root: same file, main pointed one level in.
node -e '
  const fs = require("fs");
  const c = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
  c.main = "portal/" + c.main;
  // The guard lives one level in too, and it is the thing standing between a friend and an
  // emptied portal, so the root copy has to point at it and not silently lose it.
  if (c.build && c.build.command) c.build.command = c.build.command.replace("bin/", "portal/bin/");
  fs.writeFileSync(process.argv[2], JSON.stringify(c, null, 2) + "\n");
' "$SRC/portal/wrangler.json" "$PUB/wrangler.json"

cd "$PUB"
git add -A
if git diff --cached --quiet; then echo "public mirror already current"; exit 0; fi
git commit -q -m "${2:-sync from the working repo}"
git push -q origin main
echo "pushed: https://github.com/mazelai/portal"
