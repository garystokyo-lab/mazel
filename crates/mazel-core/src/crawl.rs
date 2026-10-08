//! Crawl ontology: the objects one-hop finding creates and learns from.
//!
//! Types only, no behavior. The portal (Worker) is the live implementation;
//! these give the ontology a home in the core so later stages share one vocabulary.
//! Every wire action is typed and versioned; every match carries its path;
//! every known card carries a trust tier.

use serde::{Deserialize, Serialize};

/// Trust tier of a known card. A routing field for later stages; defaulted, never asked of the user.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "kebab-case")]
pub enum TrustTier {
    Inner,
    #[default]
    Tribe,
    World,
}

/// Where a Need may travel (spec §3.2 tiers).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "kebab-case")]
pub enum NeedVisibility {
    #[default]
    Public,
    MatchedOnly,
    Directed,
}

/// A person as their card presents them: handle, persona, the tags they cast.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Person {
    pub handle: String,
    #[serde(default)]
    pub description: String,
    pub card_url: String,
    #[serde(default)]
    pub rpc: Option<String>,
    #[serde(default)]
    pub tier: TrustTier,
}

/// Something a person is looking for from another person, with a hard TTL.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Need {
    pub tag: String,
    #[serde(default)]
    pub gloss: String,
    #[serde(default)]
    pub visibility: NeedVisibility,
    /// RFC 3339. None means an ongoing stream.
    #[serde(default)]
    pub expires: Option<String>,
}

/// Something another person would be glad to reach this person for.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Have {
    pub tag: String,
    #[serde(default)]
    pub gloss: String,
}

/// A candidate produced by deterministic matching of a Need against known Haves.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Match {
    pub thread_id: String,
    pub need_text: String,
    pub need_tags: Vec<String>,
    pub candidate: Person,
    pub matched_tags: Vec<String>,
    pub score: u32,
    /// One-line mutual why, generated deterministically from the matched tag and its gloss.
    pub why: String,
    /// Handles the match traveled through. One hop: just the finder.
    pub path: Vec<String>,
}

/// Who proposed an intro, as carried inside `intro.propose` so the answer can find them.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Proposer {
    pub handle: String,
    pub card_url: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub rpc: Option<String>,
}

/// The wire answer to an intro: what the other side decided. Stays on the wire unchanged.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum Decision {
    Accepted,
    Declined,
}

/// Lifecycle of a proposed intro. Only the first three are set from the wire; the rest are captured, never inferred.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum IntroState {
    Proposed,
    /// Unanimous yes: the proposer said yes by proposing, the other side by accepting.
    Connected,
    Declined,
    Met,
    MetContinued,
    WentQuiet,
}

/// An intro proposed to a candidate, carrying the why and the path.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Intro {
    pub id: String,
    pub thread_id: Option<String>,
    pub proposer: String,
    pub candidate: String,
    pub why: String,
    pub path: Vec<String>,
    pub state: IntroState,
    pub created: String,
    #[serde(default)]
    pub updated: Option<String>,
}

/// What became of an intro. Captured only, so outcomes exist to learn from later.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Outcome {
    pub intro_id: String,
    pub state: IntroState,
    pub recorded: String,
    #[serde(default)]
    pub note: String,
}

/// One person vouching for another along a path. Not sent at crawl; the type exists so paths can carry vouches later.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Vouch {
    pub voucher: String,
    pub subject: String,
    #[serde(default)]
    pub note: String,
    pub created: String,
}

/// The ask inside an intro note (§4.3b): what is being asked for and how much of it.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Ask {
    /// question | call | intro_onward | other
    pub kind: String,
    #[serde(default)]
    pub size: String,
}

/// The signed envelope every action carries since the inbound gate (2026-09-28): who signed, with
/// which key, where their card and door are, when, and the signature. All optional here so the
/// unsigned `note` shape still reads; the portal refuses an action without them.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct Envelope {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub handle: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub public_key: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub card_url: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub rpc: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub cast_at: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub sig: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub kid: Option<String>,
}

/// Typed, versioned wire action carried in message/send metadata. `note` is the default.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all_fields = "camelCase")]
pub enum Action {
    #[serde(rename = "note")]
    Note { v: u32 },
    #[serde(rename = "intro.propose")]
    IntroPropose {
        v: u32,
        intro_id: String,
        why: String,
        #[serde(default)]
        need_text: String,
        need_tags: Vec<String>,
        matched_tags: Vec<String>,
        path: Vec<String>,
        #[serde(default, skip_serializing_if = "Option::is_none")]
        proposer: Option<Proposer>,
        #[serde(default, skip_serializing_if = "Option::is_none")]
        ask: Option<Ask>,
        /// The branch this proposal was made from (§4.3b): the people join it on 🌀.
        #[serde(default, skip_serializing_if = "Option::is_none")]
        context_id: Option<String>,
        #[serde(flatten)]
        envelope: Envelope,
    },
    #[serde(rename = "intro.respond")]
    IntroRespond {
        v: u32,
        intro_id: String,
        decision: Decision,
        #[serde(default)]
        note: String,
        path: Vec<String>,
        /// The thread the people will share, minted at random by the answering side when the
        /// proposal carried none (§4.3b).
        #[serde(default, skip_serializing_if = "Option::is_none")]
        context_id: Option<String>,
        #[serde(flatten)]
        envelope: Envelope,
    },
    /// A thread message: the A2A Message itself is the unit; the action only names the kind.
    #[serde(rename = "thread.message")]
    ThreadMessage { v: u32 },
    #[serde(rename = "thread.close")]
    ThreadClose { v: u32, context_id: String },
}

impl Action {
    pub fn version(&self) -> u32 {
        match self {
            Action::Note { v } | Action::IntroPropose { v, .. } | Action::IntroRespond { v, .. }
            | Action::ThreadMessage { v } | Action::ThreadClose { v, .. } => *v,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn actions_serialize_to_the_wire_shape() {
        let a = Action::IntroPropose { v: 1, intro_id: "abc".into(), why: "hockey".into(), need_text: String::new(), need_tags: vec!["hockey".into()], matched_tags: vec!["hockey".into()], path: vec!["avery@mazel".into()], proposer: None, ask: None, context_id: None, envelope: Envelope::default() };
        let v = serde_json::to_value(&a).unwrap();
        assert_eq!(v["type"], "intro.propose");
        assert_eq!(v["v"], 1);
        assert_eq!(v["path"][0], "avery@mazel");
        let note: Action = serde_json::from_str(r#"{"type":"note","v":1}"#).unwrap();
        assert_eq!(note.version(), 1);
        let r: Action = serde_json::from_str(r#"{"type":"intro.respond","v":1,"introId":"abc","decision":"declined","path":["avery@mazel","gary@mazel"]}"#).unwrap();
        assert!(matches!(r, Action::IntroRespond { decision: Decision::Declined, .. }));
    }

    #[test]
    fn tier_defaults_to_tribe_and_is_never_required() {
        let p: Person = serde_json::from_str(r#"{"handle":"gary@mazel","cardUrl":"https://x/card"}"#).unwrap();
        assert_eq!(p.tier, TrustTier::Tribe);
        assert_eq!(serde_json::to_value(TrustTier::World).unwrap(), "world");
        assert_eq!(serde_json::to_value(IntroState::MetContinued).unwrap(), "met-continued");
    }
}
