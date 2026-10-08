# The permanent test peer (5 minutes)

Mazel's loop needs two portals, and since Fly the relay too. Cloudflare blocks a Worker from fetching any workers.dev address on its own account (error 1042), so the peer must live on **its own free Cloudflare account**: not Ariel's (it must reach his portal) and not the company account (it must reach the relay, which lives there). This is also the timing test for `npx create-mazel`.

Nothing here costs money. Both accounts stay on the free plan.

## 1. A second free Cloudflare account (~2 min)

Sign up at https://dash.cloudflare.com/sign-up with an email address that is **not** the one on your main account. A plus-address works if your mail provider supports it (`you+mazelpeer@…`), otherwise any second address you control.

Verify the email, then open Workers & Pages once. If it asks you to choose a workers.dev subdomain, pick something neutral like `mazel-peer`. The peer's portal will end up at `mazel.<that subdomain>.workers.dev`.

## 2. A token for that account (~1 min)

Signed in **as the new account**: https://dash.cloudflare.com/profile/api-tokens → Create Token → template **Edit Cloudflare Workers** → Continue to summary → Create Token → copy it.

(Full walkthrough, including the least-privilege variant: `docs/CLOUDFLARE-TOKEN.md`.)

## 3. Install the peer (~2 min)

In a terminal:

```
npx create-mazel --name mazel
```

Paste that token when it asks, then give it:

| Prompt | Answer |
|---|---|
| handle | `testpeer@mazel` |
| persona | `A test portal for Mazel's own checks. Not a real person. Has sailed across the Atlantic twice.` |
| need | `managed-ai-delivery` |
| have | `sailing-atlantic` |

Keep the key it prints; CI needs it. When it finishes, the card is live at `https://mazel.<subdomain>.workers.dev/card`.

**Time it.** From opening the sign-up page to that card answering is the number worth writing down.

## 4. Give the have a gloss

One line, so matching works on meaning rather than exact tags. Ask your AI (or curl it):

```
curl -s -X POST https://mazel.<subdomain>.workers.dev/card \
  -H "authorization: Bearer <the key>" -H 'content-type: application/json' \
  -d '{"gloss_tag":"sailing-atlantic","gloss_text":"has sailed across the Atlantic twice, happy to advise on crossings","confirmed":true}'
```

## 5. Hand the engineer two things

- the peer's card URL
- the peer's key

Both go into CI as repository secrets (`PEER_URL`, `PEER_TOKEN`), and the live suite runs against it on every push.

## Keeping it honest

- The peer is **not a person**. Its persona says so, so nobody mistakes it for a real match if its card ever travels.
- It holds only Ariel's card, and Ariel holds only its card.
- It runs the same portal code as everyone else; that is the point. Update it the same way: `npx create-mazel` on that account.
- If the account is ever lost, nothing breaks except the tests: delete the two known cards and repeat this page.
