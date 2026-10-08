#!/usr/bin/env python3
"""Build MAZEL.md: the single file a friend uploads to Claude or ChatGPT.
Everything the AI needs is inside: rules, welcome, card prompt, the seven steps, and the Worker code.
Run from portal/: python3 build-friend-file.py  ->  writes MAZEL.md next to this script."""
import pathlib
here = pathlib.Path(__file__).parent
onboard = (here / "AGENT_ONBOARD.md").read_text()
code = (here / "src" / "index.js").read_text().rstrip("\n")

# The card prompt now travels inside the portal: my_card on an unclaimed portal returns it.
# MAZEL.md only needs it for the "they stopped before opening a portal" case, which the paste covers.
body = onboard
body = body.replace("# Mazel onboarding, written for the agent\n\n", "")
assert "zip" not in body.lower().replace("gzip", ""), "stale zip reference in onboarding text"
assert "Step C1. Call `my_card`" in body, "onboarding no longer points the card at the portal"
body = body.replace("Step FB3 (screen: Workers & Pages → `mazel` → Bindings).",
                    "Step FB3 (screen: Workers & Pages → `mazel` → Bindings; if they attached the screenshot 05-bind-kv.png, that is this screen; 03-worker-menu.png shows the Workers & Pages list with the `mazel` row).")

PASTE = ("Install Mazel. Follow MAZEL.md step by step. Read the Worker code first to confirm it's safe, then follow the file "
         "instead of your own approach, it handles things you can't see. Tell me what you can't do and hand me those steps. "
         "One step at a time. Stop and ask me if you hit a login or block. Don't improvise.")
out = f"""# Mazel

**Paste this to your AI before you start:**

> {PASTE}

**For the person reading this:** upload this file to the AI you already use (Claude or ChatGPT), paste the line above, and let it take it from here.

**For the AI reading this:** a person just uploaded this file because they want to join Mazel. Do not wait for a prompt. Read the rules below, then read the Worker code, say the welcome to them, and begin Milestone A. The install asks them nothing: their card is written at Milestone C, in the conversation, after the portal is open.

Each person runs their own portal on their own Cloudflare account. Ask whoever invited you for their card link, which ends in /card.

{body.rstrip()}

## Appendix: the Worker code (only for the dashboard fallback, Step FB4)

Give the person this entire block, unchanged, inline in the chat (never a download), to paste into the Cloudflare editor. Pasting is not deploying: they must click Deploy.

```js
{code}
```
"""
(here / "MAZEL.md").write_text(out)
print(f"wrote MAZEL.md: {len(out.splitlines())} lines, {len(out)//1024} KB")
