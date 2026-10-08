use thiserror::Error;

use crate::{Handle, HandleError, SessionKind};

/// A wing command from an in-chat message. Group (🪽🪽🪽) is later.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WingCommand {
    pub session_kind: SessionKind,
    pub target: Handle,
    pub text: String,
}

#[derive(Debug, Error, Clone, PartialEq, Eq)]
pub enum WingError {
    #[error("not a wing command")]
    NotAWing,
    #[error("group wings are later")]
    GroupLater,
    #[error("wing command needs a handle and text")]
    Incomplete,
    #[error(transparent)]
    Handle(#[from] HandleError),
}

/// Parse `🪽 @kai hello` / `🪽🪽 @nova series-A CTO` / `mazel @kai hello`.
pub fn parse_wing(input: &str) -> Result<WingCommand, WingError> {
    let trimmed = input.trim();
    let (stripped, had_verb) = strip_mazel_verb(trimmed);
    let (stripped, kind_word) = if had_verb {
        take_kind_word(stripped)
    } else {
        (stripped, None)
    };
    let (wings, rest) = count_wings(stripped);
    let (wings, rest_owned) = apply_kind_word(kind_word, wings, had_verb, rest);
    let rest = rest_owned.trim_start();
    let session_kind = match wings {
        0 => return Err(WingError::NotAWing),
        1 => SessionKind::Direct,
        2 => SessionKind::Intro,
        _ => return Err(WingError::GroupLater),
    };

    let mut parts = rest.splitn(2, char::is_whitespace);
    let raw_handle = parts.next().unwrap_or("");
    let text = parts.next().unwrap_or("").trim();
    if raw_handle.is_empty() || text.is_empty() {
        return Err(WingError::Incomplete);
    }

    Ok(WingCommand {
        session_kind,
        target: Handle::parse(raw_handle)?,
        text: text.to_string(),
    })
}

impl WingCommand {
    pub fn is_discovery(&self) -> bool {
        self.target.is_discovery_sink()
    }
}

fn strip_mazel_verb(input: &str) -> (&str, bool) {
    if let Some(head) = input.get(..5) {
        if head.eq_ignore_ascii_case("mazel") {
            let rest = &input[5..];
            if rest.is_empty() {
                return ("", true);
            }
            if rest.starts_with(char::is_whitespace) {
                return (rest.trim_start(), true);
            }
            if rest.starts_with('🪽') {
                return (rest, true);
            }
        }
    }
    (input, false)
}

fn take_kind_word(input: &str) -> (&str, Option<&'static str>) {
    let input = input.trim_start();
    let mut parts = input.splitn(2, char::is_whitespace);
    let word = parts.next().unwrap_or("");
    let rest = parts.next().unwrap_or("").trim_start();
    match word.to_ascii_lowercase().as_str() {
        "intro" => (rest, Some("intro")),
        "need" => (rest, Some("need")),
        "direct" => (rest, Some("direct")),
        _ => (input, None),
    }
}

fn apply_kind_word<'a>(
    kind_word: Option<&str>,
    wings: u8,
    had_verb: bool,
    rest: &'a str,
) -> (u8, std::borrow::Cow<'a, str>) {
    match kind_word {
        Some("intro") => (2, std::borrow::Cow::Borrowed(rest)),
        Some("direct") => (1, std::borrow::Cow::Borrowed(rest)),
        Some("need") => {
            let rest = rest.trim_start();
            let first = rest.split(char::is_whitespace).next().unwrap_or("");
            let looks_handle = first.starts_with('@') || first.contains('@');
            if looks_handle {
                (1, std::borrow::Cow::Borrowed(rest))
            } else {
                (1, std::borrow::Cow::Owned(format!("@mazel {rest}")))
            }
        }
        _ if wings == 0 && had_verb => (1, std::borrow::Cow::Borrowed(rest)),
        _ => (wings, std::borrow::Cow::Borrowed(rest)),
    }
}

fn count_wings(input: &str) -> (u8, &str) {
    let mut rest = input;
    let mut n = 0u8;
    while let Some(next) = rest.strip_prefix('🪽') {
        n = n.saturating_add(1);
        rest = next;
    }
    (n, rest)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_direct_and_intro() {
        let direct = parse_wing("🪽 @kai hello").unwrap();
        assert_eq!(direct.session_kind, SessionKind::Direct);
        assert_eq!(direct.target.id(), "kai@mazel");
        assert_eq!(direct.text, "hello");

        let intro = parse_wing("  🪽🪽 @nova series-A CTO  ").unwrap();
        assert_eq!(intro.session_kind, SessionKind::Intro);
        assert_eq!(intro.target.id(), "nova@mazel");
        assert_eq!(intro.text, "series-A CTO");

        let disco = parse_wing("🪽 @mazel series-A CTO").unwrap();
        assert!(disco.is_discovery());
        assert_eq!(disco.target.id(), "mazel@mazel");
        assert!(!parse_wing("🪽 @kai hello").unwrap().is_discovery());

        let verb = parse_wing("mazel @kai hello").unwrap();
        assert_eq!(verb.session_kind, SessionKind::Direct);
        assert_eq!(verb.target.id(), "kai@mazel");
        assert_eq!(verb.text, "hello");

        let verb_intro = parse_wing("mazel 🪽🪽 @nova series-A CTO").unwrap();
        assert_eq!(verb_intro.session_kind, SessionKind::Intro);
        assert_eq!(verb_intro.target.id(), "nova@mazel");

        let intro_word = parse_wing("mazel intro @kai series-A CTO").unwrap();
        assert_eq!(intro_word.session_kind, SessionKind::Intro);
        assert_eq!(intro_word.target.id(), "kai@mazel");
        assert_eq!(intro_word.text, "series-A CTO");

        let need_word = parse_wing("mazel need series-A CTO").unwrap();
        assert!(need_word.is_discovery());
        assert_eq!(need_word.target.id(), "mazel@mazel");
        assert_eq!(need_word.text, "series-A CTO");
    }

    #[test]
    fn rejects_unknown_shapes() {
        assert_eq!(parse_wing("hello @kai").unwrap_err(), WingError::NotAWing);
        assert_eq!(parse_wing("🪽🪽🪽 @kai later").unwrap_err(), WingError::GroupLater);
        assert_eq!(parse_wing("🪽 @kai").unwrap_err(), WingError::Incomplete);
        assert!(matches!(parse_wing("🪽 @ghost?? hi"), Err(WingError::Handle(_))));
    }
}
