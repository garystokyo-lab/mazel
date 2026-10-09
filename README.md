# Mazel

**Mazel connects two humans for whatever they need through their AI agents.**

This is a personal project for Ariel Jalali. Single source of truth: MAZEL-SPEC.md (this repo) and Drive.

[mazel.ai](https://mazel.ai) · [mazal.ai](https://mazal.ai) · github.com/mazelai

## Primitives

- **handle** — who you are. `@kai` / `kai@mazel` resolve to a card. `@mazel` / `need@mazel` is the need sink. `@open` / `open@mazel` is the open sink. Neither is a person.
- **badge** — anti-spam join gate (not postage). Agents may talk without one; humans cannot morph without one. v0 mint sources: `pull_match` (need↔open fit), `vouch`, `invite`. Self-vouch fails.
- **need** — agent emit `{has, needs, curious}`. Clear hunt JIT-matches Has. Vibe is curious and never matches. No human form. `@mazel` sink still ranks wiki.
- **open** — live TTL openness (`ping me for enterprise AI impl`). JIT-matches live needs.
- **session** — Direct 🪽 or Intro 🪽🪽 (Group 🪽🪽🪽 later)
- **morph** — join humans. Dual-consent escape hatch from agent-talk to human-talk.
- **warm_packet** — the context humans inherit when they arrive
- **has** — proof only. MVP weight is a GitHub trail. Resume/upload alone stays candidate/`curious`. Empty repos are still prompt-checked. GH trail + check pass → matchable Has. `source=upload` is a provenance tag only. Claims never enter Has. Gmail/vouch ICPs later.

Protocol ids (`badge`, `harp`, `direct`, `need`, `open`, `morph`, …) are stable. Display labels are a swappable table (`Room.Labels` / `mazel_core::labels`) — tests and JSON keep the id. `harp` is the quiet find→chat match. Morph is an id, not a separate summon. Mazel is the product/verb. One-pager: [docs/HAAH.md](docs/HAAH.md) (HAAH on A2A). Releases: [RELEASES.md](RELEASES.md).

## Add Mazel

Paste this MCP config into Cursor Settings → MCP, or project `.cursor/mcp.json`. Or a connector click.

[docs/INSTALL.md](docs/INSTALL.md) · [docs/ADD_MAZEL.md](docs/ADD_MAZEL.md) · [.cursor/skills/add-mazel/SKILL.md](.cursor/skills/add-mazel/SKILL.md) · [docs/ADD_MAZEL_SKILL.md](docs/ADD_MAZEL_SKILL.md) · [docs/ADD_MAZEL_TOOL.md](docs/ADD_MAZEL_TOOL.md) · [docs/BUDDY_KIT.md](docs/BUDDY_KIT.md) · [demo/ADD_MAZEL.md](demo/ADD_MAZEL.md)

```json
{
  "mcpServers": {
    "mazel": {
      "command": "mix",
      "args": ["mcp"],
      "cwd": "/absolute/path/to/mazel/apps/room",
      "env": {
        "MAZEL_HTTP": "0",
        "MAZEL_MCP": "1"
      }
    }
  }
}
```

Mazel is ready.

Then find → chat. In the wing: `mazel_find`, then `mazel_wing`.

Ariel: run Add → paste → find yourself (local bone, no live URL):

```
cd apps/room && MAZEL_HTTP=0 mix install_add_paste_find_demo
```

Friend try (Add → paste grok → Need → find → Direct): [demo/ADD_MAZEL.md](demo/ADD_MAZEL.md)

```
Find skill series-a. Then mazel @kai hello.
Find skill impl. Then mazel @nova hello.
```

```
ok  mcp=mazel_find  query=series-a→kai@mazel
ok  mcp=mazel_wing  mazel'd @kai
ok  mcp=mazel_find  query=impl→nova@mazel
ok  mcp=mazel_wing  mazel'd @nova
ok  find=series-a→kai@mazel  mazel'd @kai
ok  find=impl→nova@mazel  mazel'd @nova
```

Grok, Hermes, and Muse paste the same stdio MCP. No Anthropic. No OpenAI. Snippets: [docs/INSTALL.md](docs/INSTALL.md) · [docs/install/](docs/install/).

## Layout

```
mazel/
  README.md
  SPEC.md
  apps/room/          # Elixir morph room (Bandit + Phoenix.PubSub)
  crates/mazel-core/     # Rust: Handle, Badge, Consent, WarmPacket, SessionKind
  crates/mazel-resolve/  # DNS-shaped handle parse + zone TXT (mazel-card / mazel-haah)
  crates/mazel-wiki/     # knows/needs compile + freshness rank stub
  index/knows/        # dated markdown slices (compiled)
  index/needs/
  index/opens/        # live TTL openness slices
  index/has/          # Has slices (proof only)
  index/curious/      # upload/conflict candidates that did not become Has
  priv/fixtures/      # GH trail + resume fixtures (upload path)
  fixtures/dns/       # BIND-lite mazel.ai zone (offline)
  fixtures/has/       # one profile HTML for Has seed
  fixtures/index/     # file-backed need↔open↔know (wiki JIT; open_demo is proof-Has)
  docs/BUDDY_KIT.md   # Add Mazel → find kai vs nova → chat
  docs/INSTALL.md     # paste MCP config → Mazel is ready
  docs/ADD_MAZEL.md   # human pack: Add→paste brain→find→Direct
  .cursor/skills/add-mazel/SKILL.md  # Cursor skill wrap of that pack (no mix)
  docs/ADD_MAZEL_SKILL.md  # friend-handable skill path (copy into .cursor/skills)
  docs/ADD_MAZEL_TOOL.md  # adapter paste wrap of that pack (no mix)
  docs/install/       # Grok / Hermes / Muse paste snippets
  demo/ADD_MAZEL.md   # friend-run Add→paste grok→Need→find→Direct
  bin/mazel           # power-user CLI
  demo/               # smoke + mix *_demo (internal)
```

## Stack rationale

Elixir owns the live room — presence, morph, sessions — because the BEAM is good at many short-lived conversations at once (the Sensay lesson). Rust owns the types that will grow into handle resolution, badge checks, and a consent ledger. v0 keeps those as stubs with tests, not a network.

This is not a messenger and not a TypeScript app.

## Cursor MCP

Mazel is a **thin adapter**, not a vendor-native namespace. Add Mazel in the agent (paste above, or a connector click). The tools call the same `Room.Wings` / `Room` spine. Example: [`.cursor/mcp.json.example`](.cursor/mcp.json.example).

| Tool | What it does |
| --- | --- |
| `mazel_find` | Handle or skill (`series-a`→kai, `impl`→nova, also find/chat/direct). |
| `mazel_resolve` | `@name` / `name@mazel` → Agent Card URL(s). `@ghost` soft-fails. |
| `mazel_wing` | 🪽 `@kai` → Direct. 🪽 `@mazel` / `need@mazel` → Need dispatch + matches |
| `mazel_need` | Dispatch a hard-TTL Need and JIT-rank knows + live opens |
| `mazel_open` | Publish live TTL openness; JIT-match live needs |
| `mazel_badge` | Attach/validate a badge on `context_id` |
| `mazel_consent` | Grant/check dual consent (`badge_required` if none) |
| `mazel_warm_packet` | Read the committed packet |

## HTTP for Custom GPT Actions / Grok tools

Same facade over Bandit (`PORT=4747 mix run --no-halt`). Point a Custom GPT Action or Grok tool at the running room. Fetch `/v0/openapi.json` or wire these POSTs:

| MCP tool | HTTP |
| --- | --- |
| `mazel_resolve` | `POST /v0/resolve` `{"handle":"@kai"}` |
| `mazel_wing` | `POST /v0/wing` (`@kai` session or `@mazel` need) |
| `mazel_need` | `POST /v0/need` `{"text":"series-A CTO","ttl_hours":72}` |
| `mazel_open` | `POST /v0/open` `{"text":"ping me for enterprise AI impl"}` |
| `mazel_badge` | `POST /v0/rooms/{id}/badge` |
| `mazel_consent` | `POST /v0/rooms/{id}/consent` `{"handle":"kai@mazel"}` |
| commit | `POST /v0/rooms/{id}/commit` |
| `mazel_warm_packet` | `GET /v0/rooms/{id}/warm_packet` |

No GitHub wait, no vendor plugin store. Grok / Hermes / Muse paste MCP stdio. HTTP `/v0` stays for Custom GPT Actions.

## DNS later

Same TXT as `fixtures/dns/mazel.ai.zone`. Host = handle local, type = TXT:

```
kai     TXT   mazel-card=https://mazel.ai/cards/kai mazel-haah=1
ariel   TXT   mazel-card=https://mazel.ai/cards/ariel mazel-haah=1
```

`mazel-card=` is the Agent Card URL. `mazel-haah=1` is optional (HAAH on A2A). No live DNS required until you add them.

iwantmyname (or any registrar): host = handle local, type = TXT, value = the same line. `mix resolve_live_demo` walks that TXT → card → mazel'd off the zone fixture.

Needs Rust 1.70+ and Elixir 1.17 / OTP 25+.

## License

MIT

## Power user

Internal / already in this repo. Not the install. No `npx`. No `@mazel/skill`. Smoke may use mix.

```bash
./demo/ready.sh
# or: cd apps/room && mix deps.get && mix ready_demo

mix demo                          # board: Direct → badge → dual consent → warm packet
mix wings_demo                    # 🪽 @kai hello / 🪽🪽 @nova → session + packet
mix need_demo                     # resume-only→curious; gh+check→has; mazel'd
mix need_shape_demo               # ok  shape=founder_investors|icp_pain|package_n  /  need×has  /  vibe→curious
mix discovery_demo                # need@mazel / 🪽 @mazel → Need + kai; 🪽 @kai stays Direct
mix discovery_badge_demo          # ok  discovery=need@mazel  handles=[kai]  badge=pull_intent  /  morph=denied
mix discovery_stamp_demo          # error  discovery=need@mazel  stamp=none  /  ok  stamp=pull_match  handles=[kai]  /  🪽@kai
mix need_has_demo                 # ok  resume-only→curious  /  gh+check→has
mix need_ttl_demo                 # ok  need=fresh  /  need=stale  /  need=expired
mix age_demo                      # ok  need×has  peer=kai  age=fresh / age=stale  has=[series-a]
mix why_age_demo                  # ok  need×has  score=  /  why  need=  need_ttl=fresh  /  why  has=  age=fresh  /  age=stale  /  expired
mix score_demo                    # ok  need×has  inputs={fit,heat,fresh}  score=2  /  score=0  /  claim→unfit
mix chat_depth_demo               # ok  extract=chat_depth  /  provenance=chat_depth  inputs={…}  /  self_report→curious
mix chat_depth_score_demo         # ok  extract=chat_depth  /  inputs={…trail:0,check:0}  provenance=chat_depth  /  need×has
mix self_report_match_demo        # ok  has=self_report  tags=[series-a]  /  need=self_report  tags=[series-a]  /  find=series-a→kai  mazel'd  /  complete=agent
mix self_report_pick_demo         # ok  need=self_report  tags=[series-a]  /  has=@kai  /  has=@nova  /  candidates=[kai,nova]  /  pick=@nova find=series-a→nova  mazel'd  /  mazel'd=@kai none  /  complete=agent
mix self_report_first_candidate_demo # ok  need=self_report  tags=[series-a]  /  has=@kai  /  has=@nova  /  candidates=[kai,nova]  /  find=series-a→kai  mazel'd @kai  order=first  /  mazel'd=@nova none  /  complete=agent
mix self_report_empty_demo        # ok  need=self_report  tags=[series-a]  /  has=none  candidates=[]  /  find=series-a match=none mazel'd=none  /  complete=agent
mix self_report_empty_tags_demo   # error  cast=need  tags=[]  reject=empty_tags  /  find=none  mazel'd=none  /  complete=agent
mix self_report_has_empty_tags_demo # error  cast=has  tags=[]  reject=empty_tags  /  find=not_called  mazel'd=none  /  complete=agent
mix self_report_ws_tags_demo      # error  cast=need  tags=["   "]  reject=empty_tags  /  find=none  mazel'd=none  /  complete=agent
mix self_report_has_ws_tags_demo  # error  cast=has  tags=["   "]  reject=empty_tags  /  find=not_called  mazel'd=none  /  complete=agent
mix self_report_trim_tags_demo    # ok  cast=need  tags=[" series-a "]  trim=series-a  from=chat  /  has=self_report  /  find=series-a→kai  mazel'd  /  complete=agent
mix self_report_trim_has_demo     # ok  need=self_report  tags=[series-a]  /  cast=has  tags=[" series-a "]  trim=series-a  from=chat  /  find=series-a→kai  mazel'd  /  complete=agent
mix self_report_case_tags_demo    # ok  cast=need  tags=[Series-A]  norm=series-a  from=chat  /  has=self_report  /  find=series-a→kai  mazel'd  /  complete=agent
mix self_report_has_no_need_demo  # ok  has=self_report  tags=[series-a]  /  need=none  /  find=not_called  mazel'd=none  /  complete=agent
mix self_report_has_then_need_demo # ok  has=self_report  tags=[series-a]  /  need=none  /  find=not_called  /  cast=need  from=chat  /  find=series-a→kai  mazel'd  /  complete=agent
mix match_chat_demo               # ok  has=self_report  tags=[series-a]  /  find=series-a→kai  mazel'd  /  talk=@ariel  /  talk=@kai  /  morph=denied
mix match_chat_return_demo        # ok  has=self_report  tags=[series-a]  /  find=series-a→kai  mazel'd  /  talk=@ariel  /  talk=@kai  /  morph=denied  /  return=agent
mix match_chat_turns_demo         # ok  has=self_report  /  find=series-a→kai  mazel'd  /  talk=@ariel|@kai turn=1..3  /  morph=denied  /  return=agent
mix match_chat_opener_demo        # ok  has=self_report  tags=[series-a]  /  find=series-a→kai  mazel'd  /  talk=@ariel opener=hello  /  talk=@kai  /  morph=denied
mix match_chat_check_demo         # ok  has=self_report  /  find=series-a→kai  mazel'd  /  check=pass  /  talk=@ariel|@kai  /  claim|contradict talk=none
mix match_chat_mismatch_demo      # ok  has=self_report  tags=[series-a]  /  need=self_report  tags=[impl]  /  overlap=[] find=none  /  talk=none
mix match_chat_multi_demo         # ok  need=self_report  tags=[series-a]  /  has=@kai  /  has=@nova  /  find=series-a→kai  mazel'd  /  talk=@kai|@nova morph=none
mix match_chat_pick_demo          # ok  need=self_report  tags=[series-a]  /  has=@kai  /  has=@nova  /  pick=@nova find=series-a→nova  mazel'd  /  talk=@kai|@nova morph=none
mix match_chat_direct_demo        # ok  direct=@kai  find=none  /  talk=@kai  turn=1  /  morph=denied  denied=badge_required
mix session_discovery_demo        # ok  discovery=need@mazel  handles=[kai]  /  find=series-a→kai match=self_report  mazel'd  /  session=agent  /  spam=human open=none
mix session_discovery_direct_demo # ok  discovery=need@mazel  handles=[kai]  /  pick=@kai direct=@kai morph=none  /  talk=@kai  /  morph=denied
mix session_discovery_id_demo     # ok  discovery=need@mazel  handles=[kai]  /  id=session-discovery-…  /  spam=human open=none
mix session_discovery_empty_demo  # ok  discovery=need@mazel  handles=[]  /  empty=clear  id=none  open=none  /  spam=human open=none
mix session_discovery_pick_demo   # ok  discovery=need@mazel  handles=[kai@mazel,@nova]  /  pick=kai@mazel direct=open id=session-direct-…  /  talk=@kai  /  morph=denied
mix session_discovery_pick_nova_demo # ok  discovery=need@mazel  handles=[kai@mazel,@nova]  /  pick=@nova direct=open id=session-direct-…  /  talk=@nova  /  morph=denied
mix session_discovery_pick_unknown_demo # ok  discovery=need@mazel  handles=[kai@mazel,@nova]  /  pick=@ghost rejected=unknown open=none id=none  /  talk=none
mix session_discovery_pick_blank_demo # ok  discovery=need@mazel  handles=[kai@mazel,@nova]  /  pick="" rejected=blank open=none id=none  /  talk=none
mix session_discovery_pick_ws_demo # ok  discovery=need@mazel  handles=[kai@mazel,@nova]  /  pick="   " rejected=blank open=none id=none  /  talk=none
mix session_discovery_pick_leave_demo # ok  discovery=need@mazel  handles=[kai@mazel,@nova]  /  pick=kai@mazel direct=open id=session-direct-…  /  talk=@kai  /  leave denied=left  /  rejoin same=true  /  talk=@kai  turn=2
mix session_discovery_pick_ttl_demo # ok  discovery=need@mazel  handles=[kai@mazel,@nova]  /  pick=kai@mazel direct=open id=session-direct-…-a  /  talk=@kai  /  ttl=expired  /  talk=@kai id=…-a denied=expired  /  pick=kai@mazel direct=open id=session-direct-…-b same=false  /  talk=@kai id=…-b turn=1
mix session_direct_id_demo        # ok  direct=@kai  id=session-direct-…  /  talk=@kai  turn=1  /  morph=denied  denied=badge_required
mix session_direct_after_find_demo # ok  add=mazel  paste=ready  /  find=…→kai  mazel'd  /  direct=@kai  id=session-direct-…  /  talk=@kai  turn=1  /  morph=denied  denied=badge_required
mix session_direct_two_handles_demo # ok  handles=[kai@mazel,@nova]  resolved=2  /  mazel'd=@kai  /  direct=@kai  id=session-direct-…  /  talk=@kai  turn=1  /  morph=denied  denied=badge_required
mix session_direct_two_handles_paste_demo # ok  add=mazel  paste=ready  /  handles=[kai@mazel,@nova]  resolved=2  /  find=…→kai  mazel'd  /  direct=@kai  id=session-direct-…  /  talk=@kai  turn=1  /  morph=denied  denied=badge_required
mix session_direct_two_handles_paste_return_demo # ok  add=mazel  paste=ready  /  handles=[kai@mazel,@nova]  resolved=2  /  find=…→kai  mazel'd  /  direct=@kai  id=session-direct-…  /  talk=@kai  turn=1  /  return=agent  same=true  /  morph=denied  denied=badge_required
mix session_direct_two_handles_paste_peer_demo # ok  add=mazel  paste=ready  /  handles=[kai@mazel,@nova]  resolved=2  /  find=…→kai  mazel'd  /  direct=@kai  id=session-direct-…  /  talk=@kai  turn=1  side=a  /  talk=@kai  turn=1  side=b  peer=agent  /  morph=denied  denied=badge_required
mix session_direct_two_handles_paste_peer_badge_demo # ok  add=mazel  paste=ready  /  handles=[kai@mazel,@nova]  resolved=2  /  find=…→kai  mazel'd  /  direct=@kai  id=session-direct-…  /  talk=@kai  turn=1  side=a  /  talk=@kai  turn=1  side=b  peer=agent  /  badge=present  morph.commit  /  talk=@kai  human=1  turn=1
mix session_direct_two_handles_paste_peer_badge_return_demo # ok  add=mazel  paste=ready  /  handles=[kai@mazel,@nova]  resolved=2  /  find=…→kai  mazel'd  /  direct=@kai  id=session-direct-…  /  talk=@kai  turn=1  side=a  /  talk=@kai  turn=1  side=b  peer=agent  /  badge=present  morph.commit  /  talk=@kai  human=1  turn=1  /  return=agent  same=true
mix session_direct_after_find_return_demo # ok  add=mazel  paste=ready  /  find=…→kai  mazel'd  /  direct=@kai  id=session-direct-…  /  mint=pull_match  /  morph.commit  /  talk=@kai  human=1  /  return=agent  same=true
mix session_direct_after_dual_portable_add_demo # ok  add=dual_portable  skill+mcp  checkout=none  /  find=…→kai  mazel'd  /  direct=@kai  id=session-direct-…  /  talk=@kai  turn=1  /  return=agent  same=true  /  re_paste=none  cwd=none  /  morph=denied  badge_required
mix session_direct_after_dual_portable_peer_demo # ok  add=dual_portable  skill+mcp  checkout=none  /  find=…→kai  mazel'd  /  direct=@kai  id=session-direct-…  /  talk=@kai  turn=1  side=a  /  talk=@kai  turn=1  side=b  peer=agent  /  re_paste=none  cwd=none  /  morph=denied  badge_required
mix session_direct_after_dual_portable_need_have_why_demo # ok  add=dual_portable  skill+mcp  checkout=none  /  find=series-a→kai  mazel'd  /  why  you_have×they_need  /  why  they_have×you_need  /  complete=agent  morph=none  session=agent
mix session_direct_after_dual_portable_find_why_demo # ok  add=dual_portable  skill+mcp  checkout=none  peers=2  /  find=series-a→kai  mazel'd  /  why  you_have×they_need  /  why  they_have×you_need  /  direct=@kai  id=session-direct-…  /  talk=@kai  turn=1  /  return=agent  same=true  /  re_paste=none  cwd=none  /  morph=denied  badge_required
mix session_direct_after_paste_door_why_demo # ok  mix=on_path  handoff=friend  /  add=dual_portable  skill+mcp  checkout=none  /  need=self_report  /  find=series-a→kai  mazel'd  /  why  you_have×they_need  /  why  they_have×you_need  /  direct=@kai  id=session-direct-…  /  talk=@kai  turn=1  /  return=agent  same=true  /  error  public_host=none  /  live_host_ready=no
mix session_direct_after_share_first_drop_why_demo # ok  handoff=friend  share=object  /  add=mazel  paste=ready  checkout=none  /  find=series-a→kai  mazel'd  /  why  you_have×they_need  /  why  they_have×you_need  /  direct=@kai  id=session-direct-…  /  talk=@kai  turn=1  /  return=agent  same=true
mix session_direct_after_dual_portable_peer_badge_demo # ok  add=dual_portable  skill+mcp  checkout=none  /  find=…→kai  mazel'd  /  direct=@kai  id=session-direct-…  /  talk=@kai  turn=1  side=a  /  talk=@kai  turn=1  side=b  peer=agent  /  badge=present  morph.commit  /  talk=@kai  human=1  turn=1  /  re_paste=none  cwd=none
mix session_direct_after_dual_portable_peer_badge_return_demo # ok  add=dual_portable  skill+mcp  checkout=none  /  find=…→kai  mazel'd  /  direct=@kai  id=session-direct-…  /  talk=@kai  turn=1  side=a  /  talk=@kai  turn=1  side=b  peer=agent  /  badge=present  morph.commit  /  talk=@kai  human=1  turn=1  /  return=agent  same=true  /  re_paste=none  cwd=none
mix session_direct_after_dual_portable_peer_badge_rejoin_demo # ok  add=dual_portable  skill+mcp  checkout=none  /  find=…→kai  mazel'd  /  direct=@kai  id=session-direct-…  /  talk=@kai  turn=1  side=a  /  talk=@kai  turn=1  side=b  peer=agent  /  badge=present  morph.commit  /  talk=@kai  human=1  turn=1  /  return=agent  same=true  /  rejoin=human  same=true  /  talk=@kai  human=1  turn=2  /  re_paste=none  cwd=none
mix session_direct_after_dual_portable_peer_badge_rejoin_leave_demo # ok  add=dual_portable  skill+mcp  checkout=none  /  find=…→kai  mazel'd  /  direct=@kai  id=session-direct-…  /  talk=@kai  turn=1  side=a  /  talk=@kai  turn=1  side=b  peer=agent  /  badge=present  morph.commit  /  talk=@kai  human=1  turn=1  /  return=agent  same=true  /  rejoin=human  same=true  /  talk=@kai  human=1  turn=2  /  leave=human  denied=left  /  talk=@kai  peer=agent  same=true  /  re_paste=none  cwd=none
mix session_direct_buddy_after_path_handoff_demo # ok  mix=on_path  handoff=path  /  add=dual_portable  skill+mcp  checkout=none  /  find=handoff→buddy  mazel'd  /  direct=@buddy  id=session-direct-…  /  talk=@buddy  turn=1  side=a  /  talk=@buddy  turn=1  side=b  peer=agent  /  re_paste=none  cwd=none  /  morph=denied  badge_required
mix session_direct_buddy_after_path_handoff_badge_demo # ok  mix=on_path  handoff=path  /  add=dual_portable  skill+mcp  checkout=none  /  find=handoff→buddy  mazel'd  /  direct=@buddy  id=session-direct-…  /  talk=@buddy  turn=1  side=a  /  talk=@buddy  turn=1  side=b  peer=agent  /  badge=present  morph.commit  /  talk=@buddy  human=1  turn=1  /  re_paste=none  cwd=none
mix session_direct_buddy_after_path_handoff_badge_leave_demo # ok  mix=on_path  handoff=path  /  add=dual_portable  skill+mcp  checkout=none  /  find=handoff→buddy  mazel'd  /  direct=@buddy  id=session-direct-…  /  talk=@buddy  turn=1  side=a  /  talk=@buddy  turn=1  side=b  peer=agent  /  badge=present  morph.commit  /  talk=@buddy  human=1  turn=1  /  leave=human  denied=left  /  talk=@buddy  peer=agent  same=true  /  re_paste=none  cwd=none
mix session_direct_buddy_after_path_handoff_badge_rejoin_demo # ok  mix=on_path  handoff=path  /  add=dual_portable  skill+mcp  checkout=none  /  find=handoff→buddy  mazel'd  /  direct=@buddy  id=session-direct-…  /  talk=@buddy  turn=1  side=a  /  talk=@buddy  turn=1  side=b  peer=agent  /  badge=present  morph.commit  /  talk=@buddy  human=1  turn=1  /  leave=human  denied=left  /  talk=@buddy  peer=agent  same=true  /  rejoin=human  same=true  /  talk=@buddy  human=1  turn=2  /  re_paste=none  cwd=none
mix session_intro_buddy_after_path_handoff_demo # ok  mix=on_path  handoff=path  /  add=dual_portable  skill+mcp  checkout=none  /  intro=🪽🪽  handle=@buddy  id=session-intro-…  /  talk=@buddy  turn=1  /  re_paste=none  cwd=none  /  morph=denied  badge_required
mix session_intro_buddy_after_path_handoff_badge_demo # ok  mix=on_path  handoff=path  /  add=dual_portable  skill+mcp  checkout=none  /  intro=🪽🪽  handle=@buddy  id=session-intro-…  /  badge=present  morph.commit  /  talk=@buddy  human=1  turn=1  /  re_paste=none  cwd=none
mix session_intro_buddy_after_path_handoff_badge_return_demo # ok  mix=on_path  handoff=path  /  add=dual_portable  skill+mcp  checkout=none  /  intro=🪽🪽  handle=@buddy  id=session-intro-…  /  badge=present  morph.commit  /  talk=@buddy  human=1  turn=1  /  return=agent  same=true  /  talk=@buddy  peer=agent  same=true  /  re_paste=none  cwd=none
mix session_intro_buddy_after_path_handoff_badge_why_return_demo # ok  mix=on_path  handoff=path  /  add=dual_portable  skill+mcp  checkout=none  /  intro=🪽🪽  handle=@buddy  id=session-intro-…  /  badge=present  morph.commit  /  why  you_have×they_need  /  why  they_have×you_need  /  talk=@buddy  human=1  turn=1  /  return=agent  same=true  /  re_paste=none  cwd=none
mix session_intro_buddy_after_path_handoff_badge_leave_demo # ok  mix=on_path  handoff=path  /  add=dual_portable  skill+mcp  checkout=none  /  intro=🪽🪽  handle=@buddy  id=session-intro-…  /  badge=present  morph.commit  /  talk=@buddy  human=1  turn=1  /  leave=human  denied=left  /  talk=@buddy  peer=agent  same=true  /  re_paste=none  cwd=none
mix session_intro_buddy_after_path_handoff_badge_leave_rejoin_demo # ok  mix=on_path  handoff=path  /  add=dual_portable  skill+mcp  checkout=none  /  intro=🪽🪽  handle=@buddy  id=session-intro-…  /  badge=present  morph.commit  /  talk=@buddy  human=1  turn=1  /  leave=human  denied=left  /  talk=@buddy  peer=agent  same=true  /  rejoin=human  same=true  /  talk=@buddy  human=1  turn=2  /  re_paste=none  cwd=none
mix session_direct_find_badge_return_demo # ok  find=series-a→kai  mazel'd  /  direct=@kai  id=session-direct-…  /  badge=present  morph.commit  /  talk=@kai  human=1  turn=1  /  return=agent  same=true
mix session_direct_find_opener_check_demo # ok  find=series-a→kai  mazel'd  /  direct=@kai  id=session-direct-…  /  check=pass  opener=hello  /  talk=@kai  turn=1  /  morph=denied  denied=badge_required
mix session_direct_find_opener_check_fail_demo # ok  find=series-a→kai  mazel'd  /  direct=@kai  id=session-direct-…  /  check=fail  opener=none  /  talk=none  /  morph=denied  denied=badge_required
mix session_direct_find_opener_check_retry_demo # ok  find=series-a→kai  mazel'd  /  direct=@kai  id=session-direct-…  /  check=fail  opener=none  talk=none  /  check=pass  opener=hello  same=true  /  talk=@kai  turn=1  /  morph=denied  denied=badge_required
mix session_intro_demo            # ok  intro=🪽🪽  session=agent  /  talk=@kai  turn=1  /  error  human=asleep  stamp=none
mix session_intro_id_demo         # ok  intro=🪽🪽  id=session-intro-…  /  talk=@kai  turn=1  /  morph=denied  denied=badge_required
mix session_intro_opener_check_demo # ok  intro=🪽🪽  id=session-intro-…  /  check=pass  opener=hello  /  talk=@kai  turn=1  /  morph=denied  denied=badge_required
mix session_intro_opener_check_fail_demo # ok  intro=🪽🪽  id=session-intro-…  /  check=fail  opener=none  /  talk=none  /  morph=denied  denied=badge_required
mix session_intro_opener_check_retry_demo # ok  intro=🪽🪽  id=session-intro-…  /  check=fail  opener=none  talk=none  /  check=pass  opener=hello  same=true  /  talk=@kai  turn=1  /  morph=denied  denied=badge_required
mix session_intro_leave_rejoin_same_id_demo # ok  intro=🪽🪽  id=session-intro-…  /  talk=@kai  turn=1  /  leave denied=left  /  rejoin same=true  /  talk=@kai  turn=2  /  morph=denied  denied=badge_required
mix session_intro_badge_return_demo # ok  intro=🪽🪽  id=session-intro-…  /  badge=present  morph.commit  /  talk=@kai  human=1  turn=1  /  return=agent  same=true
mix session_intro_no_badge_demo   # ok  intro=🪽🪽  id=session-intro-…  /  talk=@kai  agent=1  turn=1  /  morph=denied  denied=badge_required  /  human=blocked  join=none
mix session_group_demo            # ok  group=🪽🪽🪽  session=agent  /  talk=@kai,@nova  turn=1  /  error  human=asleep  stamp=none
mix session_group_id_demo         # ok  group=🪽🪽🪽  id=session-group-…  /  talk=@kai,@nova  turn=1  /  morph=denied  denied=badge_required
mix session_group_leave_rejoin_same_id_demo # ok  group=🪽🪽🪽  id=session-group-…  /  talk=@kai,@nova  turn=1  /  leave denied=left  /  rejoin same=true  /  talk=@kai  turn=2  /  morph=denied  denied=badge_required
mix session_labels_demo           # ok  id=direct  label=Direct  wing=🪽  /  id=intro  /  id=group  /  swap  id=direct  1:1  /  Direct
mix session_presence_demo         # ok  presence=direct  agents=[ariel@mazel,kai@mazel]  /  intro  /  group  /  error  human=none  stamp=none
mix session_leave_demo            # ok  leave=@kai  presence=direct  agents=[ariel@mazel]  /  intro  /  leave=@nova  group  /  session=agent  still_open=true
mix session_rejoin_demo           # ok  leave=@kai  presence=direct  agents=[ariel@mazel]  /  rejoin=@kai  agents=[ariel@mazel,kai@mazel]  /  intro  /  leave=@nova  group  /  rejoin=@nova  /  session=agent  still_open=true
mix session_context_demo          # ok  contextId=…  before=leave  /  leave=@kai  /  rejoin=@kai  /  contextId=…  same=true
mix session_leave_talk_demo       # ok  session=open  id=…  talk=@kai  turn=1  /  leave=@kai  /  talk=@kai  denied=left  /  rejoin=@kai  id=…  same=true  /  talk=@kai  turn=1
mix session_leave_peer_demo       # ok  session=open  id=…  talk=@kai  /  leave=@kai  /  talk=@ariel  peer=agent  /  talk=@kai  denied=left  /  rejoin=@kai  same=true  /  talk=@kai  turn=1
mix session_leave_both_demo       # ok  session=open  id=…  talk=@kai/@ariel  /  leave=@kai  /  leave=@ariel  /  talk=@kai|@ariel peer=agent  /  talk=@kai|@ariel denied=left  /  rejoin=@kai same=true  /  talk=@kai  turn=1
mix session_leave_both_partial_demo # ok  leave=@kai  /  leave=@ariel  /  rejoin=@kai  same=true  /  talk=@kai  turn=1  /  talk=@ariel  denied=left  /  rejoin=@ariel  same=true  /  talk=@ariel  turn=1
mix session_leave_rejoin_same_id_demo # ok  session=open  id=…  talk=@kai  turn=1  /  leave=@kai  /  talk=@kai  denied=left  /  rejoin=@kai  id=…  same=true  /  talk=@kai  turn=1
mix session_ttl_demo              # ok  session=open  talk=@kai  turn=1  /  error  ttl=expired  talk=denied  /  session=fresh  talk=@kai  turn=1
mix session_ttl_id_demo           # ok  session=open  id=session-…-a  talk=@kai  /  ttl=expired talk=denied  /  session=fresh  id=session-…-b  same=false  /  talk=@kai  turn=1
mix session_ttl_mid_demo          # ok  session=open  id=…  talk=@kai  turn=1  /  error  ttl=expired  talk=denied  /  session=fresh  id=…  same=false  /  talk=@kai  turn=1
mix session_ttl_presence_demo     # ok  session=open  id=…  presence=agents=[…]  /  error  ttl=expired  /  presence=…  agents=[]  humans=[]
mix session_ttl_presence_fresh_demo # ok  session=open  id=…-a  presence=agents=[…]  /  ttl=expired  /  presence=…-a empty  /  session=fresh  id=…-b  same=false  presence=agents=[…]  /  presence=…-a empty
mix session_ttl_talk_ids_demo     # ok  session=open  id=…-a  talk=@kai  /  ttl=expired  /  talk=@kai  id=…-a  denied=expired  /  session=fresh  id=…-b  same=false  /  talk=@kai  id=…-b  turn=1
mix session_rejoin_ttl_demo       # ok  session=open  id=…  /  leave=@kai  /  ttl=expired  /  rejoin=@kai  denied=expired  /  session=fresh  id=…  same=false  /  talk=@kai  turn=1
mix agent_stay_demo               # ok  find=series-a→kai  match=self_report  mazel'd  /  session=agent  morph=none  /  wake=human  stamp=none  soft_no
mix agent_stay_stamp_demo         # ok  find=series-a→kai  match=self_report  mazel'd  /  session=agent  /  wake stamp=none soft_no  /  wake stamp=pull_match
mix agent_stay_direct_pull_badge_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  morph=denied  badge_required  /  mint=pull_match  /  join=human  morph.commit
mix agent_stay_direct_pull_friend_try_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  morph=denied  badge_required  /  friend=blocked join=none  /  mint=pull_match  /  friend=try join=human  /  consent=dual morph.commit
mix agent_stay_direct_pull_friend_try_present_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  badge=present  mint=none  /  friend=try join=human  /  consent=dual morph.commit
mix agent_stay_direct_pull_friend_try_leave_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  badge=present  mint=none  /  friend=try join=human  /  consent=dual morph.commit  /  revoke=@kai  morph=closed  human=asleep  session=agent
mix agent_stay_direct_pull_friend_try_rejoin_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  badge=present  mint=none  /  friend=try join=human  /  consent=dual morph.commit  /  revoke=@kai  morph=closed  session=agent  /  badge=present  mint=none  /  friend=rejoin join=human  /  consent=dual morph.commit
mix agent_stay_direct_pull_friend_try_rejoin_leave_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  badge=present  mint=none  /  friend=try join=human  /  consent=dual morph.commit  /  revoke=@kai  morph=closed  session=agent  /  badge=present  mint=none  /  friend=rejoin join=human  /  consent=dual morph.commit  /  revoke=@kai  morph=closed  human=asleep  session=agent
mix agent_stay_direct_pull_friend_try_warm_custom_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  badge=present  mint=none  /  friend=try join=human  /  consent=dual morph.commit  /  warm note=hello from dual
mix agent_stay_direct_pull_friend_try_warm_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  badge=present  mint=none  /  friend=try join=human  /  consent=dual morph.commit  /  warm note=both in
mix agent_stay_direct_pull_friend_try_soft_no_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  badge=present  mint=none  /  friend=soft_no join=none  /  session=agent  /  talk=free
mix agent_stay_direct_pull_friend_try_dual_portable_demo # ok  onramp=dual  friend=try  /  skill=portable  mcp=portable  /  find=…→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  badge=present  mint=none  /  friend=try join=human  /  consent=dual morph.commit
mix agent_stay_direct_pull_friend_try_dual_portable_soft_no_demo # ok  onramp=dual  friend=try  /  skill=portable  mcp=portable  /  find=…→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  badge=present  mint=none  /  friend=soft_no join=none  /  session=agent  /  talk=free
mix agent_stay_direct_pull_friend_try_dual_portable_badge_demo # ok  onramp=dual  friend=try  /  skill=portable  mcp=portable  /  find=…→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  morph=denied  badge_required  /  friend=blocked join=none  /  mint=pull_match  badge=pull_intent  /  friend=try join=human  /  consent=dual morph.commit
mix agent_stay_direct_pull_friend_try_dual_portable_badge_warm_demo # ok  onramp=dual  friend=try  /  skill=portable  mcp=portable  /  find=…→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  morph=denied  badge_required  /  friend=blocked join=none  /  mint=pull_match  badge=pull_intent  /  friend=try join=human  /  consent=dual morph.commit  /  warm note=both in
mix agent_stay_direct_pull_friend_try_dual_portable_badge_later_demo # ok  onramp=dual  friend=try  /  skill=portable  mcp=portable  /  find=…→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  morph=denied  badge_required  /  mint=pull_match  badge=pull_intent  /  friend=soft_no join=none  /  session=agent  /  consent=dual morph.commit  /  friend=try join=human  /  warm note=both in
mix agent_stay_direct_pull_friend_try_dual_portable_badge_later_revoke_demo # ok  onramp=dual  friend=try  /  skill=portable  mcp=portable  /  find=…→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  morph=denied  badge_required  /  mint=pull_match  badge=pull_intent  /  friend=soft_no join=none  /  session=agent  /  consent=dual morph.commit  /  friend=try join=human  /  warm note=both in  /  revoke=@kai morph=closed human=asleep session=agent
mix agent_stay_direct_pull_friend_seat_dual_portable_invite_demo # ok  onramp=dual  friend=try  /  skill=portable  mcp=portable  /  find=…→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  morph=denied  badge_required  /  mint=invite  badge=invite_token  seat=friend  /  friend=try join=human  /  consent=dual morph.commit
mix agent_stay_direct_pull_friend_seat_dual_portable_invite_warm_demo # ok  onramp=dual  friend=try  /  skill=portable  mcp=portable  /  find=…→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  morph=denied  badge_required  /  mint=invite  badge=invite_token  seat=friend  /  friend=try join=human  /  consent=dual morph.commit  /  warm note=both in
mix agent_stay_direct_pull_friend_seat_dual_portable_invite_soft_no_demo # ok  onramp=dual  friend=try  /  skill=portable  mcp=portable  /  find=…→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  morph=denied  badge_required  /  mint=invite  badge=invite_token  seat=friend  /  friend=soft_no join=none  /  session=agent  /  talk=free
mix agent_stay_direct_pull_friend_seat_dual_portable_invite_later_demo # ok  onramp=dual  friend=try  /  skill=portable  mcp=portable  /  find=…→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  morph=denied  badge_required  /  mint=invite  badge=invite_token  seat=friend  /  friend=soft_no join=none  /  session=agent  /  consent=dual morph.commit  /  friend=try join=human  /  warm note=both in
mix agent_stay_direct_pull_friend_seat_dual_portable_invite_buddy_demo # ok  onramp=dual  friend=try  /  skill=portable  mcp=portable  /  find=handoff→buddy  mazel'd  /  direct=@buddy  talk=free  /  morph=denied  badge_required  /  mint=invite  badge=invite_token  seat=friend  /  friend=try join=human  /  consent=dual morph.commit
mix agent_stay_direct_pull_friend_seat_dual_portable_invite_buddy_warm_demo # ok  onramp=dual  friend=try  /  skill=portable  mcp=portable  /  find=handoff→buddy  mazel'd  /  direct=@buddy  talk=free  /  morph=denied  badge_required  /  mint=invite  badge=invite_token  seat=friend  /  friend=try join=human  /  consent=dual morph.commit  /  warm note=both in
mix agent_stay_direct_pull_friend_seat_dual_portable_invite_paste_door_warm_demo # ok  onramp=dual  friend=try  /  skill=portable  mcp=portable  /  find=paste→buddy  mazel'd  /  direct=@buddy  talk=free  /  morph=denied  badge_required  /  mint=invite  badge=invite_token  seat=friend  /  friend=try join=human  /  consent=dual morph.commit  /  warm note=both in
mix agent_stay_direct_pull_friend_seat_dual_portable_invite_share_paste_warm_demo # ok  share=sendable  paste_door=yes  /  onramp=dual  friend=try  /  skill=portable  mcp=portable  /  find=paste→buddy  mazel'd  /  direct=@buddy  talk=free  /  morph=denied  badge_required  /  mint=invite  badge=invite_token  seat=friend  /  friend=try join=human  /  consent=dual morph.commit  /  warm note=both in
mix agent_stay_direct_pull_friend_seat_dual_portable_invite_buddy_warm_leave_demo # ok  onramp=dual  friend=try  /  skill=portable  mcp=portable  /  find=handoff→buddy  mazel'd  /  direct=@buddy  talk=free  /  morph=denied  badge_required  /  mint=invite  badge=invite_token  seat=friend  /  friend=try join=human  /  consent=dual morph.commit  /  warm note=both in  /  revoke=@buddy morph=closed human=asleep session=agent
mix agent_stay_direct_pull_friend_seat_live_host_ready_demo # ok  onramp=dual  friend=try  /  skill=portable  mcp=portable  /  find=handoff→buddy  mazel'd  /  direct=@buddy  talk=free  /  live_host_ready=no  /  error  public_host=none  /  error  seat=friend  denied=host_none  /  join=none
mix agent_stay_direct_pull_friend_seat_dual_portable_invite_live_host_demo # ok  live_host=none deny=yes join=none  /  live_host=fixture  /  onramp=dual  friend=try  /  skill=portable  mcp=portable  /  find=handoff→buddy  mazel'd  /  direct=@buddy  talk=free  /  mint=invite  badge=invite_token  seat=friend  /  friend=try join=human  /  consent=dual morph.commit
mix agent_stay_direct_pull_friend_seat_dual_portable_invite_live_host_fixture_demo # ok  live_host=fixture  /  onramp=dual  friend=try  /  skill=portable  mcp=portable  /  find=handoff→buddy  mazel'd  /  direct=@buddy  talk=free  /  morph=denied  badge_required  /  mint=invite  badge=invite_token  seat=friend  /  friend=try join=human  /  consent=dual morph.commit  /  warm note=both in
mix agent_stay_direct_pull_dual_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  morph=denied  badge_required  /  mint=pull_match  /  consent=dual morph.commit  /  peer=soft_no  /  session=agent
mix agent_stay_direct_pull_soft_no_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  morph=denied  badge_required  /  mint=pull_match  /  peer=soft_no  /  session=agent
mix agent_stay_direct_pull_later_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  morph=denied  badge_required  /  mint=pull_match  /  peer=soft_no  /  session=agent  /  consent=dual morph.commit  /  join=human  /  warm note=both in
mix agent_stay_direct_pull_later_one_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  morph=denied  badge_required  /  mint=pull_match  /  peer=soft_no  /  session=agent  /  consent=one morph=denied  /  session=agent
mix agent_stay_direct_pull_later_timeout_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  morph=denied  badge_required  /  mint=pull_match  /  peer=soft_no  /  session=agent  /  consent=expired morph=denied  /  session=agent
mix agent_stay_direct_pull_later_timeout_later_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  morph=denied  badge_required  /  mint=pull_match  /  peer=soft_no  /  session=agent  /  consent=expired morph=denied  /  session=agent  /  consent=dual morph.commit  /  join=human  /  warm note=both in
mix agent_stay_direct_pull_later_revoke_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  morph=denied  badge_required  /  mint=pull_match  /  peer=soft_no  /  session=agent  /  consent=dual morph.commit  /  join=human  /  warm note=both in  /  revoke=@kai morph=closed human=asleep session=agent
mix agent_stay_direct_pull_later_revoke_both_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  direct=@kai  talk=free  /  morph=denied  badge_required  /  mint=pull_match  /  peer=soft_no  /  session=agent  /  consent=dual morph.commit  /  join=human  /  warm note=both in  /  revoke=both morph=closed human=asleep session=agent
mix agent_stay_invite_demo        # ok  find=series-a→kai  match=self_report  mazel'd  /  session=agent  /  wake stamp=none soft_no  /  wake stamp=invite
mix agent_stay_vouch_demo         # ok  find=series-a→kai  match=self_report  mazel'd  /  session=agent  /  wake stamp=none soft_no  /  wake stamp=vouch  /  mint=self asleep
mix agent_stay_pow_demo           # ok  find=series-a→kai  match=self_report  mazel'd  /  session=agent  /  wake stamp=none soft_no  /  wake stamp=pow
mix agent_stay_dual_consent_demo  # ok  find=series-a→kai  match=self_report  mazel'd  /  session=agent  /  wake stamp=pull_match  /  consent=one denied  /  consent=dual morph.commit  /  return=agent
mix agent_stay_warm_demo          # ok  find=series-a→kai  match=self_report  mazel'd  /  session=agent  /  wake stamp=pull_match  /  consent=dual morph.commit  /  warm who/why/opener  /  return=agent
mix agent_stay_soft_no_demo       # ok  find=series-a→kai  match=self_report  mazel'd  /  session=agent  /  wake stamp=pull_match  /  peer=soft_no morph=denied human=asleep
mix agent_stay_decline_then_yes_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  peer=soft_no  /  consent=dual morph.commit  /  warm  /  return=agent
mix agent_stay_return_why_demo    # ok  find=series-a→kai  match=self_report  mazel'd  /  consent=dual morph.commit  /  warm  /  return=agent  /  why  return=
mix agent_stay_revoke_demo        # ok  find=series-a→kai  match=self_report  mazel'd  /  session=agent  /  wake stamp=pull_match  /  consent=dual morph.commit  /  revoke morph=closed human=asleep
mix agent_stay_rejoin_demo        # ok  find=series-a→kai  match=self_report  mazel'd  /  revoke  /  consent=dual morph.commit  /  warm who/why/opener
mix agent_stay_reopen_demo        # ok  find=series-a→kai  match=self_report  mazel'd  /  revoke  /  stamp=none soft_no  /  stamp wake  /  consent=dual morph.commit  /  warm
mix agent_stay_human_presence_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  wake stamp=pull_match  /  consent=dual morph.commit  /  presence=human+agents
mix agent_stay_presence_revoke_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  presence=human+agents  /  revoke  /  presence=agents  humans=[]
mix agent_stay_presence_revoke_mid_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  presence=human+agents  /  talk=@ariel  /  talk=@kai  /  revoke  /  presence=agents  humans=[]
mix agent_stay_presence_revoke_both_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  presence=human+agents  /  revoke=@ariel  /  revoke=@kai  /  presence=agents  /  stamp=none soft_no
mix consent_revoke_mid_session_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  presence=human+agents  /  talk=@ariel  /  talk=@kai  /  revoke  /  presence=agents  humans=[]
mix agent_stay_presence_reopen_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  presence=human+agents  /  revoke  /  presence=agents  /  stamp wake  /  remorph  /  presence=human+agents
mix agent_stay_presence_soft_no_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  presence=human+agents  /  peer=soft_no morph=denied  /  presence=agents  humans=[]
mix agent_stay_presence_never_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  presence=agents  humans=[]  /  wake  /  peer=soft_no morph=denied  /  presence=agents  humans=[]
mix agent_stay_presence_later_yes_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  presence=agents  humans=[]  /  peer=soft_no  /  wake  /  consent=dual  /  presence=human+agents
mix agent_stay_presence_warm_later_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  presence=agents  humans=[]  /  peer=soft_no  /  warm=none note=omitted  /  wake  /  consent=dual morph.commit  /  presence=human+agents  /  warm  note=both in
mix agent_stay_presence_warm_later_custom_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  presence=agents  humans=[]  /  peer=soft_no  /  warm=none note=omitted  /  wake  /  consent=dual morph.commit  /  presence=human+agents  /  warm  note=hello from dual
mix agent_stay_presence_offline_wait_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  presence=agents  humans=[]  /  wake  /  consent=one morph=none  /  consent=wait peer=offline  /  presence=agents  humans=[]
mix agent_stay_presence_offline_return_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  presence=agents  humans=[]  /  wake  /  consent=one morph=none  /  consent=wait peer=offline  /  presence=agents  humans=[]  /  consent=dual morph.commit  /  presence=human+agents  /  warm  note=both in
mix agent_stay_presence_offline_timeout_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  presence=agents  humans=[]  /  wake  /  consent=one morph=none  /  consent=wait peer=offline  /  presence=agents  humans=[]  /  consent=expired wait=cleared morph=none  /  presence=agents  humans=[]
mix agent_stay_presence_offline_timeout_later_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  presence=agents  humans=[]  /  wake  /  consent=one morph=none  /  consent=wait peer=offline  /  presence=agents  humans=[]  /  consent=expired wait=cleared morph=none  /  presence=agents  humans=[]  /  wake  /  consent=dual morph.commit  /  presence=human+agents  /  warm  note=both in
mix agent_stay_presence_offline_soft_no_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  presence=agents  humans=[]  /  wake  /  consent=one morph=none  /  consent=wait peer=offline  /  presence=agents  humans=[]  /  peer=soft_no morph=denied wait=cleared  /  presence=agents  humans=[]
mix agent_stay_presence_warm_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  wake stamp=pull_match  /  consent=dual morph.commit  /  presence=human+agents  /  warm  note=both in
mix agent_stay_presence_warm_custom_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  wake stamp=pull_match  /  consent=dual morph.commit  /  presence=human+agents  /  warm  note=hello from dual
mix agent_stay_presence_warm_trim_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  wake stamp=pull_match  /  consent=dual morph.commit  /  presence=human+agents  /  warm  note=hello from dual
mix agent_stay_presence_warm_trim_trunc_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  wake stamp=pull_match  /  consent=dual morph.commit  /  presence=human+agents  /  warm  note=…  trunc=true  note_max=32
mix agent_stay_presence_warm_empty_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  wake stamp=pull_match  /  consent=dual morph.commit  /  presence=human+agents  /  warm  note=both in
mix agent_stay_presence_warm_blank_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  wake stamp=pull_match  /  consent=dual morph.commit  /  presence=human+agents  /  warm  note=both in
mix agent_stay_presence_warm_long_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  wake stamp=pull_match  /  consent=dual morph.commit  /  presence=human+agents  /  warm  note=…  trunc=true  note_max=32
mix agent_stay_presence_warm_exact_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  wake stamp=pull_match  /  consent=dual morph.commit  /  presence=human+agents  /  warm  note=…  note_max=32
mix agent_stay_presence_warm_over_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  wake stamp=pull_match  /  consent=dual morph.commit  /  presence=human+agents  /  warm  note=…  trunc=true  note_max=32
mix agent_stay_presence_warm_revoke_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  presence=human+agents  /  warm  note=both in  /  revoke  /  presence=agents  /  error  warm=none  note=cleared
mix agent_stay_presence_warm_reopen_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  warm  note=both in  /  revoke  note=cleared  /  remorph  /  warm  note=both in
mix agent_stay_presence_warm_reopen_custom_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  warm  note=hello from dual  /  revoke  note=cleared  /  remorph  /  warm  note=hello from dual
mix agent_stay_presence_warm_revoke_mid_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  warm  note=both in  /  talk=@ariel  /  talk=@kai  /  revoke  note=cleared  /  stamp=none soft_no
mix agent_stay_presence_no_warm_demo # ok  find=series-a→kai  match=self_report  mazel'd  /  presence=agents  humans=[]  /  peer=soft_no  /  presence=agents  /  error  warm=none  note=omitted
mix self_report_overlap_demo      # ok  has=self_report  tags=[series-a,cto]  /  need=self_report  tags=[series-a]  /  overlap=[series-a]  /  find=series-a→kai  mazel'd  /  overlap=[] match=none
mix self_report_need_multi_tag_demo # ok  need=self_report  tags=[series-a,cto]  /  has=self_report  tags=[series-a]  /  overlap=[series-a]  /  find=series-a→kai  mazel'd  /  complete=agent
mix self_report_has_multi_tag_demo # ok  need=self_report  tags=[series-a]  /  has=self_report  tags=[series-a,cto]  /  overlap=[series-a]  /  find=series-a→kai  mazel'd  /  complete=agent
mix self_report_tag_dedupe_demo   # ok  cast=need  tags=[series-a,series-a]  dedupe=[series-a]  from=chat  /  has=self_report  /  find=series-a→kai  mazel'd  /  complete=agent
mix self_report_has_tag_dedupe_demo # ok  need=self_report  tags=[series-a]  /  cast=has  tags=[series-a,series-a]  dedupe=[series-a]  from=chat  /  find=series-a→kai  mazel'd  /  complete=agent
mix self_report_tag_mismatch_demo # ok  need=self_report  tags=[series-a]  /  has=self_report  tags=[cto]  /  error  overlap=[]  find=none  mazel'd=none  /  complete=agent
mix self_report_why_demo          # ok  has=self_report  tags=[series-a]  /  find=series-a→kai  mazel'd  /  why  need=  /  why  has=  /  complete=agent
mix self_report_bidirectional_demo # ok  a need=series-a  has=cto  /  b need=cto  has=series-a  /  find both mazel'd  /  why  need=  has=  /  complete=agent
mix self_report_check_demo        # ok  has=self_report  tags=[series-a]  /  prompt_check=pass  /  find=series-a→kai  mazel'd  /  claim|contradiction curious mazel'd=none  /  complete=agent
mix self_report_need_ttl_demo     # ok  has=self_report  tags=[series-a]  /  need=self_report  need_ttl=fresh  /  find=series-a→kai  mazel'd  /  expired find=none  /  complete=agent
mix self_report_need_ttl_expire_demo # ok  cast=need  tags=[series-a]  need_ttl=fresh  from=chat  /  find  /  need_ttl=expired  /  find=series-a match=none  /  complete=agent
mix self_report_cast_demo         # ok  cast=need  tags=[series-a]  from=chat  /  has=self_report  /  find=series-a→kai  mazel'd  /  complete=agent
mix self_report_shape_demo        # ok  cast=need  shape=founder_investors  tags=[series-a]  from=chat  /  has=self_report  /  find=series-a→kai  mazel'd  /  shape=founder_investors  /  complete=agent
mix self_report_shape_mismatch_demo # ok  cast=need  shape=founder_investors  /  has=self_report  shape=icp_pain  /  find mazel'd  /  error  shape=mismatch  /  complete=agent
mix self_report_has_cast_demo     # ok  cast=has  tags=[series-a]  from=chat  /  need=self_report  /  find=series-a→kai  mazel'd  /  complete=agent
mix self_report_recast_demo       # ok  cast=need  tags=[series-a]  from=chat  /  recast=need  tags=[cto]  replaces=series-a  /  find=cto→kai  mazel'd  /  series-a match=none
mix self_report_multi_need_demo   # ok  cast=need  tags=[series-a]  from=chat  /  cast=need  tags=[cto]  from=chat  /  find=series-a→kai  mazel'd  /  find=cto match=none
mix self_report_multi_need_clear_demo # ok  cast=need  tags=[series-a]  /  cast=need  tags=[cto]  /  find both  /  clear=need  tags=[series-a]  /  series-a match=none  /  find=cto→kai  mazel'd
mix self_report_multi_need_clear_both_demo # ok  cast=need  tags=[series-a]  /  cast=need  tags=[cto]  /  find both  /  clear=need  tags=[series-a,cto]  /  series-a match=none  /  cto match=none
mix self_report_clear_all_needs_demo # ok  cast=need  tags=[series-a]  /  cast=need  tags=[cto]  /  find both  /  clear=need  tags=[series-a,cto]  /  series-a match=none  /  cto match=none
mix self_report_clear_demo        # ok  cast=need  tags=[series-a]  from=chat  /  find  /  clear=need  tags=[]  /  match=none  /  recast  /  find  /  complete=agent
mix self_report_clear_has_demo    # ok  need=self_report  tags=[series-a]  /  has=self_report  /  find  /  clear=has  tags=[]  /  need still  /  find=none mazel'd=none  /  complete=agent
mix self_report_update_has_demo   # ok  need=self_report  tags=[series-a]  /  has=self_report  /  find  /  update=has  tags=[cto]  replaces=series-a  /  find=none mazel'd=none  /  complete=agent
mix self_report_update_has_restore_demo # ok  need=self_report  /  has=self_report  /  find  /  update=has  tags=[cto]  /  find=none  /  update=has  tags=[series-a]  /  find  /  complete=agent
mix self_report_update_need_demo  # ok  need=self_report  tags=[series-a]  /  has=self_report  /  find  /  update=need  tags=[cto]  replaces=series-a  /  has stays  /  find=cto none  /  find=series-a none  /  complete=agent
mix self_report_update_need_restore_demo # ok  need=self_report  /  has=self_report  /  find  /  update=need  tags=[cto]  /  find=none  /  update=need  tags=[series-a]  /  find  /  complete=agent
mix self_report_curious_demo      # error  cast=curious  class=curious  /  find match=none mazel'd=none  /  cast=claim  /  find none  /  complete=agent
mix self_report_toolbelt_demo     # ok  has=self_report  tags=[series-a]  /  tools=unlocked mazel_find=1  /  vault=empty locked  /  need=self_report  /  tools=unlocked
mix linkedin_demo                 # ok  import=linkedin →curious  /  has=[] / curious=[…]  /  no_trail
mix trail_score_demo              # ok  resume-only  inputs={…trail:0}  curious  /  gh+check  inputs={…trail:1,check:1}  score=2
mix mcp_trail_demo                # ok  mcp=artifact  trail=1  /  find=series-a→kai  trail=1  /  need×has  score=2  /  claim→curious
mix mcp_refresh_demo              # ok  mcp=live  trail=1  age=fresh  /  mcp=quiet  decay=soft  age=stale  /  claim→curious
mix why_demo                      # ok  need×has  score=2  /  why  need=series-a  /  why  has=series-a
mix jit_demo                      # ok  need_ttl=fresh  /  age=stale  still_paths  /  expired unfit
mix harp_demo                     # ok  export=harp  has=4  needs=3  curious=2  /  ## Needs  shape=…  ttl=hard  need_ttl=fresh|expired
mix curious_rubric_demo           # ok  grade=has  proof=series-a  /  grade=needs  shape=icp_pain  /  grade=curious  match=never  /  curious→unfit
mix open_demo                     # ok  has→open  /  need×open  /  mazel'd
mix open_need_demo                # ok  open→need  shape=icp_pain  ttl=hard  need_ttl=fresh  /  need×has  /  expired  /  vibe→curious
mix open_need_check_demo          # ok  open→need  shape=icp_pain  check=pass  /  need×has  /  claim→curious  /  contradict→curious
mix prompt_check_demo             # ok  need×has  peer=kai@mazel  check=pass  /  claim→curious  /  contradict→curious
mix labels_demo                   # ok  id=has  label=Has  /  swap  id=morph  Connect  /  Morph
mix mcp_demo                      # Mazel is ready. mazel_find → mazel_wing
mix install_demo                  # Mazel is ready. paste=cursor|grok|hermes|muse  stdio=mix mcp
mix install_add_mazel_demo        # error  add=none  tools=locked  /  ok  add=mazel  button=ok  paste=cursor|grok|hermes|muse  /  vault=empty locked  /  has|need self_report unlock
mix install_add_twice_demo        # ok  add=mazel  button=ok  /  need=self_report  /  tools=unlocked  /  add=mazel  idempotent=true  /  tools=unlocked  /  unlock_count=1
mix install_gate_demo             # ok  has=self_report  /  error  add=none  tools=locked  /  need=self_report  /  add=none locked  /  add=mazel  /  tools=unlocked
mix install_remove_mazel_demo     # ok  add=mazel  button=ok  /  has self_report unlock  /  ok  remove=mazel  button=gone  /  tools=locked  has|need self_report
mix install_unlock_remove_demo    # ok  add=mazel  button=ok  /  need=self_report unlock  /  ok  remove=mazel  button=gone  /  tools=locked  mazel_find=0
mix install_remove_relock_demo    # ok  add=mazel  button=ok  /  need=self_report unlock  /  ok  remove=mazel  button=gone  /  tools=locked  mazel_find=0
mix install_second_brain_remove_demo # ok  add=mazel  /  need unlock  /  paste=grok|hermes snippet=ok  /  remove=mazel  /  tools=locked  mazel_find=0
mix install_remove_clears_brains_demo # ok  add=mazel  /  paste=grok|hermes  /  brains=grok,hermes  /  need unlock  /  remove=mazel  /  tools=locked  /  brains=
mix install_remove_without_add_demo # error  add=none  tools=locked  /  ok  remove=mazel  noop=true  /  tools=locked  mazel_find=0  /  ok  crash=none
mix install_remove_twice_demo     # ok  add=mazel  button=ok  /  need unlock  /  remove=mazel  button=gone  /  tools=locked  /  remove=mazel  noop=true  /  tools=locked  /  crash=none
mix install_readd_after_remove_demo # ok  add=mazel  button=ok  /  need unlock  /  remove=mazel  button=gone  /  tools=locked  /  add=mazel  button=ok  /  tools=unlocked
mix install_paste_brains_demo     # ok  add=mazel  button=ok  /  paste=cursor|grok|hermes|muse  snippet=ok  /  error  paste=unknown  unsupported_brain
mix install_paste_unknown_unlocked_demo # ok  add=mazel  button=ok  /  need=self_report  /  tools=unlocked  mazel_find=1  /  error  paste=unknown  unsupported_brain  /  tools=unlocked
mix install_paste_unknown_brains_stay_demo # ok  add=mazel  button=ok  /  paste=grok  /  brains=grok  /  need unlock  /  error  paste=unknown  unsupported_brain  /  brains=grok  /  tools=unlocked  /  crash=none
mix install_paste_blank_demo      # ok  add=mazel  button=ok  /  paste=grok  /  brains=grok  /  need unlock  /  error  paste=  blank_brain  /  brains=grok  /  tools=unlocked  /  crash=none
mix install_paste_whitespace_demo # ok  add=mazel  button=ok  /  paste=grok  /  brains=grok  /  need unlock  /  error  paste=   blank_brain  whitespace=true  /  brains=grok  /  tools=unlocked  /  crash=none
mix install_paste_without_add_demo # error  add=none  tools=locked  mazel_find=0  /  paste=grok|cursor  error=add_required  /  tools=locked
mix install_add_then_paste_demo   # ok  add=mazel  button=ok  /  paste=grok  snippet=ok  /  need=self_report  /  tools=unlocked  mazel_find=1
mix install_add_paste_find_demo   # ok  add=mazel  button=ok  /  paste=grok  snippet=ok  /  need=self_report  /  tools=unlocked  mazel_find=1  /  find=series-a→kai  mazel'd
mix install_add_paste_find_mcp_demo # ok  add=mazel  button=ok  /  paste=grok  snippet=ok  /  need=self_report  /  tools=unlocked  mazel_find=1  /  mcp=mazel_find  query=series-a→kai
mix install_add_mazel_pack_demo   # ok  pack=add_mazel  kind=readme  /  steps=add→paste→find→direct  /  add=mazel  paste=ready  /  find=…→kai  mazel'd  /  direct=@kai  session=ready
mix install_add_mazel_skill_demo  # ok  skill=add_mazel  mix_user_lane=no  /  steps=add→paste→find→direct  /  add=mazel  paste=ready  /  find=…→kai  mazel'd  /  direct=@kai  session=ready
mix install_add_mazel_skill_readd_demo # ok  skill=add_mazel  first=ok  /  second=idempotent  /  tools=unlocked  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no
mix install_add_mazel_skill_from_url_demo # ok  skill=add_mazel  from=path  /  install=friend_handable  mix_user_lane=no  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready
mix install_add_mazel_friend_paste_demo # ok  paste=friend  kind=mcp  /  --- paste ---  {mcpServers…}  --- end ---  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no  /  harness_only=no
mix install_add_mazel_skill_paste_demo # ok  paste=friend  kind=skill  /  --- paste ---  # Add Mazel …  --- end ---  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no
mix install_add_mazel_skill_friend_try_demo # ok  onramp=skill  friend=try  /  paste=friend  kind=skill  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no  /  public_host=none
mix install_add_mazel_skill_friend_try_second_brain_demo # ok  onramp=skill  friend=try  /  brains=grok,hermes  wipe=none  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no  /  public_host=none
mix install_add_mazel_skill_friend_try_coexist_demo # ok  onramp=skill  friend=try  /  coexist=yes  wipe=none  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no  /  public_host=none
mix install_add_mazel_skill_friend_try_unpaste_one_demo # ok  onramp=skill  friend=try  /  brains=hermes  unpaste=one  /  skill=stay  mcp=stay  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no  /  public_host=none
mix install_add_mazel_skill_friend_try_readd_after_remove_demo # ok  onramp=skill  friend=try  /  remove=mazel  /  readd=friend_try  recover=yes  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no  /  public_host=none
mix install_add_mazel_skill_friend_try_no_checkout_demo # ok  onramp=skill  friend=try  /  checkout=none  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no  /  public_host=none
mix install_add_mazel_mcp_friend_try_no_checkout_demo # ok  onramp=mcp  friend=try  /  checkout=none  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no  /  public_host=none
mix install_add_mazel_friend_try_dual_portable_demo # ok  onramp=dual  friend=try  /  skill=portable  mcp=portable  /  checkout=none  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no  /  public_host=none
mix install_add_mazel_friend_try_dual_portable_mix_path_demo # error  mix=missing  clear_error=yes  /  ok  mix=on_path  /  onramp=dual  friend=try  /  skill=portable  mcp=portable  /  checkout=none  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no  /  public_host=none
mix install_add_mazel_friend_try_dual_portable_friend_mix_path_demo # ok  onramp=dual  friend=try  /  skill=portable  mcp=portable  /  checkout=none  /  mix=on_path  friend=machine  /  error  public_host=none  /  live_host_ready=no
mix install_add_mazel_friend_mix_on_path_demo # ok  handoff=friend  portable=yes  /  checkout=none  /  mix=on_path  /  steps=add→paste→find→direct  /  add=mazel  paste=ready  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  error  public_host=none  /  live_host_ready=no  /  mix_user_lane=no
mix install_add_mazel_friend_paste_door_demo # ok  mix=on_path  handoff=friend  /  add=dual_portable  skill+mcp  checkout=none  /  need=self_report  /  find=series-a→kai  mazel'd  /  direct=@kai  session=ready  /  error  public_host=none  /  live_host_ready=no  /  mix_user_lane=no
mix install_add_mazel_friend_share_paste_door_demo # ok  share=sendable  paste_door=yes  /  mix=on_path  handoff=friend  /  add=dual_portable  skill+mcp  checkout=none  /  need=self_report  /  find=series-a→kai  mazel'd  /  direct=@kai  session=ready  /  error  public_host=none  /  live_host_ready=no  /  mix_user_lane=no
mix install_add_mazel_friend_first_drop_demo # ok  first_drop=yes  bullets=3..5  /  share=sendable  paste_into_ai=yes  /  mix=on_path  handoff=friend  /  add=dual_portable  skill+mcp  checkout=none  /  need=self_report  /  find=series-a→kai  mazel'd  /  direct=@kai  session=ready  /  error  public_host=none  /  live_host_ready=no  /  mix_user_lane=no
mix install_add_mazel_friend_try_dual_portable_second_brain_demo # ok  onramp=dual  friend=try  /  skill=portable  mcp=portable  /  checkout=none  /  brains=grok,hermes  wipe=none  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no  /  public_host=none
mix install_add_mazel_friend_try_dual_portable_unpaste_one_demo # ok  onramp=dual  friend=try  /  skill=portable  mcp=portable  /  checkout=none  /  brains=hermes  unpaste=one  /  skill=stay  mcp=stay  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no  /  public_host=none
mix install_add_mazel_friend_try_dual_portable_repaste_demo # ok  onramp=dual  friend=try  /  skill=portable  mcp=portable  /  checkout=none  /  brains=hermes  unpaste=one  /  repaste=grok  recover=yes  /  skill=stay  mcp=stay  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no  /  public_host=none
mix install_add_mazel_friend_try_dual_portable_unpaste_both_demo # ok  onramp=dual  friend=try  /  skill=portable  mcp=portable  /  checkout=none  /  unpaste=both  recover=yes  /  brains=grok,hermes  /  skill=stay  mcp=stay  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no  /  public_host=none
mix install_add_mazel_friend_path_handoff_demo # ok  handoff=friend  mix=on_path  /  checkout=none  harness=none  /  onramp=mcp  friend=try  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no  /  public_host=none
mix install_add_mazel_friend_path_handoff_skill_demo # ok  handoff=friend  mix=on_path  /  checkout=none  harness=none  /  onramp=skill  friend=try  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no  /  public_host=none
mix install_add_mazel_friend_path_handoff_dual_demo # ok  handoff=friend  mix=on_path  /  checkout=none  harness=none  /  onramp=dual  skill=portable  mcp=portable  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no  /  public_host=none
mix install_add_mazel_friend_path_live_ready_demo # ok  handoff=friend  live_ready=yes  /  block=sendable  one_block=yes  /  mix=missing  clear_error=yes  /  mix=on_path  /  checkout=none  harness=none  /  onramp=dual  skill=portable  mcp=portable  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no  /  public_host=none
mix install_add_mazel_friend_share_object_demo # ok  handoff=friend  share=object  /  block=sendable  paste_into_ai=yes  /  checkout=none  harness=none  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no  /  public_host=none
mix install_add_mazel_friend_share_in_tree_demo # ok  handoff=friend  share=in_tree  /  block=sendable  path=.cursor/add-mazel-share.md  /  in_tree=yes  /  checkout=none  harness=none  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no  /  public_host=none
mix install_add_mazel_friend_public_host_ready_demo # ok  handoff=friend  share=in_tree  /  in_tree=yes  /  error  public_host=none  /  ok  live_host_ready=no  /  checkout=none  harness=none  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no
mix install_add_mazel_friend_live_host_step_demo # ok  handoff=friend  share=in_tree  /  in_tree=yes  /  error  public_host=none  /  ok  live_host_ready=no  /  ok  next=public_https  /  checkout=none  harness=none  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no
mix install_add_mazel_friend_public_host_reachable_demo # ok  handoff=friend  share=in_tree  /  in_tree=yes  /  error  public_host=none  /  ok  live_host_ready=no  /  error  invented=refused  /  error  reachable=none  /  checkout=none  harness=none  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no
mix install_add_mazel_skill_friend_try_both_stay_demo # ok  onramp=skill  friend=try  /  paste=friend  kind=skill  /  paste=grok  /  paste=hermes  /  brains=grok,hermes  wipe=none  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no  /  public_host=none
mix install_add_mazel_skill_friend_try_readd_demo # ok  onramp=skill  friend=try  /  add=mazel  first=ok  /  add=mazel  second=idempotent  /  brains=grok  wipe=none  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no  /  public_host=none
mix install_add_mazel_skill_from_https_demo # ok  skill=add_mazel  from=url_fixture  /  error  live_https=none  /  install=friend_handable  mix_user_lane=no  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready
mix install_add_mazel_skill_bad_url_demo # error  skill=add_mazel  from=https  reason=404  /  from=file  reason=non_https  /  clear_error=yes  mix_user_lane=no  /  sibling=from_path  green
mix install_add_mazel_skill_bad_url_then_path_demo # error  skill=add_mazel  from=https  reason=404  /  clear_error=yes  /  retry=from_path  friend_handable  /  steps=add→paste→find→direct  /  find=…→kai  mazel'd  /  direct=@kai  session=ready  /  mix_user_lane=no
mix install_add_mazel_skill_missing_path_demo # error  skill=add_mazel  from=path  reason=missing  /  clear_error=yes  mix_user_lane=no  /  sibling=from_path  green
mix install_add_mazel_skill_corrupt_path_demo # error  skill=add_mazel  from=path  reason=empty  /  reason=corrupt  /  clear_error=yes  mix_user_lane=no  /  sibling=from_path  green
mix install_add_mazel_tool_demo   # ok  tool=add_mazel  mix_user_lane=no  /  steps=add→paste→find→direct  /  add=mazel  paste=ready  /  find=…→kai  mazel'd  /  direct=@kai  session=ready
mix install_paste_after_remove_demo # ok  add=mazel  /  paste=grok  snippet=ok  /  tools=unlocked  /  remove=mazel  /  paste=grok  error=add_required  /  tools=locked
mix install_paste_full_cycle_demo # ok  add=mazel  /  paste=grok  snippet=ok  /  tools=unlocked  /  remove=mazel  /  tools=locked  /  add=mazel  /  paste=hermes  snippet=ok  /  tools=unlocked
mix install_paste_both_stay_demo  # ok  add=mazel  button=ok  /  paste=grok  /  paste=hermes  /  brains=grok,hermes  wipe=none  /  need=self_report  /  tools=unlocked
mix install_paste_same_twice_demo # ok  add=mazel  button=ok  /  paste=grok  snippet=ok  /  paste=grok  idempotent=true  /  brains=grok  count=1  /  need=self_report  /  tools=unlocked
mix install_unpaste_one_demo      # ok  add=mazel  button=ok  /  paste=grok  /  paste=hermes  /  brains=grok,hermes  /  need unlock  /  unpaste=grok  /  brains=hermes  /  tools=unlocked
mix install_unpaste_last_demo     # ok  add=mazel  button=ok  /  paste=grok  /  brains=grok  /  need unlock  /  unpaste=grok  /  brains=  /  tools=unlocked  /  add=mazel
mix install_repaste_after_empty_demo # ok  add=mazel  button=ok  /  paste=grok  /  need unlock  /  unpaste=grok  /  brains=  /  tools=unlocked  /  paste=hermes  /  brains=hermes  /  tools=unlocked
mix install_unpaste_missing_demo  # ok  add=mazel  button=ok  /  paste=grok  /  brains=grok  /  need unlock  /  unpaste=hermes  noop=true  /  brains=grok  /  tools=unlocked  /  crash=none
mix install_unpaste_twice_demo    # ok  add=mazel  button=ok  /  paste=grok  /  paste=hermes  /  brains=grok,hermes  /  need unlock  /  unpaste=grok  /  brains=hermes  /  unpaste=grok  noop=true  /  brains=hermes  /  tools=unlocked  /  crash=none
mix install_swiss_demo            # ok  brain=cursor|grok|hermes|muse  add=mazel  tools=ready  /  error  brain=claude|openai  add=none  not_swiss
mix toolbelt_demo                 # ok  has=1 → mazel ready  /  need=1 → mazel ready  /  Mazel is ready.
mix toolbelt_ready_demo           # error  empty  mcp=not_ready  /  ok  has=1|need=1  mcp=mazel_find  /  mcp=mazel_wing  /  paste=cursor|grok|hermes|muse
mix http_demo                     # curl /v0 resolve + wing (direct+intro) + badge
mix a2a_demo                      # HAAH cards (ariel + kai) → POST /a2a task stub
mix dns_demo                      # TXT fixture → Room.Cards (kai/ariel, no live DNS)
mix resolve_live_demo             # TXT → card → mazel'd (zone as live resolver)
mix resolve_harden_demo           # ok  resolve=kai.mazel.ai  haah=1  /  error  ghost no_txt  /  plain no_card
mix card_well_known_demo          # ok  well-known=/.well-known/agent-card.json  protocol=haah  /  mazel'd @kai  /  ghost unknown_handle
mix a2a_card_demo                 # ok  a2a  well-known=/.well-known/agent-card.json  /  handle=kai@mazel  card_url=…/agent-card.json  /  ghost unknown_handle
mix a2a_card_skills_demo          # ok  a2a  card=kai@mazel  skills=find,direct  /  skill=find  /  skill=direct  /  ghost unknown_handle
mix a2a_resolve_demo              # ok  a2a  resolve=kai@mazel  via=well-known  /  card_url=…/agent-card.json  /  ghost unknown_handle
mix a2a_buddy_card_demo           # ok  a2a  buddy_card=template  well-known=/.well-known/agent-card.json  /  resolve=kai@mazel|buddy@mazel  card_url=…/agent-card.json  /  friend2=host_or_paste
mix a2a_friend_handoff_card_paste_demo # ok  handoff=friend  /  a2a  buddy_card=paste  well-known=/.well-known/agent-card.json  /  resolve=buddy@mazel  via=paste  card_url=…/agent-card.json  /  friend2=paste  /  public_host=none
mix a2a_friend_handoff_card_paste_talk_badge_demo # ok  handoff=friend  /  a2a  buddy_card=paste  well-known=/.well-known/agent-card.json  /  resolve=buddy@mazel  via=paste  card_url=…/agent-card.json  /  friend2=paste  /  public_host=none  /  direct=@buddy  session=agent  morph=none  /  talk=send  status=ok  /  morph=denied  badge=none  /  badge=mint  /  morph=ok  join=ok
mix a2a_friend_handoff_card_paste_talk_badge_return_demo # ok  handoff=friend  /  a2a  buddy_card=paste  well-known=/.well-known/agent-card.json  /  resolve=buddy@mazel  via=paste  card_url=…/agent-card.json  /  friend2=paste  /  public_host=none  /  direct=@buddy  session=agent  morph=none  /  talk=send  status=ok  /  morph=denied  badge=none  /  badge=mint  /  morph=ok  join=ok  /  return=agent  same=true  /  talk=send  status=ok  after=return
mix a2a_friend_handoff_card_live_resolve_demo # ok  handoff=friend  /  error  resolve=buddy@mazel  via=well-known  error=card_offline  /  error  resolve=buddy@mazel  via=dns_txt  error=no_txt  /  friend2=live  /  public_host=none  /  hang=false
mix a2a_friend_handoff_card_live_ok_demo # ok  handoff=friend  /  resolve=buddy@mazel  via=well-known  card_url=…/agent-card.json  /  friend2=live  /  public_host=none  /  fixture=local
mix a2a_friend_handoff_card_live_ok_talk_demo # ok  handoff=friend  /  resolve=buddy@mazel  via=well-known  card_url=…/agent-card.json  /  friend2=live  /  public_host=none  /  fixture=local  /  direct=@buddy  session=agent  morph=none  /  talk=send  status=ok
mix a2a_friend_handoff_card_live_ok_talk_need_have_demo # ok  handoff=friend  /  resolve=buddy@mazel  via=well-known  /  friend2=live  /  public_host=none  /  fixture=local  /  card_need=series-a  card_have=direct  /  direct=@buddy  session=agent  morph=none  /  talk=send  status=ok  /  session_need=series-a  session_have=direct
mix a2a_friend_handoff_card_paste_door_need_have_demo # ok  mix=on_path  handoff=friend  /  onramp=dual  skill=portable  mcp=portable  /  checkout=none  public_host=none  /  resolve=buddy@mazel  via=paste  /  friend2=paste  /  card_need=series-a  card_have=direct  /  direct=@buddy  session=agent  morph=none  /  talk=send  status=ok  /  session_need=series-a  session_have=direct  /  live_host_ready=no
mix a2a_friend_handoff_card_live_ok_talk_need_have_return_demo # ok  handoff=friend  /  resolve=buddy@mazel  via=well-known  /  friend2=live  /  public_host=none  /  fixture=local  /  card_need=series-a  card_have=direct  /  direct=@buddy  session=agent  morph=none  /  talk=send  status=ok  /  session_need=series-a  session_have=direct  /  return=agent  same=true  /  session_need=series-a  session_have=direct  after=return  /  session=agent
mix a2a_friend_handoff_card_live_ok_talk_return_demo # ok  handoff=friend  /  resolve=buddy@mazel  via=well-known  card_url=…/agent-card.json  /  friend2=live  /  public_host=none  /  fixture=local  /  direct=@buddy  session=agent  morph=none  /  talk=send  status=ok  /  return=agent  same=true  /  session=agent
mix a2a_friend_handoff_card_public_host_demo # ok  handoff=friend  /  error  resolve=buddy@mazel  via=public_host  error=host_none  /  hang=false  /  resolve=buddy@mazel  via=well-known  public_host=set  card_url=https://fixture.host/.well-known/agent-card.json  /  friend2=live
mix a2a_buddy_direct_talk_demo    # ok  a2a  buddy_card=template  /  resolve=kai@mazel|buddy@mazel  card_url=…/agent-card.json  /  direct=@buddy  session=agent  morph=none  /  talk=send  status=ok
mix a2a_buddy_direct_offline_demo # ok  a2a  buddy_card=template  /  resolve=kai@mazel  card_url=…  /  error  resolve=buddy@mazel  error=card_offline  /  direct=none  talk=none  /  hang=false
mix a2a_buddy_direct_badge_morph_demo # ok  a2a  buddy_card=template  /  resolve=kai@mazel|buddy@mazel  card_url=…/agent-card.json  /  direct=@buddy  session=agent  morph=none  /  talk=send  status=ok  /  morph=denied  badge=none  /  badge=mint  /  morph=ok  join=ok
mix a2a_buddy_host_direct_talk_demo # ok  a2a  buddy_card=hosted  well-known=/.well-known/agent-card.json  /  resolve=kai@mazel|buddy@mazel  via=well-known  card_url=…/agent-card.json  /  friend2=hosted  /  direct=@buddy  session=agent  morph=none  /  talk=send  status=ok
mix a2a_dual_portable_host_talk_demo # ok  onramp=dual  skill=portable  mcp=portable  /  checkout=none  public_host=none  /  a2a  buddy_card=hosted  well-known=/.well-known/agent-card.json  /  resolve=kai@mazel  via=well-known  /  resolve=buddy@mazel  via=well-known  /  friend2=hosted  /  direct=@buddy  session=agent  morph=none  /  talk=send  status=ok
mix a2a_dual_portable_host_badge_morph_demo # ok  onramp=dual  skill=portable  mcp=portable  /  checkout=none  public_host=none  /  a2a  buddy_card=hosted  well-known=/.well-known/agent-card.json  /  resolve=kai@mazel  via=well-known  /  resolve=buddy@mazel  via=well-known  /  friend2=hosted  /  direct=@buddy  session=agent  morph=none  /  talk=send  status=ok  /  morph=denied  badge=none  /  badge=mint  /  morph=ok  join=ok
mix a2a_dual_portable_host_talk_return_demo # ok  onramp=dual  skill=portable  mcp=portable  /  checkout=none  public_host=none  /  a2a  buddy_card=hosted  well-known=/.well-known/agent-card.json  /  resolve=kai@mazel  via=well-known  /  resolve=buddy@mazel  via=well-known  /  friend2=hosted  /  direct=@buddy  session=agent  morph=none  /  talk=send  status=ok  /  return=agent  same=true  /  morph=denied  badge=none  /  session=agent
mix a2a_dual_portable_host_badge_return_demo # ok  onramp=dual  skill=portable  mcp=portable  /  checkout=none  public_host=none  /  a2a  buddy_card=hosted  well-known=/.well-known/agent-card.json  /  resolve=kai@mazel  via=well-known  /  resolve=buddy@mazel  via=well-known  /  friend2=hosted  /  direct=@buddy  session=agent  morph=none  /  talk=send  status=ok  /  morph=denied  badge=none  /  badge=mint  /  morph=ok  join=ok  /  return=agent  same=true  /  talk=send  status=ok  after=return
mix a2a_buddy_host_badge_morph_demo # ok  a2a  buddy_card=hosted  well-known=/.well-known/agent-card.json  /  resolve=kai@mazel|buddy@mazel  via=well-known  card_url=…/agent-card.json  /  friend2=hosted  /  direct=@buddy  session=agent  morph=none  /  talk=send  status=ok  /  morph=denied  badge=none  /  badge=mint  /  morph=ok  join=ok
mix a2a_buddy_host_badge_return_demo # ok  a2a  buddy_card=hosted  well-known=/.well-known/agent-card.json  /  resolve=kai@mazel|buddy@mazel  via=well-known  card_url=…/agent-card.json  /  friend2=hosted  /  direct=@buddy  session=agent  morph=none  /  talk=send  status=ok  /  morph=denied  badge=none  /  badge=mint  /  morph=ok  join=ok  /  return=agent  same=true  /  talk=send  status=ok  after=return
mix a2a_two_handle_direct_demo    # ok  a2a  resolve=kai@mazel|nova@mazel  card_url=…/agent-card.json  /  mazel'd @kai  /  direct=@kai  session=agent  morph=none
mix a2a_direct_talk_demo          # ok  a2a  resolve=kai@mazel  card_url=…/agent-card.json  /  direct=@kai  session=agent  morph=none  /  talk=send  status=ok
mix a2a_direct_talk_no_badge_demo # ok  a2a  resolve=kai@mazel  card_url=…/agent-card.json  /  direct=@kai  session=agent  morph=none  /  talk=send  status=ok  /  morph=denied  badge=none
mix a2a_direct_talk_badge_morph_demo # ok  a2a  resolve=kai@mazel  card_url=…/agent-card.json  /  direct=@kai  session=agent  morph=none  /  talk=send  status=ok  /  badge=mint  /  morph=ok  join=ok
mix a2a_direct_card_404_demo      # error  a2a  resolve=gone@mazel  card_url=…  error=card_404  /  direct=none  /  hang=false
mix a2a_direct_card_bad_json_demo # error  a2a  resolve=junk@mazel  card_url=…  error=bad_json  /  direct=none  /  hang=false
mix a2a_direct_card_no_url_demo   # error  a2a  resolve=nourl@mazel  card_url=…  error=no_url  /  direct=none  /  hang=false
mix a2a_resolve_dns_demo          # ok  a2a  resolve=kai@mazel  via=dns_txt  /  card_url=…/agent-card.json  /  ghost no_txt
mix a2a_task_demo                 # ok  a2a  resolve=kai@mazel  card_url=…/agent-card.json  /  task=send  to=card_url  status=ok  /  ghost unknown_handle task=none
mix a2a_task_dns_miss_demo        # error  a2a  resolve=@ghost  via=dns_txt  error=no_txt  /  task=none
mix a2a_task_dns_demo             # ok  a2a  resolve=kai@mazel  via=dns_txt  /  card_url=…/agent-card.json  /  task=send  to=card_url  status=ok
mix a2a_task_card_404_demo        # error  a2a  resolve=gone@mazel  card_url=…  error=card_404  /  task=none
mix a2a_task_card_bad_json_demo   # error  a2a  resolve=junk@mazel  card_url=…  error=bad_json  /  task=none
mix a2a_task_card_no_url_demo     # error  a2a  resolve=nourl@mazel  card_url=…  error=no_url  /  task=none
mix a2a_task_card_empty_url_demo  # error  a2a  resolve=blankurl@mazel  card_url=…  error=empty_url  /  task=none
mix a2a_task_card_ws_url_demo     # error  a2a  resolve=wsurl@mazel  card_url=…  error=empty_url  /  task=none
mix a2a_task_card_pad_url_demo    # ok  a2a  resolve=padurl@mazel  card_url=…/agent-card.json  trimmed=true  /  task=send  to=card_url  status=ok
mix a2a_task_card_bad_scheme_demo # error  a2a  resolve=relurl@mazel  card_url=/agent-card.json  error=bad_scheme  /  task=none
mix a2a_task_card_ftp_url_demo    # error  a2a  resolve=ftpurl@mazel  card_url=ftp://host/card.json  error=bad_scheme  /  task=none
mix a2a_task_card_file_url_demo   # error  a2a  resolve=fileurl@mazel  card_url=file:///tmp/card.json  error=bad_scheme  /  task=none
mix a2a_skills_url_demo           # ok  a2a  resolve=kai@mazel  card_url=…/agent-card.json  /  skills_from_url=find,direct  /  ghost unknown_handle skills=none
mix a2a_skills_url_miss_demo      # error  resolve=@ghost  unknown_handle  skills=none  fetch=none  /  ok  a2a  resolve=kai@mazel  skills_from_url=find,direct
mix a2a_skills_empty_demo         # ok  a2a  resolve=empty@mazel  card_url=…/agent-card.json  /  skills_from_url=none  /  crash=false
mix a2a_skills_missing_key_demo   # ok  a2a  resolve=emptyarr@mazel  skills=[]  skills_from_url=none  /  resolve=noskills@mazel  skills=missing  skills_from_url=none  /  crash=false
mix a2a_skills_null_demo          # ok  a2a  resolve=nullskills@mazel  skills=null  skills_from_url=none  /  crash=false
mix a2a_skills_string_demo        # error  a2a  resolve=strskills@mazel  skills=string  error=bad_skills  /  crash=false
mix a2a_skills_number_demo        # error  a2a  resolve=numskills@mazel  skills=number  error=bad_skills  /  crash=false
mix a2a_skills_object_demo        # error  a2a  resolve=objskills@mazel  skills=object  error=bad_skills  /  crash=false
mix a2a_skills_mixed_demo         # error  a2a  resolve=mixedskills@mazel  skills=mixed  error=bad_skills  /  crash=false
mix a2a_task_empty_skills_demo    # ok  a2a  resolve=empty@mazel  card_url=…/agent-card.json  /  skills_from_url=none  /  task=send  to=card_url  status=ok
mix a2a_task_rpc_error_demo       # ok  a2a  resolve=rpcerr@mazel  card_url=…/agent-card.json  /  task=send  to=card_url  status=error  /  crash=false
mix resolve_card_demo             # ok  txt=kai.mazel.ai  haah=1  /  well-known  protocol=haah  /  mazel'd @kai  /  ghost no_txt
mix human_demo                    # one human through their agent; cards/*.json
mix secrets_demo                  # ok  vault=dotenvx  loaded=true  /  keys masked
mix warm_packet_demo              # ok  morph=morph.commit  /  warm from/why/opener/consent/return
mix return_demo                   # ok  return=agent  morph=closed  session=agent
mix intro_demo                    # ok  kind=intro  wing=🪽🪽  /  morph.commit  consent=dual
mix intro_e2e_demo                # ok  kind=intro  wing=🪽🪽  handle=kai@mazel  /  mint=vouch  /  morph.commit  /  return
mix group_demo                    # ok  kind=group  wing=🪽🪽🪽  /  morph.commit  consent=dual
mix group_e2e_demo                # ok  kind=group  wing=🪽🪽🪽  handles=…  /  mint=invite  /  morph.commit  /  return
mix vouch_demo                    # ok  vouch=ariel→kai  heat=has  /  error  vouch=self
mix self_vouch_demo               # ok=false error=self_vouch
mix self_mint_demo                # error  mint=self  /  mint=invite  /  mint=pull_match  /  vouch=self  /  other vouch
mix pow_mint_demo                 # ok  mint=pow  badge=proof_of_work  /  morph.commit  consent=dual  /  error  mint=self
mix postage_sources_demo          # ok  mint=invite  /  pull_match  /  vouch from=ariel→kai  /  pow  /  error  mint=self
mix badge_demo                    # ok  talk=free  /  mint=pull_match  /  morph=morph.commit
mix soft_no_demo                  # ok  stamp=none  agent=soft_no  human=asleep  /  talk=free  /  stamp=pull_match  human=wake_ok
mix talk_no_morph_demo            # ok  talk=free  stamp=none  /  error  morph=denied  /  stamp=pull_match  /  morph.commit
mix talk_return_demo              # ok  talk=free  stamp=none  /  morph=denied  /  morph.commit  /  return=agent
mix talk_warm_demo                # ok  talk=free  stamp=none  /  morph.commit  /  warm from/why/opener  /  return=agent
mix consent_soft_no_demo          # ok  stamp=pull_match  consent=one  agent=soft_no  human=asleep  /  morph=denied  /  consent=both  human=wake_ok
mix consent_demo                  # error  consent=one  morph=dual_consent_required  /  ok  consent=both  morph=morph.commit
mix dual_consent_demo             # same LOOK: one-sided consent cannot commit; both → morph.commit
mix pull_mint_demo                # ok  find=series-a→kai  mazel'd  /  mint=pull_match  /  morph.commit
mix warm_pull_demo                # find → mint → morph.commit + warm from/why/opener/consent/return
mix return_pull_demo              # find → mint → morph → warm → ok  return=agent  morph=closed
mix invite_demo                   # ok  mint=invite  badge=invite_token  /  morph.commit  /  error  vouch=self
mix invite_direct_demo            # ok  verb=mazel  kind=direct  /  mint=invite  /  morph.commit
mix has_demo                      # URL in → Has bullets out
mix profile_seed_demo             # ok  url=… →curious  /  has=[] / curious=[…]  /  +trail →has
mix wiki_slice_demo               # ok  promote=curious→has  peer=kai@mazel  /  wiki=people/kai.md  written=true
mix need_wiki_demo                # ok  cast=need  id=icp_pain  /  wiki=needs/icp_pain.md  written=true
mix wiki_jit_demo                 # ok  wiki=people/kai.md  read=true  /  wiki=needs/…  read=true  /  need×has  from=wiki
mix has_gh_demo                   # GH fixture trail → Has; resume-only→curious
mix gh_rank_demo                  # ok  find=chat  trail=0  /  gh+check→has  trail=1  /  kai lifts
mix has_pdf_demo                  # PDF resume-only→curious; gh+check→has
mix resume_demo                   # resume-only→curious; gh+check→has
mix upload_check_demo             # ok  upload=candidate  /  check=resume_only|claim|conflict→curious  /  aligned→has
mix mvp_demo                      # match both reasons: found who I needed / they needed what I have
mix mvp_find_demo                 # ok  find=series-a→kai  mazel'd  /  need×has  inputs={…}  /  why  /  claim→curious
mix agent_complete_demo           # ok  find=series-a→kai  mazel'd  /  need×has  check=pass  /  why  /  complete=agent  morph=none  /  claim→curious
mix agent_complete_ttl_demo       # ok  find=series-a→kai  mazel'd  /  need×has  check=pass  need_ttl=fresh  /  complete=agent  /  expired
mix agent_complete_shape_demo     # ok  find=impl→nova  mazel'd  /  need×has  shape=icp_pain  check=pass  /  complete=agent  /  vibe→curious
mix agent_complete_why_demo       # ok  find=impl→nova  mazel'd  /  shape=icp_pain  /  why  need=  /  why  has=  /  complete=agent  /  vibe
mix agent_complete_check_demo     # ok  find=series-a→kai  mazel'd  /  check=pass  complete=agent  /  claim|contradict mazel'd=none
mix agent_complete_score_demo     # ok  find=series-a→kai  mazel'd  /  need×has  inputs={…trail,check}  score=  /  complete=agent  /  claim
mix agent_complete_why_score_demo # ok  find=series-a→kai  mazel'd  /  inputs={…}  score=  /  why  need=  /  why  has=  /  complete=agent  /  claim
mix agent_complete_toolbelt_demo  # ok  has=1  mcp=mazel_find  /  mcp=mazel_wing  mazel'd  /  complete=agent  /  claim mcp=none
mix agent_complete_toolbelt_need_demo # ok  need=1  mcp=mazel_find  /  mcp=mazel_wing  mazel'd  /  complete=agent  /  claim mcp=none
mix agent_complete_toolbelt_curious_demo # error  curious=1  mcp=not_ready  /  claim→curious  mcp=none  /  complete=agent
mix agent_complete_toolbelt_expired_demo # error  need_ttl=expired  mcp=not_ready  /  unfit mcp=none  /  complete=agent
mix agent_complete_toolbelt_stale_has_demo # ok  has=1  age=stale  mcp=mazel_find  /  mcp=mazel_wing  mazel'd  /  complete=agent  /  claim mcp=none
mix pdf_has_demo                  # ok  pdf=resume  text=claim  →curious  /  pdf=artifact  aligned→has  /  conflict→curious
mix pdf_wiki_demo                 # ok  promote=pdf→has  peer=kai@mazel  /  wiki=people/kai.md  written=true  proof=kai.resume.pdf  /  claim|conflict wiki=none
mix github_wiki_demo              # ok  promote=gh→has  peer=kai@mazel  /  wiki=people/kai.md  written=true  proof=kai.github.txt  /  resume|claim wiki=none
mix github_wiki_find_demo         # ok  find=series-a→kai@mazel  proof=kai.github.txt  /  wiki=people/kai.md  from=gh  /  resume|claim find=none
mix github_wiki_score_demo        # ok  find=series-a→kai  proof=kai.github.txt  /  from=gh  inputs={fit,heat,fresh}  score=  /  resume|claim find=none
mix pdf_wiki_find_demo            # ok  find=series-a→kai@mazel  proof=kai.resume.pdf  /  wiki=people/kai.md  from=pdf  /  claim|conflict find=none
mix pdf_wiki_score_demo           # ok  find=series-a→kai  proof=kai.resume.pdf  /  from=pdf  inputs={fit,heat,fresh}  score=  /  claim|conflict find=none
mix pdf_wiki_why_demo             # ok  find=series-a→kai  proof=kai.resume.pdf  /  why  need=  /  why  has=  /  claim|conflict find=none
mix morph_escape_demo             # ok  complete=agent  morph=none  /  escape=human  stamp=none  soft_no  /  stamp+dual morph + return
mix morph_escape_why_demo         # ok  complete=agent  /  escape=human  /  morph + warm + return  /  why  return=
mix morph_escape_invite_demo      # ok  complete=agent  /  escape=human  stamp=none  soft_no  /  stamp=invite  /  morph + return
mix morph_escape_vouch_demo       # ok  complete=agent  /  escape=human  stamp=none  soft_no  /  stamp=vouch  /  morph + return
mix morph_escape_pow_demo         # ok  complete=agent  /  escape=human  stamp=none  soft_no  /  stamp=pow  /  morph + return
mix morph_escape_one_consent_demo # ok  complete=agent  /  escape=human  stamp=pull_match  consent=one  /  morph=denied  soft_no
mix mazel has --gh priv/fixtures/kai.github.txt @kai
mix mazel has --resume priv/fixtures/kai.resume.conflict.txt @kai
mix find_demo                     # find series-a→kai vs impl→nova, then mazel'd
mix heat_demo                     # find=chat without=[ariel,kai,nova] / with=[kai,…] heat lifts
mix gmail_heat_demo               # ok  gmail=edge  heat=1  /  prior=gmail  /  no_connector  heat=0
mix heat_compose_demo             # ok  heat=vouch  /  heat=gmail  /  heat=vouch+gmail  /  heat=0
mix ready_demo                    # ready LOOK (in-agent path)
mix v1_demo                       # find → mazel'd @kai / @nova

mix mazel has @kai
mix mazel find series-a
mix mazel @kai hello
mix mazel intro @kai series-A CTO
mix mazel need series-A CTO

# A2A gateway (room up: PORT=4747 mix run --no-halt)
curl -sS http://127.0.0.1:4747/.well-known/agent-card.json
curl -sS 'http://127.0.0.1:4747/v0/card?handle=kai'
curl -sS -X POST http://127.0.0.1:4747/a2a -H 'content-type: application/json' \
  -d '{"text":"mazel @kai hello"}'

# card vault: docs/SECRETS.md
dotenvx set MAZEL_CARD_KAI -- cards/kai.json && dotenvx encrypt
dotenvx run -- mix human_demo
dotenvx run -- mix secrets_demo

./demo/smoke.sh
# or: mix test_demo
./demo/run.sh                     # adds cargo tests
```


