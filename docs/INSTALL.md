# Add Mazel

Paste this MCP config into Cursor Settings → MCP, or project `.cursor/mcp.json`. Or a connector click.

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

Same file in-repo: [`.cursor/mcp.json.example`](../.cursor/mcp.json.example)

Mazel is ready.

Then find → chat. In the wing: `mazel_find`, then `mazel_wing`.

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

## Grok, Hermes, Muse

Same stdio MCP. No Anthropic. No OpenAI. Paste into that brain, then find → chat.

Grok — `.grok/config.toml` or `~/.grok/config.toml`:

```toml
[mcp_servers.mazel]
command = "mix"
args = ["mcp"]
cwd = "/absolute/path/to/mazel/apps/room"
env = { MAZEL_HTTP = "0", MAZEL_MCP = "1" }
```

Hermes — `~/.hermes/config.yaml`:

```yaml
mcp_servers:
  mazel:
    command: "mix"
    args: ["mcp"]
    cwd: "/absolute/path/to/mazel/apps/room"
    env:
      MAZEL_HTTP: "0"
      MAZEL_MCP: "1"
```

Muse — `~/.config/muse/settings.json`:

```json
{
  "schema_version": 1,
  "mcp_servers": {
    "mazel": {
      "enabled": true,
      "transport": "stdio",
      "command": "mix",
      "args": ["mcp"],
      "cwd": "/absolute/path/to/mazel/apps/room",
      "env": {
        "MAZEL_HTTP": "0",
        "MAZEL_MCP": "1"
      },
      "mode": "optional"
    }
  }
}
```

Files: [docs/install/](install/).

Mazel is ready.

```
Mazel is ready.
ok  paste=cursor  stdio=mix mcp
ok  paste=grok  stdio=mix mcp
ok  paste=hermes  stdio=mix mcp
ok  paste=muse  stdio=mix mcp
```
