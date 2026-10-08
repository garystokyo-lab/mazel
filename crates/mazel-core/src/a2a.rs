//! A2A v1.0 shapes as Mazel emits and reads them, serialized exactly like the wire
//! (camelCase, protobuf-JSON enums). Hand-rolled on purpose: no dependency on a
//! pre-1.0 crate. The JS side writes fixtures from the live Worker output and the
//! tests below round-trip them, so drift on either side fails a build.

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

pub const HAAH_URI: &str = "https://mazel.ai/ext/haah/v1";
pub const A2A_VERSION: &str = "1.0";

/// What HAAH adds to a plain A2A card: the extension's `params`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct HaahParams {
    pub handle: String,
    pub card_url: String,
    #[serde(default)]
    pub need: Vec<String>,
    #[serde(default)]
    pub have: Vec<String>,
    #[serde(default)]
    pub glosses: BTreeMap<String, String>,
    /// Ed25519 public key, base64url raw. The key is the identity; the handle is a label.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub public_key: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub key_id: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AgentExtension {
    pub uri: String,
    pub description: String,
    pub required: bool,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub params: Option<serde_json::Value>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AgentInterface {
    pub url: String,
    pub protocol_binding: String,
    pub protocol_version: String,
    #[serde(default)]
    pub tenant: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AgentProvider {
    pub organization: String,
    pub url: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AgentCapabilities {
    #[serde(default)]
    pub streaming: bool,
    #[serde(default)]
    pub push_notifications: bool,
    #[serde(default)]
    pub extensions: Vec<AgentExtension>,
    #[serde(default)]
    pub extended_agent_card: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AgentSkill {
    pub id: String,
    pub name: String,
    pub description: String,
    #[serde(default)]
    pub tags: Vec<String>,
    #[serde(default)]
    pub examples: Vec<String>,
    #[serde(default)]
    pub input_modes: Vec<String>,
    #[serde(default)]
    pub output_modes: Vec<String>,
}

/// A2A v1.0 AgentCard as the portal serves it at /.well-known/agent-card.json.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AgentCard {
    pub name: String,
    pub description: String,
    pub supported_interfaces: Vec<AgentInterface>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub provider: Option<AgentProvider>,
    pub version: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub documentation_url: Option<String>,
    pub capabilities: AgentCapabilities,
    #[serde(default)]
    pub security_schemes: BTreeMap<String, serde_json::Value>,
    #[serde(default)]
    pub security_requirements: Vec<serde_json::Value>,
    #[serde(default)]
    pub default_input_modes: Vec<String>,
    #[serde(default)]
    pub default_output_modes: Vec<String>,
    #[serde(default)]
    pub skills: Vec<AgentSkill>,
    #[serde(default)]
    pub signatures: Vec<serde_json::Value>,
}

impl AgentCard {
    /// The HAAH params if this card carries the extension.
    pub fn haah(&self) -> Option<HaahParams> {
        self.capabilities
            .extensions
            .iter()
            .find(|e| e.uri == HAAH_URI)
            .and_then(|e| e.params.clone())
            .and_then(|v| serde_json::from_value(v).ok())
    }

    /// The JSON-RPC talk address (first JSONRPC interface, else the first).
    pub fn rpc(&self) -> Option<&str> {
        self.supported_interfaces
            .iter()
            .find(|i| i.protocol_binding.eq_ignore_ascii_case("JSONRPC"))
            .or_else(|| self.supported_interfaces.first())
            .map(|i| i.url.as_str())
    }
}

/// Wire role, protobuf-JSON spelling.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Role {
    #[serde(rename = "ROLE_USER")]
    User,
    #[serde(rename = "ROLE_AGENT")]
    Agent,
}

/// v1.0 text part: `{ "text": "..." }`. Other part kinds are not used by Mazel.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Part {
    pub text: String,
}

/// v1.0 Message as it travels in SendMessage and comes back in the ack.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Message {
    pub message_id: String,
    #[serde(default)]
    pub context_id: String,
    #[serde(default)]
    pub task_id: String,
    pub role: Role,
    pub parts: Vec<Part>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub metadata: Option<serde_json::Value>,
    #[serde(default)]
    pub extensions: Vec<String>,
    #[serde(default)]
    pub reference_task_ids: Vec<String>,
}

/// The JSON-RPC envelope Mazel sends: method SendMessage, params { message }.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SendMessageRequest {
    pub jsonrpc: String,
    pub id: String,
    pub method: String,
    pub params: SendMessageParams,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SendMessageParams {
    pub message: Message,
}

/// Pulse subscription = A2A TaskPushNotificationConfig. Register only at crawl.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PulseConfig {
    #[serde(default)]
    pub tenant: String,
    pub id: String,
    pub task_id: String,
    pub url: String,
    /// A2A allows a bearer here. A Mazel portal never stores or returns one: an unauthenticated
    /// door plus a stored credential is a credential given away (v0.5.2-sec). Accepted on the way
    /// in, dropped immediately, never serialized back out.
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub token: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub authentication: Option<serde_json::Value>,
}

// ---------------------------------------------------------------------------
// Fly: identity records and carriers. Signed objects carry `sig` (base64url Ed25519 over the
// canonical JSON of everything except sig/kid) and `kid` (first 16 chars of base64url SHA-256 of the key).

/// A rotation: signed by the old key (`sig`), countersigned by the new (`new_sig`).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RotationRecord {
    pub v: u32,
    #[serde(rename = "type")]
    pub kind: String,
    pub handle: String,
    pub old_key: String,
    pub old_kid: String,
    pub new_key: String,
    pub new_kid: String,
    pub timestamp: String,
    pub sig: String,
    pub kid: String,
    pub new_sig: String,
}

/// What `/.well-known/mazel/<name>.json` serves: any domain can be a directory.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HandleRecord {
    pub v: u32,
    pub handle: String,
    pub public_key: String,
    pub card_url: String,
    pub rpc: String,
    pub timestamp: String,
    #[serde(default)]
    pub rotations: Vec<RotationRecord>,
    pub sig: String,
    pub kid: String,
}

/// A signed public cast to the relay: a need (kind = "need") or a card (kind = "card").
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Cast {
    pub v: u32,
    pub handle: String,
    pub public_key: String,
    pub card_url: String,
    pub rpc: String,
    pub kind: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub visibility: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub need_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub need_text: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub need_tags: Option<Vec<String>>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub have: Option<Vec<String>>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub glosses: Option<BTreeMap<String, String>>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    pub sig: String,
    pub kid: String,
}

