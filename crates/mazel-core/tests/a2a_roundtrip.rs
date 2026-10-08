//! The JS side writes portal/test/fixtures/*.json from the live Worker. These tests read them
//! into the typed Rust shapes and re-emit them. Any field either side adds, drops, or renames
//! fails here, so the ontology and the wire cannot drift apart silently.

use mazel_core::{Action, AgentCard, Cast, HandleRecord, PulseConfig, RotationRecord, SendMessageRequest, HAAH_URI};
use serde_json::Value;
use std::{fs, path::PathBuf};

fn fixture(name: &str) -> Value {
    let p = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../portal/test/fixtures").join(name);
    serde_json::from_str(&fs::read_to_string(&p).unwrap_or_else(|e| panic!("{}: {e}", p.display()))).unwrap()
}

/// Deserialize into T, serialize back, compare as JSON values. Exact: no field lost, none invented.
fn roundtrip<T: serde::de::DeserializeOwned + serde::Serialize>(v: &Value, what: &str) -> T {
    let typed: T = serde_json::from_value(v.clone()).unwrap_or_else(|e| panic!("{what}: rust cannot read the JS output: {e}"));
    let back = serde_json::to_value(&typed).unwrap();
    assert_eq!(&back, v, "{what}: rust re-emits something different from the JS output");
    typed
}

#[test]
fn agent_card_roundtrips_and_exposes_haah() {
    let card: AgentCard = roundtrip(&fixture("agent-card.json"), "agent-card");
    // the fixture is written by the portal; its version is whatever portal/package.json says
    let pkg: serde_json::Value = serde_json::from_str(include_str!("../../../portal/package.json")).unwrap();
    assert_eq!(card.version, pkg["version"].as_str().unwrap());
    assert_eq!(card.rpc(), Some("https://mazel.fixture.workers.dev/a2a"));
    let haah = card.haah().expect("HAAH extension present");
    assert_eq!(haah.handle, "avery@mazel");
    assert!(haah.have.contains(&"managed-ai-delivery".to_string()));
    assert!(card.capabilities.extensions.iter().any(|e| e.uri == HAAH_URI && !e.required));
    assert!(fixture("agent-card.json").get("handle").is_none(), "no Mazel fields at the top level");
}

#[test]
fn send_message_envelope_roundtrips() {
    let req: SendMessageRequest = roundtrip(&fixture("send-message.json"), "send-message");
    assert_eq!(req.method, "SendMessage");
    assert_eq!(req.params.message.role, mazel_core::Role::User);
    assert_eq!(req.params.message.extensions, vec![HAAH_URI.to_string()]);
    assert_eq!(req.params.message.parts.len(), 1);
    let action: Action = serde_json::from_value(req.params.message.metadata.unwrap()["action"].clone()).unwrap();
    assert!(matches!(action, Action::IntroPropose { .. }));
}

#[test]
fn ack_is_a_message_result() {
    let ack = fixture("ack.json");
    let msg: mazel_core::Message = roundtrip(&ack["result"]["message"], "ack.result.message");
    assert_eq!(msg.role, mazel_core::Role::Agent);
    assert!(msg.parts[0].text.starts_with("Delivered to peer@mazel"));
}

#[test]
fn every_action_type_roundtrips() {
    let actions = fixture("actions.json");
    let list = actions.as_array().unwrap();
    assert_eq!(list.len(), 3);
    let mut seen = Vec::new();
    for a in list {
        let typed: Action = roundtrip(a, "action");
        seen.push(match typed { Action::Note { .. } => "note", Action::IntroPropose { .. } => "intro.propose", Action::IntroRespond { .. } => "intro.respond", Action::ThreadMessage { .. } => "thread.message", Action::ThreadClose { .. } => "thread.close" });
    }
    assert_eq!(seen, vec!["note", "intro.propose", "intro.respond"]);
}

#[test]
fn pulse_config_roundtrips() {
    let cfg: PulseConfig = roundtrip(&fixture("pulse-config.json"), "pulse-config");
    assert_eq!(cfg.task_id, "*");
    assert!(cfg.url.starts_with("https://"));
}

#[test]
fn card_exposes_the_public_key() {
    let card: AgentCard = roundtrip(&fixture("agent-card.json"), "agent-card");
    let haah = card.haah().unwrap();
    assert!(haah.public_key.as_deref().map(|k| k.len() > 30).unwrap_or(false));
    assert!(haah.key_id.is_some());
}

#[test]
fn handle_record_and_rotation_roundtrip() {
    let rec: HandleRecord = roundtrip(&fixture("handle-record.json"), "handle-record");
    assert_eq!(rec.handle, "avery@mazel");
    assert!(rec.card_url.ends_with("/.well-known/agent-card.json"));
    let rot: RotationRecord = roundtrip(&fixture("rotation-record.json"), "rotation-record");
    assert_eq!(rot.kind, "rotation");
    assert_ne!(rot.old_key, rot.new_key);
    assert!(!rot.new_sig.is_empty());
}

#[test]
fn cast_roundtrip() {
    let c: Cast = roundtrip(&fixture("cast.json"), "cast");
    assert_eq!(c.kind, "need");
    assert_eq!(c.visibility.as_deref(), Some("public"));
}
