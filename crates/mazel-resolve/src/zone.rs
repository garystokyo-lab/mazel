//! BIND-lite zone fixture. No network. No `dig`.

use std::path::{Path, PathBuf};

use mazel_core::Handle;

use crate::{
    parse_txt_attrs, push_source, push_unique, ResolveError, Resolution, ResolveSource, Resolver,
};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ZoneRecord {
    pub owner: String,
    pub ttl: u32,
    pub rtype: String,
    pub data: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ZoneFile {
    pub origin: String,
    pub ttl: u32,
    pub records: Vec<ZoneRecord>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ZoneError {
    Io(String),
    Parse(String),
}

impl std::fmt::Display for ZoneError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ZoneError::Io(msg) | ZoneError::Parse(msg) => write!(f, "{msg}"),
        }
    }
}

impl std::error::Error for ZoneError {}

impl ZoneFile {
    pub fn parse(text: &str) -> Result<Self, ZoneError> {
        let mut origin = "mazel.ai".to_string();
        let mut ttl = 300_u32;
        let mut records = Vec::new();

        for (idx, raw) in text.lines().enumerate() {
            let line_no = idx + 1;
            let tokens = tokenize(raw);
            if tokens.is_empty() {
                continue;
            }

            match tokens[0].to_ascii_uppercase().as_str() {
                "$ORIGIN" => {
                    let name = tokens.get(1).ok_or_else(|| {
                        ZoneError::Parse(format!("line {line_no}: $ORIGIN needs a name"))
                    })?;
                    origin = fqdn(name, "mazel.ai");
                }
                "$TTL" => {
                    let value = tokens.get(1).ok_or_else(|| {
                        ZoneError::Parse(format!("line {line_no}: $TTL needs a number"))
                    })?;
                    ttl = value.parse().map_err(|_| {
                        ZoneError::Parse(format!("line {line_no}: bad $TTL {value}"))
                    })?;
                }
                other if other.starts_with('$') => {}
                _ => {
                    if let Some(record) = parse_record(&tokens, &origin, ttl, line_no)? {
                        records.push(record);
                    }
                }
            }
        }

        Ok(Self {
            origin,
            ttl,
            records,
        })
    }

    pub fn load(path: impl AsRef<Path>) -> Result<Self, ZoneError> {
        let path = path.as_ref();
        let text = std::fs::read_to_string(path)
            .map_err(|err| ZoneError::Io(format!("{}: {err}", path.display())))?;
        Self::parse(&text)
    }

    pub fn default_path() -> PathBuf {
        if let Ok(path) = std::env::var("MAZEL_ZONE") {
            if !path.trim().is_empty() {
                return PathBuf::from(path);
            }
        }

        let crate_zone = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../fixtures/dns/mazel.ai.zone");
        if crate_zone.is_file() {
            return crate_zone;
        }

        PathBuf::from("fixtures/dns/mazel.ai.zone")
    }

    pub fn txt_for(&self, handle: &Handle) -> Option<&ZoneRecord> {
        let names = qnames(handle);
        self.records.iter().find(|record| {
            record.rtype == "TXT"
                && names
                    .iter()
                    .any(|name| name == &record.owner || name == &first_label(&record.owner))
        })
    }

    pub fn mock_dig(&self, handle: &Handle) -> String {
        let qname = primary_qname(handle);
        match self.txt_for(handle) {
            Some(record) => format!(
                ";; mock dig TXT {qname}.  (fixture, no network)\n\
                 ;; ANSWER\n\
                 {owner}.  {ttl}  IN  TXT  \"{data}\"\n",
                owner = record.owner,
                ttl = record.ttl,
                data = record.data
            ),
            None => format!(
                ";; mock dig TXT {qname}.  (fixture, no network)\n\
                 ;; ANSWER\n\
                 ;; (no TXT)\n"
            ),
        }
    }
}

impl Resolver for ZoneFile {
    fn lookup(&self, handle: &Handle) -> Result<Resolution, ResolveError> {
        let Some(record) = self.txt_for(handle) else {
            return Err(ResolveError::Unknown(handle.id().to_string()));
        };

        let attrs = parse_txt_attrs(&record.data);
        if attrs.card_urls.is_empty() {
            return Err(ResolveError::Unknown(handle.id().to_string()));
        }

        let mut card_urls = Vec::new();
        let mut sources = Vec::new();
        push_unique(&mut card_urls, &attrs.card_urls);
        push_source(&mut sources, ResolveSource::Txt);

        Ok(Resolution {
            handle: handle.clone(),
            card_urls,
            sources,
            haah: attrs.haah,
        })
    }
}

fn parse_record(
    tokens: &[String],
    origin: &str,
    default_ttl: u32,
    line_no: usize,
) -> Result<Option<ZoneRecord>, ZoneError> {
    if tokens.len() < 3 {
        return Err(ZoneError::Parse(format!("line {line_no}: short record")));
    }

    let owner = fqdn(&tokens[0], origin);
    let mut i = 1;
    let mut ttl = default_ttl;

    if let Ok(n) = tokens[i].parse::<u32>() {
        ttl = n;
        i += 1;
    }

    if tokens
        .get(i)
        .is_some_and(|t| t.eq_ignore_ascii_case("IN"))
    {
        i += 1;
    }

    let rtype = tokens
        .get(i)
        .ok_or_else(|| ZoneError::Parse(format!("line {line_no}: missing type")))?
        .to_ascii_uppercase();
    i += 1;

    if rtype != "TXT" {
        return Ok(None);
    }

    let data = tokens[i..].join(" ");
    if data.is_empty() {
        return Err(ZoneError::Parse(format!("line {line_no}: empty TXT")));
    }

    Ok(Some(ZoneRecord {
        owner,
        ttl,
        rtype,
        data,
    }))
}

fn tokenize(line: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut cur = String::new();
    let mut in_quote = false;

    for c in line.chars() {
        match c {
            '"' => in_quote = !in_quote,
            ';' if !in_quote => break,
            c if c.is_whitespace() && !in_quote => {
                if !cur.is_empty() {
                    out.push(std::mem::take(&mut cur));
                }
            }
            _ => cur.push(c),
        }
    }

    if !cur.is_empty() {
        out.push(cur);
    }

    out
}

fn fqdn(name: &str, origin: &str) -> String {
    let name = name.trim().trim_end_matches('.');
    let origin = origin.trim().trim_end_matches('.');
    if name.is_empty() || name == "@" {
        return origin.to_ascii_lowercase();
    }
    let name = name.to_ascii_lowercase();
    if name == origin || name.ends_with(&format!(".{origin}")) {
        name
    } else {
        format!("{name}.{origin}")
    }
}

fn first_label(name: &str) -> String {
    name.split('.').next().unwrap_or(name).to_string()
}

fn primary_qname(handle: &Handle) -> String {
    let local = handle.local();
    let zone = handle.zone().trim_end_matches('.');
    if zone == "mazel" || zone == "mazal" {
        format!("{local}.{zone}.ai")
    } else {
        format!("{local}.{zone}")
    }
}

fn qnames(handle: &Handle) -> Vec<String> {
    let local = handle.local();
    let zone = handle.zone().trim_end_matches('.');
    let mut names = vec![
        local.to_string(),
        format!("{local}.{zone}"),
        primary_qname(handle),
    ];
    if zone == "mazel.ai" || zone == "mazal.ai" {
        names.push(local.to_string());
    }
    names.sort();
    names.dedup();
    names
}

#[cfg(test)]
mod tests {
    use super::*;

    const FIXTURE: &str = r#"
$ORIGIN mazel.ai.
$TTL 300
kai     300  IN  TXT  "mazel-card=https://mazel.ai/cards/kai mazel-haah=1"
avery   IN TXT "mazel-card=https://mazel.ai/cards/avery" "mazel-haah=1"
"#;

    #[test]
    fn zone_resolves_kai_and_avery_from_txt() {
        let zone = ZoneFile::parse(FIXTURE).unwrap();
        let kai = zone
            .lookup(&Handle::parse("kai@mazel").unwrap())
            .unwrap();
        assert_eq!(kai.handle.id(), "kai@mazel");
        assert_eq!(kai.card_urls, vec!["https://mazel.ai/cards/kai".to_string()]);
        assert!(kai.haah);
        assert_eq!(kai.sources, vec![ResolveSource::Txt]);

        let avery = zone.lookup(&Handle::parse("@avery").unwrap()).unwrap();
        assert_eq!(avery.handle.id(), "avery@mazel");
        assert_eq!(
            avery.card_urls,
            vec!["https://mazel.ai/cards/avery".to_string()]
        );
        assert!(avery.haah);
    }

    #[test]
    fn zone_unknown_handle_fails_clean() {
        let zone = ZoneFile::parse(FIXTURE).unwrap();
        assert_eq!(
            zone.lookup(&Handle::parse("@ghost").unwrap()).unwrap_err(),
            ResolveError::Unknown("ghost@mazel".into())
        );
    }

    #[test]
    fn default_fixture_file_loads() {
        let zone = ZoneFile::load(ZoneFile::default_path()).unwrap();
        assert_eq!(zone.origin, "mazel.ai");
        assert!(zone
            .lookup(&Handle::parse("avery@mazel").unwrap())
            .unwrap()
            .haah);
    }

    #[test]
    fn mock_dig_prints_txt_answer() {
        let zone = ZoneFile::parse(FIXTURE).unwrap();
        let out = zone.mock_dig(&Handle::parse("@kai").unwrap());
        assert!(out.contains("mock dig TXT kai.mazel.ai."));
        assert!(out.contains("mazel-card=https://mazel.ai/cards/kai"));
        assert!(out.contains("mazel-haah=1"));
        assert!(!out.contains("no TXT"));
    }
}