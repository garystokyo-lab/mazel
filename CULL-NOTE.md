# Cull note — 2026-09-14

This is a personal project for Ariel Jalali.

This tree is the recovered codebase with the demo theater removed: 443 demo mix tasks,
buddy/kai scenario modules, LOOK-era one-off variants, and their tests (1,463 files down
to ~345). The full uncut recovery lives in mazel-codebase.zip in Ariel's archive.

Kept: Rust crates, durable Room modules (peer card / resolve / talk, badge, consent,
session, need/have/agent_complete, install paste), their tests, config, docs, cards,
fixtures, and 4 real mix tasks (mazel, demo, smoke, mcp).

Not compiled since cull: some removed module may still be referenced somewhere.
First action with tooling: `mix compile`; if a missing-module error appears, restore
that one file from the archive zip rather than restoring the lot.
