use serde::{Deserialize, Serialize};
use thiserror::Error;

use crate::{
    allow_connect, Badge, ConsentLedger, Handle, ConnectError, SessionKind, WakeContext,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ParticipantRole {
    Agent,
    Human,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Participant {
    pub handle: Handle,
    pub role: ParticipantRole,
}

impl Participant {
    pub fn new(handle: Handle, role: ParticipantRole) -> Self {
        Self { handle, role }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TranscriptLine {
    pub speaker: Handle,
    pub text: String,
}

impl TranscriptLine {
    pub fn new(speaker: Handle, text: impl Into<String>) -> Self {
        Self {
            speaker,
            text: text.into(),
        }
    }
}

/// Context humans inherit when a connect commits.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct WarmPacket {
    pub context_id: String,
    pub session_kind: SessionKind,
    pub participants: Vec<Participant>,
        pub badge: Badge,
    pub summary: String,
    pub transcript_excerpt: Vec<TranscriptLine>,
    pub committed_at: String,
}

pub struct Assemble<'a> {
    pub context_id: String,
    pub session_kind: SessionKind,
    pub participants: Vec<Participant>,
    pub badge: Badge,
    pub ledger: &'a ConsentLedger,
    pub topic: Option<String>,
    pub subject: Option<Handle>,
    pub summary: String,
    pub transcript_excerpt: Vec<TranscriptLine>,
    pub committed_at: String,
}

#[derive(Debug, Error, PartialEq, Eq)]
pub enum WarmPacketError {
    #[error("badge is required before connect")]
    MissingBadge,
    #[error("badge is invalid")]
    Badge(crate::BadgeError),
    #[error("dual consent is required before connect")]
    MissingConsent,
    #[error("warm packet needs a summary")]
    EmptySummary,
}

impl From<ConnectError> for WarmPacketError {
    fn from(err: ConnectError) -> Self {
        match err {
            ConnectError::MissingBadge => WarmPacketError::MissingBadge,
            ConnectError::Badge(err) => WarmPacketError::Badge(err),
            ConnectError::MissingConsent => WarmPacketError::MissingConsent,
        }
    }
}

impl WarmPacket {
    pub fn assemble(input: Assemble<'_>) -> Result<Self, WarmPacketError> {
        let ctx;
        let ctx_ref = match (input.topic.as_deref(), input.subject.as_ref()) {
            (None, None) => None,
            (topic, subject) => {
                ctx = WakeContext {
                    topic: topic.unwrap_or(""),
                    subject,
                };
                Some(&ctx)
            }
        };
        allow_connect(Some(&input.badge), input.ledger, ctx_ref)?;
        if input.summary.trim().is_empty() {
            return Err(WarmPacketError::EmptySummary);
        }
        Ok(Self {
            context_id: input.context_id,
            session_kind: input.session_kind,
            participants: input.participants,
            badge: input.badge,
            summary: input.summary,
            transcript_excerpt: input.transcript_excerpt,
            committed_at: input.committed_at,
        })
    }

    pub fn session_kind(&self) -> SessionKind {
        self.session_kind
    }
}
