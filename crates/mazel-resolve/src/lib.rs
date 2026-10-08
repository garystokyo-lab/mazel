//! Handle resolution stub. No real DNS.
//!
//! Lookup uses a local static map, then optional TXT:
//! `mazel-card=<url>` and optional `mazel-haah=1`.

use std::collections::BTreeMap;

use mazel_core::{Handle, HandleError};

mod zone;

pub use zone::{ZoneError, ZoneFile, ZoneRecord};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Resolution {
    pub handle: Handle,
    pub card_urls: Vec<String>,
    pub sources: Vec<ResolveSource>,
    pub haah: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct TxtAttrs {
    pub card_urls: Vec<String>,
    pub haah: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ResolveSource {
    StaticMap,
    Txt,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ResolveError {
    Handle(HandleError),
    Unknown(String),
}

impl std::fmt::Display for ResolveError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ResolveError::Handle(err) => write!(f, "{err}"),
            ResolveError::Unknown(id) => write!(f, "unknown handle {id}"),
        }
    }
}

impl std::error::Error for ResolveError {}

impl From<HandleError> for ResolveError {
    fn from(err: HandleError) -> Self {
        ResolveError::Handle(err)
    }
}

pub trait Resolver {
    fn lookup(&self, handle: &Handle) -> Result<Resolution, ResolveError>;
}

/// In-memory map + fake DNS TXT strings. No network.
#[derive(Debug, Clone, Default)]
pub struct StaticResolver {
    cards: BTreeMap<String, Vec<String>>,
    txt: BTreeMap<String, String>,
}

impl StaticResolver {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn demo() -> Self {
        let mut resolver = Self::new();
        resolver.insert_card("kai@mazel", "https://mazel.ai/cards/kai");
        resolver.insert_card("@kai", "https://cards.mazel.ai/kai.json");
        resolver.insert_card("nova@mazel", "https://mazel.ai/cards/nova");
        resolver.set_txt(
            "kai",
            "v=mazel1 mazel-card=https://mazel.ai/cards/kai mazel-haah=1",
        );
        resolver.set_txt(
            "nova",
            "mazel-card=https://mazel.ai/cards/nova mazel-card=https://cards.mazel.ai/nova.json",
        );
        resolver.set_txt(
            "avery",
            "mazel-card=https://mazel.ai/cards/avery mazel-haah=1",
        );
        resolver
    }

    pub fn insert_card(&mut self, key: &str, url: &str) {
        self.cards
            .entry(normalize_key(key))
            .or_default()
            .push(url.to_string());
    }

    pub fn set_txt(&mut self, name: &str, record: impl Into<String>) {
        self.txt.insert(name.trim().to_ascii_lowercase(), record.into());
    }

    pub fn txt_for(&self, handle: &Handle) -> Option<&str> {
        self.txt
            .get(handle.local())
            .or_else(|| self.txt.get(handle.id()))
            .map(String::as_str)
    }
}

impl Resolver for StaticResolver {
    fn lookup(&self, handle: &Handle) -> Result<Resolution, ResolveError> {
        let mut card_urls = Vec::new();
        let mut sources = Vec::new();

        for key in lookup_keys(handle) {
            if let Some(urls) = self.cards.get(&key) {
                push_unique(&mut card_urls, urls);
                if !urls.is_empty() {
                    push_source(&mut sources, ResolveSource::StaticMap);
                }
            }
        }

        let mut haah = false;

        if let Some(record) = self.txt_for(handle) {
            let attrs = parse_txt_attrs(record);
            haah = attrs.haah;
            if !attrs.card_urls.is_empty() {
                push_unique(&mut card_urls, &attrs.card_urls);
                push_source(&mut sources, ResolveSource::Txt);
            }
        }

        if card_urls.is_empty() {
            return Err(ResolveError::Unknown(handle.id().to_string()));
        }

        Ok(Resolution {
            handle: handle.clone(),
            card_urls,
            sources,
            haah,
        })
    }
}

/// Pull Agent Card URLs out of a DNS TXT string.
pub fn parse_txt(record: &str) -> Vec<String> {
    parse_txt_attrs(record).card_urls
}

/// `mazel-card=<url>` plus optional `mazel-haah=1`.
pub fn parse_txt_attrs(record: &str) -> TxtAttrs {
    let mut attrs = TxtAttrs::default();

    for part in record.split_whitespace() {
        let part = part.trim_matches(|c| c == '"' || c == ';');
        if let Some(url) = part
            .strip_prefix("mazel-card=")
            .or_else(|| part.strip_prefix("MAZEL-CARD="))
        {
            let url = url.trim_matches('"').to_string();
            if url.starts_with("https://") || url.starts_with("http://") {
                if !attrs.card_urls.contains(&url) {
                    attrs.card_urls.push(url);
                }
            }
        } else if let Some(flag) = part
            .strip_prefix("mazel-haah=")
            .or_else(|| part.strip_prefix("MAZEL-HAAH="))
        {
            let flag = flag.trim_matches('"').to_ascii_lowercase();
            attrs.haah = flag == "1" || flag == "true" || flag == "yes";
        }
    }

    attrs
}

fn lookup_keys(handle: &Handle) -> Vec<String> {
    vec![
        handle.id().to_string(),
        format!("@{}", handle.local()),
        handle.local().to_string(),
        format!("{}@mazel", handle.local()),
    ]
}

fn normalize_key(key: &str) -> String {
    Handle::parse(key)
        .map(|h| h.id().to_string())
        .unwrap_or_else(|_| key.trim().to_ascii_lowercase())
}

pub(crate) fn push_unique(into: &mut Vec<String>, urls: &[String]) {
    for url in urls {
        if !into.iter().any(|existing| existing == url) {
            into.push(url.clone());
        }
    }
}

pub(crate) fn push_source(into: &mut Vec<ResolveSource>, source: ResolveSource) {
    if !into.contains(&source) {
        into.push(source);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn txt_parse_extracts_mazel_card_urls() {
        assert_eq!(
            parse_txt("v=mazel1 mazel-card=https://mazel.ai/cards/kai"),
            vec!["https://mazel.ai/cards/kai".to_string()]
        );
        assert_eq!(
            parse_txt("mazel-card=https://a.example/card mazel-card=https://b.example/card"),
            vec![
                "https://a.example/card".to_string(),
                "https://b.example/card".to_string()
            ]
        );
        assert!(parse_txt("v=spf1 include:_spf.mazel.ai").is_empty());
        assert!(parse_txt("mazel-card=ftp://nope").is_empty());

        let haah = parse_txt_attrs("mazel-card=https://mazel.ai/cards/kai mazel-haah=1");
        assert_eq!(haah.card_urls, vec!["https://mazel.ai/cards/kai".to_string()]);
        assert!(haah.haah);
        assert!(!parse_txt_attrs("mazel-card=https://mazel.ai/cards/kai").haah);
    }

    #[test]
    fn resolves_demo_handles_from_map_and_txt() {
        let resolver = StaticResolver::demo();
        let kai = Handle::parse("@kai").unwrap();
        let found = resolver.lookup(&kai).unwrap();
        assert_eq!(found.handle.id(), "kai@mazel");
        assert!(found
            .card_urls
            .contains(&"https://mazel.ai/cards/kai".to_string()));
        assert!(found.sources.contains(&ResolveSource::StaticMap));
        assert!(found.sources.contains(&ResolveSource::Txt));
        assert!(found.haah);
    }

    #[test]
    fn unknown_handle_is_an_error() {
        let resolver = StaticResolver::demo();
        let ghost = Handle::parse("@ghost").unwrap();
        assert_eq!(
            resolver.lookup(&ghost).unwrap_err(),
            ResolveError::Unknown("ghost@mazel".into())
        );
    }

    #[test]
    fn name_at_mazel_matches_at_name() {
        let resolver = StaticResolver::demo();
        let a = resolver.lookup(&Handle::parse("@nova").unwrap()).unwrap();
        let b = resolver
            .lookup(&Handle::parse("nova@mazel").unwrap())
            .unwrap();
        assert_eq!(a.handle.id(), b.handle.id());
        assert_eq!(a.card_urls, b.card_urls);
    }
}
