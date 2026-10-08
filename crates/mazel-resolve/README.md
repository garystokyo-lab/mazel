# mazel-resolve

DNS-shaped handle resolution stub. `@kai` / `kai@mazel` → Agent Card URLs from a static map and/or a BIND-lite zone fixture.

TXT: `mazel-card=<url>` optional `mazel-haah=1`. No live DNS.

```bash
mix dns_demo
cargo run -q -p mazel-resolve --bin dns_demo
```
