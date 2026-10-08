//! Mazel spine types.
//!
//! Talk through their agent. Connect is the human moment.

mod a2a;
mod badge;
mod consent;
mod crawl;
mod graph;
mod handle;
mod labels;
mod connect;
mod session;
mod warm_packet;
mod wings;

pub use a2a::{AgentCapabilities, AgentCard, Cast, HandleRecord, RotationRecord, AgentExtension, AgentInterface, AgentProvider, AgentSkill, HaahParams, Message, Part, PulseConfig, Role, SendMessageParams, SendMessageRequest, A2A_VERSION, HAAH_URI};
pub use badge::{Badge, BadgeError, MintSource, MintedBadge, PullMatch, WakeContext};
pub use consent::{Consent, ConsentError, ConsentLedger};
pub use crawl::{Action, Decision, Proposer, Have, Intro, IntroState, Match, Need, NeedVisibility, Outcome, Person, TrustTier, Vouch};
pub use graph::{Edge, EdgeType, Entity, EntityKind};
pub use handle::{Handle, HandleError};
pub use labels::{format as format_label, label, put as put_label, reset as reset_labels, IDS as LABEL_IDS};
pub use connect::{allow_connect, ConnectError};
pub use session::SessionKind;
pub use warm_packet::{Participant, ParticipantRole, TranscriptLine, WarmPacket, WarmPacketError};
pub use wings::{parse_wing, WingCommand, WingError};

#[cfg(test)]
mod tests {
    use super::*;

    fn avery_agent() -> Handle {
        Handle::new("nova.avery@mazel.ai", Some("https://mazel.ai/cards/nova".into())).unwrap()
    }

    fn kai_agent() -> Handle {
        Handle::new("kai.sam@mazel.ai", None).unwrap()
    }

    fn avery_human() -> Handle {
        Handle::new("avery@mazel.ai", Some("https://mazel.ai/cards/avery".into())).unwrap()
    }

    fn sam_human() -> Handle {
        Handle::new("sam@mazal.ai", None).unwrap()
    }

    #[test]
    fn handle_rejects_empty() {
        assert!(Handle::new("", None).is_err());
        assert!(Handle::new("   ", None).is_err());
    }

    #[test]
    fn handle_accepts_stub_and_optional_card() {
        let h = Handle::new("avery@mazel.ai", Some("https://mazel.ai/cards/avery".into())).unwrap();
        assert_eq!(h.id(), "avery@mazel.ai");
        assert_eq!(h.card_url(), Some("https://mazel.ai/cards/avery"));
    }

    #[test]
    fn handle_parses_at_name_and_name_at_mazel() {
        let short = Handle::parse("@kai").unwrap();
        assert_eq!(short.id(), "kai@mazel");
        assert_eq!(short.local(), "kai");
        assert_eq!(short.zone(), "mazel");

        let zoned = Handle::parse("nova@mazel").unwrap();
        assert_eq!(zoned.id(), "nova@mazel");
        assert_eq!(Handle::parse("Nova@Mazel").unwrap().id(), "nova@mazel");
        assert_eq!(Handle::parse("@").unwrap_err(), HandleError::Malformed);
        assert_eq!(Handle::parse("kai").unwrap_err(), HandleError::Malformed);
        assert_eq!(Handle::parse("kai@").unwrap_err(), HandleError::Malformed);
        assert!(Handle::parse("@mazel").unwrap().is_discovery_sink());
        assert!(Handle::parse("need@mazel").unwrap().is_discovery_sink());
        assert!(Handle::parse("mazel@mazel").unwrap().is_discovery_sink());
        assert!(Handle::parse("@open").unwrap().is_discovery_sink());
        assert!(Handle::parse("open@mazel").unwrap().is_discovery_sink());
        assert!(!Handle::parse("@kai").unwrap().is_discovery_sink());
    }

    #[test]
    fn session_wings() {
        assert_eq!(SessionKind::Direct.id(), "direct");
        assert_eq!(SessionKind::Intro.id(), "intro");
        assert_eq!(SessionKind::Direct.wings(), 1);
        assert_eq!(SessionKind::Intro.wings(), 2);
        assert_eq!(SessionKind::Direct.wing_mark(), "🪽");
        assert_eq!(SessionKind::Intro.wing_mark(), "🪽🪽");
    }

    #[test]
    fn badge_variants_validate() {
        let vouch = Badge::Vouch {
            voucher: avery_agent(),
            note: "I know this person.".into(),
        };
        assert!(vouch.validate().is_ok());

        let pull = Badge::PullIntent {
            actor: avery_agent(),
            intent: "Wake the humans to review the connect path.".into(),
        };
        assert!(pull.validate().is_ok());

        let invite = Badge::InviteToken {
            token: "inv_spine_v0_demo".into(),
            issuer: kai_agent(),
        };
        assert!(invite.validate().is_ok());

        let pow = Badge::ProofOfWork {
            nonce: "deadbeef".into(),
            difficulty: 8,
        };
        assert!(pow.validate().is_ok());
    }

    #[test]
    fn badge_rejects_empty_fields() {
        let bad = Badge::Vouch {
            voucher: avery_agent(),
            note: "  ".into(),
        };
        assert!(bad.validate().is_err());

        let bad_token = Badge::InviteToken {
            token: "short".into(),
            issuer: kai_agent(),
        };
        assert!(bad_token.validate().is_err());

        let bad_pow = Badge::ProofOfWork {
            nonce: "aa".into(),
            difficulty: 0,
        };
        assert!(bad_pow.validate().is_err());
    }

    #[test]
    fn dual_consent_required_before_ready() {
        let mut ledger = ConsentLedger::new(
            "ctx_demo",
            vec![avery_agent(), kai_agent()],
        );
        assert!(!ledger.dual_consent());
        ledger.grant(avery_agent()).unwrap();
        assert!(!ledger.dual_consent());
        ledger.grant(kai_agent()).unwrap();
        assert!(ledger.dual_consent());
        assert!(ledger.missing().is_empty());
    }

    #[test]
    fn consent_rejects_strangers_and_is_idempotent() {
        let mut ledger = ConsentLedger::new("ctx_demo", vec![avery_agent(), kai_agent()]);
        assert!(ledger.grant(sam_human()).is_err());
        ledger.grant(avery_agent()).unwrap();
        ledger.grant(avery_agent()).unwrap();
        assert_eq!(ledger.granted().len(), 1);
    }

    #[test]
    fn warm_packet_requires_valid_badge_and_dual_consent() {
        let badge = Badge::PullIntent {
            actor: avery_agent(),
            intent: "Connect so the humans can see spine-v0.".into(),
        };
        let mut ledger = ConsentLedger::new("ctx_connect", vec![avery_agent(), kai_agent()]);
        ledger.grant(avery_agent()).unwrap();

        let participants = vec![
            Participant::new(avery_agent(), ParticipantRole::Agent),
            Participant::new(kai_agent(), ParticipantRole::Agent),
            Participant::new(avery_human(), ParticipantRole::Human),
            Participant::new(sam_human(), ParticipantRole::Human),
        ];

        let early = WarmPacket::assemble(warm_packet::Assemble {
            context_id: "ctx_connect".into(),
            session_kind: SessionKind::Direct,
            participants: participants.clone(),
            badge: badge.clone(),
            ledger: &ledger,
            topic: Some("spine-v0".into()),
            subject: Some(avery_human()),
            summary: "Agents aligned; humans joining.".into(),
            transcript_excerpt: vec![TranscriptLine::new(
                avery_agent(),
                "Propose connect.",
            )],
            committed_at: "2026-09-10T07:00:00Z".into(),
        });
        assert_eq!(early.unwrap_err(), WarmPacketError::MissingConsent);

        ledger.grant(kai_agent()).unwrap();
        let packet = WarmPacket::assemble(warm_packet::Assemble {
            context_id: "ctx_connect".into(),
            session_kind: SessionKind::Direct,
            participants,
            badge,
            ledger: &ledger,
            topic: Some("spine-v0".into()),
            subject: Some(avery_human()),
            summary: "Agents aligned; humans joining.".into(),
            transcript_excerpt: vec![
                TranscriptLine::new(avery_agent(), "Shipping spine v0 today."),
                TranscriptLine::new(kai_agent(), "Badge then dual consent. Propose connect."),
            ],
            committed_at: "2026-09-10T07:00:00Z".into(),
        })
        .unwrap();

        assert_eq!(packet.session_kind(), SessionKind::Direct);
        let json = serde_json::to_string_pretty(&packet).unwrap();
        assert!(json.contains("\"session_kind\": \"direct\""));
        assert!(json.contains("pull_intent"));
        assert!(json.contains("ctx_connect"));
    }

    #[test]
    fn badge_json_is_tagged() {
        let badge = Badge::InviteToken {
            token: "inv_enough_chars".into(),
            issuer: kai_agent(),
        };
        let v = serde_json::to_value(&badge).unwrap();
        assert_eq!(v["kind"], "invite_token");
        assert_eq!(v["token"], "inv_enough_chars");
    }

    fn dual_ledger() -> ConsentLedger {
        let mut ledger = ConsentLedger::new("ctx_gate", vec![avery_agent(), kai_agent()]);
        ledger.grant(avery_agent()).unwrap();
        ledger.grant(kai_agent()).unwrap();
        ledger
    }

    #[test]
    fn connect_rejects_missing_badge() {
        let err = allow_connect(None, &dual_ledger(), None).unwrap_err();
        assert_eq!(err, ConnectError::MissingBadge);
    }

    #[test]
    fn connect_rejects_single_consent_even_with_valid_badge() {
        let badge = Badge::InviteToken {
            token: "inv_enough_chars".into(),
            issuer: kai_agent(),
        };
        let mut ledger = ConsentLedger::new("ctx_gate", vec![avery_agent(), kai_agent()]);
        ledger.grant(avery_agent()).unwrap();
        assert_eq!(
            allow_connect(Some(&badge), &ledger, None).unwrap_err(),
            ConnectError::MissingConsent
        );
    }

    #[test]
    fn pull_intent_requires_matching_topic() {
        let badge = Badge::PullIntent {
            actor: avery_agent(),
            intent: "Wake humans about spine-v0 connect.".into(),
        };
        let subject = avery_human();
        let ctx_ok = WakeContext {
            topic: "spine-v0",
            subject: Some(&subject),
        };
        let ctx_bad = WakeContext {
            topic: "prague-trip",
            subject: Some(&subject),
        };
        assert!(badge.validate_for_wake(&ctx_ok).is_ok());
        assert_eq!(
            badge.validate_for_wake(&ctx_bad).unwrap_err(),
            BadgeError::TopicMismatch
        );
        assert_eq!(
            allow_connect(Some(&badge), &dual_ledger(), Some(&ctx_bad)).unwrap_err(),
            ConnectError::Badge(BadgeError::TopicMismatch)
        );
    }

    #[test]
    fn vouch_requires_voucher_handle_and_rejects_self_vouch() {
        let empty: Badge =
            serde_json::from_str(r#"{"kind":"vouch","voucher":{"id":"  "},"note":"I know them."}"#)
                .unwrap();
        assert_eq!(empty.validate().unwrap_err(), BadgeError::MissingVoucher);

        let subject = avery_human();
        let self_vouch = Badge::Vouch {
            voucher: subject.clone(),
            note: "I vouch for myself.".into(),
        };
        let ctx = WakeContext {
            topic: "intro",
            subject: Some(&subject),
        };
        assert_eq!(
            self_vouch.validate_for_wake(&ctx).unwrap_err(),
            BadgeError::SelfVouch
        );

        let ok = Badge::Vouch {
            voucher: kai_agent(),
            note: "I know Avery.".into(),
        };
        assert!(ok.validate_for_wake(&ctx).is_ok());
    }

    #[test]
    fn invite_and_pow_have_their_own_reject_paths() {
        let no_issuer: Badge = serde_json::from_str(
            r#"{"kind":"invite_token","token":"inv_enough_chars","issuer":{"id":""}}"#,
        )
        .unwrap();
        assert_eq!(no_issuer.validate().unwrap_err(), BadgeError::MissingIssuer);

        let not_hex = Badge::ProofOfWork {
            nonce: "not-hex!!".into(),
            difficulty: 8,
        };
        assert_eq!(not_hex.validate().unwrap_err(), BadgeError::WeakNonce);
    }

    #[test]
    fn connect_assemble_rejects_topic_mismatch() {
        let badge = Badge::PullIntent {
            actor: avery_agent(),
            intent: "Wake them about dinner.".into(),
        };
        let ledger = dual_ledger();
        let err = WarmPacket::assemble(warm_packet::Assemble {
            context_id: "ctx_connect".into(),
            session_kind: SessionKind::Direct,
            participants: vec![],
            badge,
            ledger: &ledger,
            topic: Some("spine-v0".into()),
            subject: Some(avery_human()),
            summary: "Nope.".into(),
            transcript_excerpt: vec![],
            committed_at: "2026-09-10T07:00:00Z".into(),
        })
        .unwrap_err();
        assert_eq!(err, WarmPacketError::Badge(BadgeError::TopicMismatch));
    }
}
