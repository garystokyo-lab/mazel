//! Wiki compile stub. Fake chat turns become dated markdown slices.
//!
//! `index/knows/` and `index/needs/` — JIT rank applies `evidence_freshness_penalty`.

use std::fs;
use std::io;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SliceKind {
    Know,
    Need,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ChatTurn {
    pub speaker: String,
    pub text: String,
    pub at: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Slice {
    pub id: String,
    pub kind: SliceKind,
    pub topic: String,
    pub title: String,
    pub body: String,
    pub as_of: String,
    pub ttl_hours: Option<u32>,
    pub expires_at: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Ranked {
    pub id: String,
    pub topic: String,
    pub as_of: String,
    pub age_days: u32,
    pub topic_score: f64,
    pub evidence_freshness_penalty: f64,
    pub score: f64,
}

impl SliceKind {
    pub fn dir(self) -> &'static str {
        match self {
            SliceKind::Know => "knows",
            SliceKind::Need => "needs",
        }
    }

    pub fn label(self) -> &'static str {
        match self {
            SliceKind::Know => "know",
            SliceKind::Need => "need",
        }
    }
}

impl Slice {
    pub fn filename(&self) -> String {
        format!("{}-{}.md", self.as_of, self.id)
    }

    pub fn path(&self, root: &Path) -> PathBuf {
        root.join("index").join(self.kind.dir()).join(self.filename())
    }

    pub fn markdown(&self) -> String {
        let mut head = format!(
            "---\nid: {id}\nkind: {kind}\ntopic: {topic}\nas_of: {as_of}\n",
            id = self.id,
            kind = self.kind.label(),
            topic = self.topic,
            as_of = self.as_of
        );
        if let Some(ttl) = self.ttl_hours {
            head.push_str(&format!("ttl_hours: {ttl}\n"));
        }
        if let Some(exp) = &self.expires_at {
            head.push_str(&format!("expires_at: {exp}\n"));
        }
        format!(
            "{head}---\n\n# {title}\n\n{body}\n",
            title = self.title,
            body = self.body.trim()
        )
    }

    pub fn expired(&self, today: &str) -> bool {
        match self.ttl_hours {
            Some(ttl) => self.age_days(today).saturating_mul(24) >= ttl,
            None => false,
        }
    }

    pub fn write(&self, root: &Path) -> io::Result<PathBuf> {
        let path = self.path(root);
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(&path, self.markdown())?;
        Ok(path)
    }

    pub fn age_days(&self, today: &str) -> u32 {
        days_between(&self.as_of, today).unwrap_or(0)
    }
}

/// Keyword stub: questions become needs; Prague / agents become knows.
pub fn compile_turn(turn: &ChatTurn) -> Slice {
    let lower = turn.text.to_ascii_lowercase();
    if lower.contains('?') {
        let topic = if lower.contains("prague") {
            "prague"
        } else if lower.contains("agent") {
            "ai-agents"
        } else {
            "open"
        };
        return Slice {
            id: format!("need-{topic}"),
            kind: SliceKind::Need,
            topic: topic.into(),
            title: format!("Need: {topic}"),
            body: turn.text.clone(),
            as_of: turn.at.clone(),
            ttl_hours: Some(72),
            expires_at: None,
        };
    }

    if lower.contains("prague") {
        return Slice {
            id: "prague".into(),
            kind: SliceKind::Know,
            topic: "prague".into(),
            title: "Prague memory".into(),
            body: format!("{}\n\n— {}", turn.text.trim(), turn.speaker),
            as_of: turn.at.clone(),
            ttl_hours: None,
            expires_at: None,
        };
    }

    Slice {
        id: "ai-agents".into(),
        kind: SliceKind::Know,
        topic: "ai-agents".into(),
        title: "AI agents know".into(),
        body: format!("{}\n\n— {}", turn.text.trim(), turn.speaker),
        as_of: turn.at.clone(),
        ttl_hours: None,
        expires_at: None,
    }
}

/// Hard-TTL need. Discovery sink (`@mazel` / `need@mazel`), not a peer session.
pub fn dispatch_need(id: impl Into<String>, topic: impl Into<String>, body: impl Into<String>, as_of: impl Into<String>, ttl_hours: u32) -> Slice {
    let as_of = as_of.into();
    Slice {
        id: id.into(),
        kind: SliceKind::Need,
        topic: topic.into(),
        title: "Need".into(),
        body: body.into(),
        as_of: as_of.clone(),
        ttl_hours: Some(ttl_hours),
        expires_at: None,
    }
}

/// JIT match. Expired needs return no matches.
pub fn match_need(need: &Slice, knows: &[Slice], today: &str) -> Vec<Ranked> {
    if need.expired(today) {
        return Vec::new();
    }
    rank_knows(need, knows, today)
        .into_iter()
        .filter(|row| row.score > 0.0)
        .collect()
}

pub fn compile_turns(root: &Path, turns: &[ChatTurn]) -> io::Result<Vec<PathBuf>> {
    let mut paths = Vec::new();
    for turn in turns {
        paths.push(compile_turn(turn).write(root)?);
    }
    Ok(paths)
}

/// JIT rank: `score = topic_score - evidence_freshness_penalty`.
/// Penalty scales with age (caps at 1.0 after ~365 days).
pub fn rank_knows(need: &Slice, knows: &[Slice], today: &str) -> Vec<Ranked> {
    let mut ranked: Vec<Ranked> = knows
        .iter()
        .map(|know| {
            let age_days = know.age_days(today);
            let topic_score = topic_score(need, know);
            let evidence_freshness_penalty = freshness_penalty(age_days);
            Ranked {
                id: know.id.clone(),
                topic: know.topic.clone(),
                as_of: know.as_of.clone(),
                age_days,
                topic_score,
                evidence_freshness_penalty,
                score: topic_score - evidence_freshness_penalty,
            }
        })
        .collect();
    ranked.sort_by(|a, b| {
        b.score
            .partial_cmp(&a.score)
            .unwrap_or(std::cmp::Ordering::Equal)
            .then(
                b.topic_score
                    .partial_cmp(&a.topic_score)
                    .unwrap_or(std::cmp::Ordering::Equal),
            )
    });
    ranked
}

pub fn freshness_penalty(age_days: u32) -> f64 {
    ((age_days as f64) / 365.0).min(1.0) * 0.55
}

fn topic_score(need: &Slice, know: &Slice) -> f64 {
    if need.topic == know.topic {
        1.0
    } else if know.body.to_ascii_lowercase().contains(&need.topic)
        || know.title.to_ascii_lowercase().contains(&need.topic)
    {
        0.35
    } else {
        0.0
    }
}

fn days_between(from: &str, to: &str) -> Option<u32> {
    Some(ordinal(to)?.abs_diff(ordinal(from)?))
}

fn ordinal(value: &str) -> Option<u32> {
    const DIM: [u32; 12] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    let mut parts = value.split('-');
    let y: u32 = parts.next()?.parse().ok()?;
    let m: u32 = parts.next()?.parse().ok()?;
    let d: u32 = parts.next()?.parse().ok()?;
    if !(1..=12).contains(&m) {
        return None;
    }
    let leap = if y % 4 == 0 && m == 2 { 1 } else { 0 };
    if d == 0 || d > DIM[(m - 1) as usize] + leap {
        return None;
    }
    let mut days = y * 365 + y / 4;
    for month in 1..m {
        days += DIM[(month - 1) as usize];
        if month == 2 && y % 4 == 0 {
            days += 1;
        }
    }
    Some(days + d)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn know(id: &str, topic: &str, as_of: &str) -> Slice {
        Slice {
            id: id.into(),
            kind: SliceKind::Know,
            topic: topic.into(),
            title: id.into(),
            body: format!("{topic} notes"),
            as_of: as_of.into(),
            ttl_hours: None,
            expires_at: None,
        }
    }

    #[test]
    fn expired_need_does_not_match() {
        let live = dispatch_need("need-series-a", "series-a", "series-A CTO", "2026-09-10", 72);
        let dead = dispatch_need("need-old", "series-a", "series-A CTO", "2026-01-01", 24);
        let knows = vec![know("series-a", "series-a", "2026-09-10")];
        assert!(!live.expired("2026-09-10"));
        assert!(dead.expired("2026-09-10"));
        assert!(!match_need(&live, &knows, "2026-09-10").is_empty());
        assert!(match_need(&dead, &knows, "2026-09-10").is_empty());
    }

    #[test]
    fn question_becomes_need() {
        let slice = compile_turn(&ChatTurn {
            speaker: "avery".into(),
            text: "Where did we eat in Prague?".into(),
            at: "2026-09-10".into(),
        });
        assert_eq!(slice.kind, SliceKind::Need);
        assert_eq!(slice.topic, "prague");
    }

    #[test]
    fn freshness_penalizes_old_prague_memory() {
        let need = compile_turn(&ChatTurn {
            speaker: "nova".into(),
            text: "Need a Prague restaurant from that trip?".into(),
            at: "2026-09-10".into(),
        });
        let knows = vec![
            know("ai-agents", "ai-agents", "2026-09-10"),
            know("prague", "prague", "2024-03-15"),
        ];
        let ranked = rank_knows(&need, &knows, "2026-09-10");
        assert_eq!(ranked[0].id, "prague");
        assert!(ranked[0].evidence_freshness_penalty > 0.5);
        assert_eq!(ranked[1].id, "ai-agents");
        assert_eq!(ranked[1].evidence_freshness_penalty, 0.0);
        assert!(ranked[0].score < ranked[0].topic_score);
    }
}
