#!/usr/bin/env bash
# Build dist/mazel-for-friends.zip. Refuses if any suite is red: a red build never ships to a friend.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/portal/test/run.sh"
cd "$ROOT/portal" && python3 build-friend-file.py >/dev/null
mkdir -p "$ROOT/dist" && STAGE="$(mktemp -d)"
cp "$ROOT/portal/MAZEL.md" "$STAGE/MAZEL.md"
cp "$ROOT/portal/FRIEND-README.md" "$STAGE/README.md"
cp "$ROOT/CHANGELOG.md" "$STAGE/CHANGELOG.md"
[ -d "$ROOT/portal/screenshots" ] && cp "$ROOT"/portal/screenshots/*.png "$STAGE/" || true
# Nothing that ships names a real person. A name in here would go to every friend who opens the zip,
# so the build refuses rather than warns.
if grep -rinE "ariel|paragon|jalali|workday|betterbeing" "$STAGE" >/dev/null 2>&1; then
  echo "refusing to build: something in the zip names a real person:" >&2
  grep -rinE "ariel|paragon|jalali|workday|betterbeing" "$STAGE" | head -5 >&2
  rm -rf "$STAGE"; exit 1
fi
rm -f "$ROOT/dist/mazel-for-friends.zip"
(cd "$STAGE" && zip -q -X -r "$ROOT/dist/mazel-for-friends.zip" .)
rm -rf "$STAGE"
echo "built dist/mazel-for-friends.zip:"; unzip -l "$ROOT/dist/mazel-for-friends.zip" | tail -n +4 | awk 'NF==4{print "  "$4}'
