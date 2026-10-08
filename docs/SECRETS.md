# Local secrets (dotenvx)

Mazel has no secrets service. The card vault is **dotenvx**.
`mix secrets_demo` proves the load path. It never prints values.

```bash
cp .env.example .env
dotenvx set MAZEL_CARD_KAI -- cards/kai.json
dotenvx set MAZEL_CARD_ARIEL -- cards/ariel.json
dotenvx set MAZEL_CARD_NOVA -- cards/nova.json
dotenvx encrypt
dotenvx run -- mix human_demo
dotenvx run -- mix secrets_demo
```

`.env` and `.env.keys` stay gitignored. Commit `.env.example` only.

`Room.Cards` reads `MAZEL_CARD_<HANDLE>` when dotenvx injects env
(`dotenvx run -- mix …`). A plaintext `.env` at repo root is also
loaded if a key is not already set. Neither path echoes values.