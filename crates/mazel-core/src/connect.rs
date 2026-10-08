use thiserror::Error;

use crate::{Badge, BadgeError, ConsentLedger, WakeContext};

#[derive(Debug, Error, PartialEq, Eq)]
pub enum ConnectError {
    #[error("badge is required before connect")]
    MissingBadge,
    #[error(transparent)]
    Badge(#[from] BadgeError),
    #[error("dual consent is required before connect")]
    MissingConsent,
}

/// No connect without a valid badge and dual consent.
pub fn allow_connect(
    badge: Option<&Badge>,
    ledger: &ConsentLedger,
    ctx: Option<&WakeContext<'_>>,
) -> Result<(), ConnectError> {
    let badge = badge.ok_or(ConnectError::MissingBadge)?;
    match ctx {
        Some(ctx) => badge.validate_for_wake(ctx)?,
        None => badge.validate()?,
    }
    if !ledger.dual_consent() {
        return Err(ConnectError::MissingConsent);
    }
    Ok(())
}
