use serde::{Deserialize, Serialize};
use thiserror::Error;

use crate::Handle;

/// Room topic + who we are trying to wake. Badge variants check this differently.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WakeContext<'a> {
    pub topic: &'a str,
    pub subject: Option<&'a Handle>,
}

/// How a badge was minted. v0: pull-match, vouch, invite. PoW is later.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MintSource {
    PullMatch,
    Vouch,
    Invite,
}

impl MintSource {
    pub fn id(self) -> &'static str {
        match self {
            MintSource::PullMatch => "pull_match",
            MintSource::Vouch => "vouch",
            MintSource::Invite => "invite",
        }
    }
}

/// Live need↔open JIT hit. Score ≤ 0 or empty ids do not mint.
#[derive(Debug, Clone, PartialEq)]
pub struct PullMatch {
    pub topic: String,
    pub score: f64,
    pub need_id: String,
    pub open_id: String,
    pub actor: Handle,
}

/// Badge plus the mint source that produced it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MintedBadge {
    pub source: MintSource,
    pub badge: Badge,
}

/// Badge required before a human is woken.
///
/// Agents may talk without it. Waking a human — and therefore connect — may not.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum Badge {
    Vouch { voucher: Handle, note: String },
    PullIntent { actor: Handle, intent: String },
    InviteToken { token: String, issuer: Handle },
    ProofOfWork { nonce: String, difficulty: u32 },
}

#[derive(Debug, Error, PartialEq, Eq)]
pub enum BadgeError {
    #[error("badge note or intent is empty")]
    EmptyClaim,
    #[error("vouch requires a usable voucher handle")]
    MissingVoucher,
    #[error("voucher cannot vouch for themselves")]
    SelfVouch,
    #[error("pull intent actor is missing")]
    MissingActor,
    #[error("pull intent does not match room topic")]
    TopicMismatch,
    #[error("invite token is too short")]
    WeakToken,
    #[error("invite token has no issuer")]
    MissingIssuer,
    #[error("proof of work is out of range")]
    WeakProof,
    #[error("proof of work nonce must be hex")]
    WeakNonce,
    #[error("need and open do not pull-match")]
    NoPullMatch,
}

impl Badge {
    /// Structural check. Prefer `validate_for_wake` at connect time.
    pub fn validate(&self) -> Result<(), BadgeError> {
        match self {
            Badge::Vouch { voucher, note } => {
                require_handle(voucher, BadgeError::MissingVoucher)?;
                nonempty(note, BadgeError::EmptyClaim)
            }
            Badge::PullIntent { actor, intent } => {
                require_handle(actor, BadgeError::MissingActor)?;
                nonempty(intent, BadgeError::EmptyClaim)
            }
            Badge::InviteToken { token, issuer } => {
                require_handle(issuer, BadgeError::MissingIssuer)?;
                if token.trim().len() < 12 {
                    Err(BadgeError::WeakToken)
                } else {
                    Ok(())
                }
            }
            Badge::ProofOfWork { nonce, difficulty } => {
                if !(1..=32).contains(difficulty) {
                    return Err(BadgeError::WeakProof);
                }
                if !is_hex(nonce) || nonce.len() < 8 {
                    return Err(BadgeError::WeakNonce);
                }
                Ok(())
            }
        }
    }

    /// Variant-specific wake rules. PullIntent must mention the room topic.
    pub fn validate_for_wake(&self, ctx: &WakeContext<'_>) -> Result<(), BadgeError> {
        self.validate()?;
        match self {
            Badge::Vouch { voucher, .. } => {
                if let Some(subject) = ctx.subject {
                    if voucher == subject {
                        return Err(BadgeError::SelfVouch);
                    }
                }
                Ok(())
            }
            Badge::PullIntent { intent, .. } => {
                let topic = ctx.topic.trim();
                if topic.is_empty() {
                    return Err(BadgeError::TopicMismatch);
                }
                if !intent.to_ascii_lowercase().contains(&topic.to_ascii_lowercase()) {
                    return Err(BadgeError::TopicMismatch);
                }
                Ok(())
            }
            Badge::InviteToken { .. } | Badge::ProofOfWork { .. } => Ok(()),
        }
    }

    /// Mint from a live need↔open fit. Kind stays `pull_intent`; source is `pull_match`.
    pub fn mint_pull_match(hit: &PullMatch) -> Result<MintedBadge, BadgeError> {
        if hit.score <= 0.0
            || hit.topic.trim().is_empty()
            || hit.need_id.trim().is_empty()
            || hit.open_id.trim().is_empty()
        {
            return Err(BadgeError::NoPullMatch);
        }
        require_handle(&hit.actor, BadgeError::MissingActor)?;
        let intent = format!(
            "pull-match {} need={} open={}",
            hit.topic.trim(),
            hit.need_id.trim(),
            hit.open_id.trim()
        );
        let badge = Badge::PullIntent {
            actor: hit.actor.clone(),
            intent,
        };
        let minted = MintedBadge {
            source: MintSource::PullMatch,
            badge,
        };
        minted.badge.validate()?;
        Ok(minted)
    }

    pub fn mint_vouch(
        voucher: Handle,
        subject: &Handle,
        note: impl Into<String>,
    ) -> Result<MintedBadge, BadgeError> {
        if voucher.id() == subject.id() {
            return Err(BadgeError::SelfVouch);
        }
        let badge = Badge::Vouch {
            voucher,
            note: note.into(),
        };
        badge.validate()?;
        Ok(MintedBadge {
            source: MintSource::Vouch,
            badge,
        })
    }

    pub fn mint_invite(
        issuer: Handle,
        token: impl Into<String>,
    ) -> Result<MintedBadge, BadgeError> {
        let badge = Badge::InviteToken {
            token: token.into(),
            issuer,
        };
        badge.validate()?;
        Ok(MintedBadge {
            source: MintSource::Invite,
            badge,
        })
    }

    pub fn kind_name(&self) -> &'static str {
        match self {
            Badge::Vouch { .. } => "vouch",
            Badge::PullIntent { .. } => "pull_intent",
            Badge::InviteToken { .. } => "invite_token",
            Badge::ProofOfWork { .. } => "proof_of_work",
        }
    }
}

fn require_handle(handle: &Handle, err: BadgeError) -> Result<(), BadgeError> {
    if handle.usable() {
        Ok(())
    } else {
        Err(err)
    }
}

fn nonempty(value: &str, err: BadgeError) -> Result<(), BadgeError> {
    if value.trim().is_empty() {
        Err(err)
    } else {
        Ok(())
    }
}

fn is_hex(value: &str) -> bool {
    let trimmed = value.trim();
    !trimmed.is_empty() && trimmed.chars().all(|c| c.is_ascii_hexdigit())
}
