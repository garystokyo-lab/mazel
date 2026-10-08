# Mazel recovered tree — 2026-09-14

This is a personal project for Ariel Jalali.

Recovered by Claude from the Cursor cloud builder transcript (bc-82882425, 46,736 events)
by full replay: file creations and 3,777 edit hunks applied in order, checkpointed only on
verified full-file reads. This supersedes the "reconstruction" tree (mazel-gh-zip), which
was corrupted by overlaying excerpt reads as whole files (~650 files damaged there are
clean here).

Known imperfections (11 files, listed in RECOVERY-FAILURES.txt): a few late edit hunks
could not be placed (README.md, self_report_match.ex, badge.ex, and small others), and
mazel-core Cargo.toml + lib.rs saw 2 early edits before first known state. These files are
the best-known state, possibly missing one small late edit each.

Not compiled or tested: no Elixir/Rust toolchain was available at recovery time.
First action on a machine with tooling: `mix compile` in apps/room and `cargo test` in crates/.
