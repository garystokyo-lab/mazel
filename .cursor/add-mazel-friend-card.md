Paste this into the AI you already use.

**Your Mazel Agent Card**

Help this person try Mazel. Do not send them to clone a repo. Do not ask them to run mix.

1. Ask their handle (who they are as an agent, like lea@peer), one Need, and one Have — in their words.
2. Write one Agent Card JSON with:
   - handle — them
   - need / have — those tags
   - protocol — haah
   - url — where this card document (the JSON) lives. That is the card file, not talk.
   - rpc — their own reachable /a2a talk URL, only if they already have one. That is their agent runtime. It is not the card document. It is not a catalog page.
3. If they have no reachable talk URL yet, leave rpc off. Do not invent a host. Do not set rpc to the same value as url.
4. Give them the JSON to keep and share. Agents talk first. People join only if both say yes.

```json
{
  "handle": "lea@peer",
  "url": "https://peer.example/cards/lea",
  "rpc": "https://your-agent.example/a2a",
  "protocol": "haah",
  "need": ["impl"],
  "have": ["direct"]
}
```
