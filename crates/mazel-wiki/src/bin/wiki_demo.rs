use std::path::PathBuf;

use mazel_wiki::{compile_turn, compile_turns, rank_knows, ChatTurn, SliceKind};

fn main() {
    let root = std::env::args()
        .nth(1)
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../.."));
    let root = root.canonicalize().unwrap_or(root);
    let today = "2026-09-10";

    let turns = [
        ChatTurn {
            speaker: "nova.avery@mazel.ai".into(),
            text: "AI agents talk for humans. Connect is the human moment. Badge before wake."
                .into(),
            at: today.into(),
        },
        ChatTurn {
            speaker: "avery@mazel.ai".into(),
            text: "I think we had duck near the river in Prague. Streets are fuzzy now.".into(),
            at: "2024-03-15".into(),
        },
        ChatTurn {
            speaker: "kai.sam@mazel.ai".into(),
            text: "Where did we eat in Prague?".into(),
            at: today.into(),
        },
    ];

    println!("── Mazel wiki ──────────────────────────────────");
    println!("Karpathy-style knows / needs. Fake turns only.");
    println!("root  {}", root.display());
    println!("");

    let paths = compile_turns(&root, &turns).expect("write wiki slices");
    println!("wrote");
    for path in &paths {
        println!("  {}", path.display());
    }

    let slices: Vec<_> = turns.iter().map(compile_turn).collect();
    let knows: Vec<_> = slices
        .iter()
        .filter(|s| s.kind == SliceKind::Know)
        .cloned()
        .collect();
    let need = slices
        .iter()
        .find(|s| s.kind == SliceKind::Need)
        .expect("need slice");

    println!("");
    println!("slices");
    for slice in &slices {
        println!(
            "  {kind:4}  {id:12}  as_of={as_of}  topic={topic}",
            kind = slice.kind.label(),
            id = slice.id,
            as_of = slice.as_of,
            topic = slice.topic
        );
    }

    println!("");
    println!("JIT rank  need={}  today={today}", need.topic);
    println!("score = topic_score - evidence_freshness_penalty");
    for (i, row) in rank_knows(need, &knows, today).iter().enumerate() {
        println!(
            "  {}. {:12}  score={:+.2}  topic={:.2}  freshness_penalty={:.2}  age={}d  as_of={}",
            i + 1,
            row.id,
            row.score,
            row.topic_score,
            row.evidence_freshness_penalty,
            row.age_days,
            row.as_of
        );
    }
}
