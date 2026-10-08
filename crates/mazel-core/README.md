# mazel-core

Rust types for the Mazel spine. Handle, badge, dual-consent ledger, warm packets, session kinds.

This crate is the stub for handle types, badge validation, and the policy/consent ledger. `@name` / `name@mazel` parse here; lookup lives in `mazel-resolve`.

Connect is refused without a valid badge and dual consent. Badge variants are not interchangeable (`validate_for_wake`). v0 mint sources: `pull_match` (need↔open fit), `vouch`, `invite`.

Protocol ids are stable (`badge`, `direct`, `need`). Display labels live in `labels` and can be swapped without renaming types or breaking tests.
