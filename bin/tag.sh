#!/usr/bin/env bash
# Cut a release tag. The version is not typed twice: this takes it from the tag name, stamps it
# into the one place it lives, rebuilds what derives from it, and refuses to tag anything red.
#
#   bin/tag.sh v0.5.2-sec "one line for the tag message"
#   bin/tag.sh v0.5.2-sec --check     # say what it would do, change nothing
set -euo pipefail
cd "$(dirname "$0")/.."

TAG="${1:?usage: bin/tag.sh vX.Y.Z-name [message|--check]}"
ARG="${2:-}"
VERSION="$(echo "$TAG" | sed -E 's/^v([0-9]+\.[0-9]+\.[0-9]+).*$/\1/')"
[ "$VERSION" != "$TAG" ] || { echo "✗ $TAG does not start with vX.Y.Z"; exit 1; }

CURRENT="$(grep -oE 'const PORTAL_VERSION = "[^"]+"' portal/src/index.js | sed -E 's/.*"([^"]+)".*/\1/')"
# A tag without a changelog entry is a release nobody can read about. Refuse it.
grep -q "^## $TAG" CHANGELOG.md || { echo "✗ CHANGELOG.md has no '## $TAG' entry; write it first"; exit 1; }
echo "  tag $TAG wants $VERSION; the tree says $CURRENT"

if [ "$CURRENT" != "$VERSION" ]; then
  if [ "$ARG" = "--check" ]; then echo "✗ they disagree. Run without --check to stamp $VERSION."; exit 1; fi
  echo "  stamping $VERSION into PORTAL_VERSION, both package.json files and VERSION"
  perl -pi -e "s/const PORTAL_VERSION = \"[^\"]+\"/const PORTAL_VERSION = \"$VERSION\"/" portal/src/index.js
  perl -pi -e "s/\"version\": \"[^\"]+\"/\"version\": \"$VERSION\"/" portal/package.json portal/create-mazel/package.json
  echo "$VERSION" > VERSION
fi

# The spec states the live version in two places; they are derived too, so they cannot go stale.
# SKIP_SPEC=1 leaves the spec alone (when the master lives elsewhere and the two lines are updated by hand).
if [ -f MAZEL-SPEC.md ] && [ -z "${SKIP_SPEC:-}" ]; then
  perl -pi -e "s/^### 7\.2 The portal today \(\`v[0-9.]+\`\)/### 7.2 The portal today (\`v$VERSION\`)/" MAZEL-SPEC.md
  perl -pi -e "s/\(Ariel's portal, [0-9.]+, pulse cron set\)/(Ariel's portal, $VERSION, pulse cron set)/" MAZEL-SPEC.md
fi

# Everything that derives from the version, rebuilt from it.
(cd relay && node build.mjs >/dev/null)
cp portal/src/index.js portal/create-mazel/worker/index.js
cp relay/src/index.js portal/create-mazel/worker/relay.js
(cd portal/test && node write-fixtures.mjs >/dev/null)

if [ "$ARG" = "--check" ]; then git diff --stat; echo "  (check only, nothing committed)"; exit 0; fi

# Stage the regenerated artefacts before testing. run.sh checks that the committed relay matches a
# fresh build by diffing against the index, and we have just rebuilt it here; staging keeps that
# check meaningful in CI (where nothing is staged) without failing on our own rebuild.
git add -A

echo "  running every suite"
(cd portal/test && ./run.sh >/tmp/mazel-tag-suites.log 2>&1) || { echo "✗ suites are red, not tagging:"; tail -20 /tmp/mazel-tag-suites.log; exit 1; }
cargo test --workspace -q >/dev/null 2>&1 || { echo "✗ rust is red, not tagging"; exit 1; }
echo "  all suites green"

if ! git diff --quiet || ! git diff --cached --quiet; then
  git add -A
  git commit -q -m "version: $VERSION for $TAG

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
  git push -q origin main
fi

git tag -a "$TAG" -m "${ARG:-$TAG}"
git push -q origin "$TAG"
echo "  ✓ $TAG pushed at $VERSION"
