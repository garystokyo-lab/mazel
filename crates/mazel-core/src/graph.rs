//! Entities and edges: the shape of what a portal knows about the world around its person.
//!
//! Types only, no behavior, like the rest of the core. Two rules live in the names rather than in
//! code here, and the portal enforces them: an entity never leaves the portal it was written on,
//! and a tribe tier between two people is derived from shared membership, never set by hand.

use serde::{Deserialize, Serialize};

/// What kind of thing an entity is. The registry is deliberately small: each kind earns its place
/// by being something the scorer can match on, and each has one natural key so two portals that
/// learn about the same thing separately agree on what it is called.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum EntityKind {
    /// Keyed by domain: `acme.com`. Not by display name, which is never stable.
    Organization,
    /// Keyed by slug: `lab-ops`. The same normalization tags use.
    Skill,
    /// Keyed by the organizer's public key plus a slug, so two tribes called "founders" on
    /// different portals are different tribes and nobody owns the word.
    Tribe,
}

/// A thing a portal knows about, on the portal that knows it.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Entity {
    pub kind: EntityKind,
    /// The natural key for the kind. Domain, slug, or organizer key plus slug.
    pub key: String,
    pub name: String,
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub purpose: String,
    /// For a Tribe: the organizer's public key.
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub organizer: String,
    /// A tribe nobody may name publicly. Members still route through it.
    #[serde(default)]
    pub unlisted: bool,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub witnesses: Vec<String>,
    pub created: String,
}

/// How two things are related. Every edge is directed and carries who saw it.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EdgeType {
    WorksAt,
    Knows,
    HasSkill,
    SoldTo,
    MetAt,
    BasedIn,
    /// Membership of a tribe. Witnessed by whoever invited the person, or by their own join.
    MemberOf,
}

/// An edge on the portal that wrote it. Never published, never sent to the relay: the graph is the
/// sum of everyone's local tables, not a table anyone holds.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Edge {
    /// A handle, a saved-contact id, or an entity key.
    pub from: String,
    #[serde(rename = "type")]
    pub edge_type: EdgeType,
    pub to: String,
    /// Who saw it: a tool the agent read, the handle that invited, or `self` for one's own join.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub witnesses: Vec<String>,
    /// Visibility of this edge, using the same five tiers as every other field.
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub tier: String,
    pub since: String,
    /// An edge that ended. Never deleted: what happened, happened, and tiers recompute around it.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub until: Option<String>,
}

impl Edge {
    /// An edge with no end date is live. Leaving a tribe sets one; it never removes the row.
    pub fn live(&self) -> bool {
        self.until.is_none()
    }
}
