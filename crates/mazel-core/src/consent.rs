use serde::{Deserialize, Serialize};
use thiserror::Error;

use crate::Handle;

/// One granted consent on a connect.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Consent {
    pub handle: Handle,
    pub granted_at: String,
}

/// Dual-consent ledger. Both required parties must grant before connect.commit.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ConsentLedger {
    pub context_id: String,
    required: Vec<Handle>,
    granted: Vec<Consent>,
}

#[derive(Debug, Error, PartialEq, Eq)]
pub enum ConsentError {
    #[error("handle is not a required party for this connect")]
    NotRequired,
}

impl ConsentLedger {
    pub fn new(context_id: impl Into<String>, required: Vec<Handle>) -> Self {
        Self {
            context_id: context_id.into(),
            required,
            granted: Vec::new(),
        }
    }

    pub fn required(&self) -> &[Handle] {
        &self.required
    }

    pub fn granted(&self) -> &[Consent] {
        &self.granted
    }

    pub fn grant(&mut self, handle: Handle) -> Result<(), ConsentError> {
        if !self.required.iter().any(|h| h == &handle) {
            return Err(ConsentError::NotRequired);
        }
        if self.granted.iter().any(|c| c.handle == handle) {
            return Ok(());
        }
        self.granted.push(Consent {
            handle,
            granted_at: "now".into(),
        });
        Ok(())
    }

    pub fn grant_at(&mut self, handle: Handle, granted_at: impl Into<String>) -> Result<(), ConsentError> {
        self.grant(handle.clone())?;
        if let Some(c) = self.granted.iter_mut().find(|c| c.handle == handle) {
            c.granted_at = granted_at.into();
        }
        Ok(())
    }

    pub fn missing(&self) -> Vec<&Handle> {
        self.required
            .iter()
            .filter(|h| !self.granted.iter().any(|c| &&c.handle == h))
            .collect()
    }

    /// Dual consent: at least two required parties, and every required party has granted.
    pub fn dual_consent(&self) -> bool {
        self.required.len() >= 2 && self.missing().is_empty()
    }
}
