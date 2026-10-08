use serde::{Deserialize, Serialize};

/// Session wings. Group (🪽🪽🪽) is later.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SessionKind {
    /// 🪽 one agent-mediated conversation
    Direct,
    /// 🪽🪽 an introduction
    Intro,
}

impl SessionKind {
    pub fn wings(self) -> u8 {
        match self {
            SessionKind::Direct => 1,
            SessionKind::Intro => 2,
        }
    }

    /// Literal 🪽 only. No alternate wing art.
    pub fn wing_mark(self) -> &'static str {
        match self {
            SessionKind::Direct => "🪽",
            SessionKind::Intro => "🪽🪽",
        }
    }

    pub fn id(self) -> &'static str {
        match self {
            SessionKind::Direct => "direct",
            SessionKind::Intro => "intro",
        }
    }

    /// Display label from the swappable table. Wire/tests use [`Self::id`].
    pub fn label(self) -> &'static str {
        crate::labels::lookup(self.id())
    }
}