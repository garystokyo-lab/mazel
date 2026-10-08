use serde::{Deserialize, Serialize};
use thiserror::Error;

/// A Mazel handle. DNS-shaped: `@name` or `name@mazel` (also `name@mazel.ai`).
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct Handle {
    id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    card_url: Option<String>,
}

#[derive(Debug, Error, Clone, PartialEq, Eq)]
pub enum HandleError {
    #[error("handle id is empty")]
    Empty,
    #[error("handle is not DNS-shaped (@name or name@zone)")]
    Malformed,
}

impl Handle {
    pub fn new(id: impl Into<String>, card_url: Option<String>) -> Result<Self, HandleError> {
        let id = canonicalize(&id.into())?;
        Ok(Self {
            id,
            card_url: card_url.filter(|u| !u.trim().is_empty()),
        })
    }

    pub fn parse(id: impl Into<String>) -> Result<Self, HandleError> {
        Self::new(id, None)
    }

    pub fn id(&self) -> &str {
        &self.id
    }

    pub fn local(&self) -> &str {
        self.id.split_once('@').map(|(local, _)| local).unwrap_or(&self.id)
    }

    pub fn zone(&self) -> &str {
        self.id.split_once('@').map(|(_, zone)| zone).unwrap_or("mazel")
    }

    pub fn card_url(&self) -> Option<&str> {
        self.card_url.as_deref()
    }

    pub fn usable(&self) -> bool {
        !self.id.trim().is_empty()
    }

    /// `@mazel` / `need@mazel` / `open@mazel` — discovery sinks, not a peer.
    pub fn is_discovery_sink(&self) -> bool {
        let zone = self.zone();
        let mazel_zone = zone == "mazel" || zone == "mazel.ai" || zone == "mazal.ai" || zone == "mazal";
        mazel_zone && (self.local() == "mazel" || self.local() == "need" || self.local() == "open")
    }
}

impl std::fmt::Display for Handle {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.id)
    }
}

fn canonicalize(raw: &str) -> Result<String, HandleError> {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return Err(HandleError::Empty);
    }

    let (local, zone) = if let Some(rest) = trimmed.strip_prefix('@') {
        if rest.is_empty() || rest.contains('@') || !valid_local(rest) {
            return Err(HandleError::Malformed);
        }
        (rest, "mazel")
    } else if let Some((local, zone)) = trimmed.rsplit_once('@') {
        if local.is_empty() || zone.is_empty() || !valid_local(local) || !valid_zone(zone) {
            return Err(HandleError::Malformed);
        }
        (local, zone)
    } else {
        return Err(HandleError::Malformed);
    };

    Ok(format!(
        "{}@{}",
        local.to_ascii_lowercase(),
        zone.to_ascii_lowercase()
    ))
}

fn valid_local(value: &str) -> bool {
    let mut chars = value.chars();
    match chars.next() {
        Some(c) if c.is_ascii_alphanumeric() => {
            chars.all(|c| c.is_ascii_alphanumeric() || c == '.' || c == '_' || c == '-')
        }
        _ => false,
    }
}

fn valid_zone(value: &str) -> bool {
    let value = value.trim_end_matches('.');
    if value.is_empty() {
        return false;
    }
    value.split('.').all(|label| {
        !label.is_empty()
            && label
                .chars()
                .next()
                .is_some_and(|c| c.is_ascii_alphanumeric())
            && label
                .chars()
                .all(|c| c.is_ascii_alphanumeric() || c == '-')
    })
}
