# Git-connected deploy (prepared, not shipped)

**Decision needed from Ariel before this can ship: it requires `mazelai/mazel` to be public.**

Today a friend updates by running `npx create-mazel` again. That is one command and it works while the repo is private. Git-connected deploy would remove even that: their Worker watches the repo and redeploys itself whenever we push.

## What it would look like for a friend

One-time, about three minutes:

1. Cloudflare dashboard, Workers & Pages, their `mazel` Worker, Settings, Build, Connect to Git.
2. Authorize the Cloudflare GitHub app, pick `mazelai/mazel`, branch `main`.
3. Build settings: root directory `portal`, no build command, deploy command `npx wrangler deploy`.
4. Save. Cloudflare builds and deploys on every push to `main`.

Their vars and secret survive because `wrangler deploy` keeps existing bindings it is not told to change; the KV namespace id has to be present in `portal/wrangler.jsonc`, which is per-person, so each friend either edits that file in a fork or sets `kv_namespaces` through the dashboard once.

## What it costs

- **The repo must be public.** Cloudflare's GitHub app can read a private repo only if the *owner* of the Worker has access, so every friend would need to be a collaborator on a private `mazelai/mazel`. That does not scale past a handful and gives them commit visibility we may not want.
- **Everyone gets every commit.** The release rhythm in the spec is friends update at milestones, not every push. Git deploy inverts that unless we point them at a `friends` branch or tags only, which is more moving parts than `npx create-mazel`.
- **A bad push breaks every friend's portal at once.** Today a bad push breaks nobody until they choose to update.
- Per-person KV ids mean a shared `wrangler.jsonc` cannot be one file for everyone without a fork or a dashboard override.

## Recommendation

Do not ship this at crawl. `npx create-mazel` already gives one-command install and one-command update, keeps the release rhythm (friends update at milestones), and works with the repo private. Revisit at v0.2 public (§12.3 M5), when the repo flips public anyway, and then only for people who want auto-updates; pin them to a `friends` branch so the milestone rhythm survives.

**Flagged for Ariel:** flip the repo public early for this, or keep `npx create-mazel` as the update path until M5?
