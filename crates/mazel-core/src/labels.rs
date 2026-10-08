//! Display labels for stable protocol ids.
//!
//! Wire, serde `kind` tags, and tests use ids (`badge`, `direct`, `need`).
//! Humans see this table. Swap or override it without renaming types.

use std::cell::RefCell;
use std::collections::HashMap;

/// Core protocol ids that have a default display row.
pub const IDS: &[&str] = &[
    "badge",
    "pull_intent",
    "pull_match",
    "vouch",
    "invite_token",
    "proof_of_work",
    "find",
    "chat",
    "harp",
    "direct",
    "series-a",
    "cto",
    "impl",
    "enterprise",
    "intro",
    "need",
    "open",
    "discovery",
    "connect",
    "connect.propose",
    "connect.commit",
    "consent",
    "room.open",
    "handle",
    "warm_packet",
    "has",
    "curious",
    "candidate",
    "proof",
    "claim",
];

const DEFAULT: &[(&str, &str)] = &[
    ("badge", "Badge"),
    ("pull_intent", "Pull intent"),
    ("pull_match", "Pull match"),
    ("vouch", "Vouch"),
    ("invite_token", "Invite token"),
    ("proof_of_work", "Proof of work"),
    ("find", "Find"),
    ("chat", "Chat"),
    ("harp", "Harp"),
    ("direct", "Direct"),
    ("series-a", "Series A"),
    ("cto", "CTO"),
    ("impl", "Impl"),
    ("enterprise", "Enterprise"),
    ("intro", "Intro"),
    ("need", "Need"),
    ("open", "Open"),
    ("discovery", "Discovery"),
    ("connect", "Connect"),
    ("connect.propose", "Connect propose"),
    ("connect.commit", "Connect commit"),
    ("consent", "Consent"),
    ("room.open", "Room open"),
    ("handle", "Handle"),
    ("warm_packet", "Warm packet"),
    ("has", "Has"),
    ("curious", "Curious"),
    ("candidate", "Candidate"),
    ("proof", "Proof"),
    ("claim", "Claim"),
];

thread_local! {
    static OVERRIDES: RefCell<HashMap<String, String>> = RefCell::new(HashMap::new());
}

/// Default English row for a known id, or the id itself.
pub fn lookup(id: &str) -> &'static str {
    DEFAULT
        .iter()
        .find(|(key, _)| *key == id)
        .map(|(_, label)| *label)
        .unwrap_or("")
}

/// Current display label (process override, then default table, then the id).
pub fn label(id: &str) -> String {
    OVERRIDES.with(|overrides| {
        if let Some(value) = overrides.borrow().get(id) {
            return value.clone();
        }
        DEFAULT
            .iter()
            .find(|(key, _)| *key == id)
            .map(|(_, value)| (*value).to_string())
            .unwrap_or_else(|| id.to_string())
    })
}

/// One demo line: `badge  Badge` (id stays; label is swappable).
pub fn format(id: &str) -> String {
    format!("{}  {}", id, label(id))
}

/// Override one display row for this thread. Does not change protocol ids.
pub fn put(id: &str, display: impl Into<String>) {
    OVERRIDES.with(|overrides| {
        overrides
            .borrow_mut()
            .insert(id.to_string(), display.into());
    });
}

/// Drop thread overrides; back to the default English table.
pub fn reset() {
    OVERRIDES.with(|overrides| overrides.borrow_mut().clear());
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn core_ids_are_in_the_table() {
        for id in [
            "badge",
            "pull_intent",
            "direct",
            "harp",
            "has",
            "curious",
            "need",
            "open",
            "connect.propose",
        ] {
            assert!(IDS.contains(&id), "missing id {id}");
            assert!(format(id).starts_with(&format!("{id}  ")));
            assert!(!label(id).is_empty());
        }
    }

    #[test]
    fn override_swaps_display_not_id() {
        put("badge", "Token");
        assert_eq!(label("badge"), "Token");
        assert_eq!(format("badge"), "badge  Token");
        reset();
        assert_ne!(label("badge"), "Token");
        assert!(format("badge").starts_with("badge  "));
    }
}
