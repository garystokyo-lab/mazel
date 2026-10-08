#!/usr/bin/env bash
# What each account spent, per day, for the last week. Lock 13's other half: the budget test says
# what an operation costs; this says what the month is actually doing.
#
#   bin/usage.sh                 every account that has a token file
#   bin/usage.sh personal        one of them
#
# Tokens: one Analytics:Read token per account, in its own file, mode 600, never in a repo and never
# in chat. Default location ~/.mazel/tokens, overridable with MAZEL_TOKEN_DIR. Each file holds two
# lines, the account id and the token:
#
#   ~/.mazel/tokens/personal     8f2de694...   (ariel.jalali@gmail.com, Ariel's portal)
#   ~/.mazel/tokens/test         1c4d289d...   (mazel@mazel.ai, the test peer, Workers Free on purpose)
#   ~/.mazel/tokens/company      ........      (ariel@mazel.ai, the relay)
#
# Make one at dash.cloudflare.com -> Manage Account -> API Tokens -> Create Token -> Custom token,
# with Account Analytics:Read on that account alone and nothing else.
set -euo pipefail
DIR="${MAZEL_TOKEN_DIR:-$HOME/.mazel/tokens}"
SINCE="$(date -u -v-7d +%Y-%m-%dT00:00:00Z 2>/dev/null || date -u -d '7 days ago' +%Y-%m-%dT00:00:00Z)"

one() {
  local name="$1" file="$DIR/$1"
  [ -f "$file" ] || { echo "  no token file for $name ($file)"; return 0; }
  local acct token
  acct="$(sed -n 1p "$file" | tr -d '[:space:]')"
  token="$(sed -n 2p "$file" | tr -d '[:space:]')"
  [ -n "$acct" ] && [ -n "$token" ] || { echo "  $name: the token file wants two lines, account id then token"; return 0; }
  echo "== $name  ($acct)"
  local q
  q=$(cat <<JSON
{"query":"query { viewer { accounts(filter: {accountTag: \\"$acct\\"}) {
  kv: kvOperationsAdaptiveGroups(limit: 300, filter: {datetime_geq: \\"$SINCE\\"}, orderBy: [date_ASC]) { sum { requests } dimensions { date actionType } }
  w: workersInvocationsAdaptive(limit: 300, filter: {datetime_geq: \\"$SINCE\\"}, orderBy: [date_ASC]) { sum { requests errors } dimensions { date scriptName } }
} } }"}
JSON
)
  curl -s -X POST https://api.cloudflare.com/client/v4/graphql \
    -H "Authorization: Bearer $token" -H 'content-type: application/json' \
    --data "$(echo "$q" | tr -d '\n')" | python3 -c '
import sys, json, collections
d = json.load(sys.stdin)
if d.get("errors"): print("  refused:", d["errors"][0].get("message", "?")); print("  (the token needs Account Analytics:Read on this account)"); raise SystemExit
accts = (d.get("data") or {}).get("viewer", {}).get("accounts") or []
if not accts: print("  no data for that account id"); raise SystemExit
a = accts[0]
kv = collections.defaultdict(dict)
for row in a.get("kv") or []: kv[row["dimensions"]["date"]][row["dimensions"]["actionType"]] = row["sum"]["requests"]
wr = collections.defaultdict(int)
for row in a.get("w") or []: wr[row["dimensions"]["date"]] += row["sum"]["requests"]
if not kv and not wr: print("  nothing in the window")
print("  date         requests   kv write  kv read  kv list  kv delete   note")
for day in sorted(set(list(kv) + list(wr))):
    k = kv.get(day, {})
    wtes = k.get("write", 0)
    note = "OVER FREE (1000/day)" if wtes >= 1000 else ("near the free ceiling" if wtes >= 800 else "")
    print(f"  {day}  {wr.get(day,0):9d}  {wtes:9d} {k.get(\"read\",0):8d} {k.get(\"list\",0):8d} {k.get(\"delete\",0):10d}   {note}")
'
}

if [ $# -gt 0 ]; then one "$1"; else for f in "$DIR"/*; do [ -f "$f" ] && one "$(basename "$f")"; done; fi
