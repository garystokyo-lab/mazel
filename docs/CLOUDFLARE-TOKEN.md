# Minting the Cloudflare API token for `npx create-mazel`

The installer needs a token so it can open (or update) your portal without you touching a dashboard. The token stays on your machine: the installer sends it only to Cloudflare's own API. Nobody else ever needs it — not Ariel, not your AI, not a chat window.

## The fast way (recommended, ~90 seconds)

1. Open **https://dash.cloudflare.com/profile/api-tokens**
2. Click **Create Token**.
3. Find the template **"Edit Cloudflare Workers"** and click **Use template**.
4. Leave the permissions as the template sets them. Two boxes are worth setting:
   - **Account Resources:** Include → the account you want the portal on (if you only have one, it is already right).
   - **Zone Resources:** if it insists on a zone and you own no domains, choose Include → All zones. Nothing here touches DNS unless you later attach a custom domain.
5. *(Optional, recommended)* **TTL:** set an end date a week out. You only need the token while installing; a short life means a leaked token dies on its own.
6. **Continue to summary** → **Create Token**.
7. Copy it. It is shown **once**. Paste it into the installer when it asks — not into chat, not into a document you share.

Then run:

```
npx create-mazel
```

## The minimal way (least privilege, ~3 minutes)

If you would rather grant only what the installer actually calls, use **Create Custom Token** instead of the template and add exactly these three **Account** permissions:

| Permission | Level | Why the installer needs it |
|---|---|---|
| Workers Scripts | Edit | Create/update the Worker, and turn on its workers.dev address |
| Workers KV Storage | Edit | Create your mailbox namespace and bind it |
| Account Settings | Read | List your accounts so it can pick the right one |

No Zone permissions are needed for a workers.dev portal. The template adds R2 and Workers Routes, which the installer never calls; the custom token above is the smaller blast radius.

## After you are set up

- You do **not** need to keep the token. Deleting it does not touch your portal; it only means the next `npx create-mazel` (an update) will ask for a fresh one.
- To revoke: same page, the token's **⋯** menu → **Delete**.
- If a token ever leaks, delete it there. That is the whole remedy — a Cloudflare token cannot be used to read your Mazel mailbox (that needs your `INBOX_TOKEN`, which is a separate secret).

## What the installer does with it

Six calls, all to `api.cloudflare.com`: list accounts; read your workers.dev subdomain; list/create the KV namespace; read whether the Worker already exists; upload the Worker with its bindings; enable its workers.dev address. It writes nothing to disk and prints the token nowhere.
