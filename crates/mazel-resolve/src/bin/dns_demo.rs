use mazel_core::Handle;
use mazel_resolve::{Resolver, ZoneFile};

fn main() {
    let path = ZoneFile::default_path();
    let zone = ZoneFile::load(&path).unwrap_or_else(|err| {
        eprintln!("dns_demo failed: {err}");
        std::process::exit(1);
    });

    println!("── Mazel DNS ────────────────────────────────────────");
    println!("TXT fixture. No live DNS. handle → card.");
    println!("─────────────────────────────────────────────────────");
    println!();
    println!(
        "zone    {}  origin={}",
        path.display(),
        zone.origin
    );
    println!();

    let mut kai_card = String::new();
    let mut kai_id = String::new();
    let mut avery_id = String::new();

    for raw in ["@kai", "kai@mazel", "@avery", "avery@mazel", "@ghost"] {
        match Handle::parse(raw) {
            Err(err) => println!("{raw:14}  parse error: {err}"),
            Ok(handle) => match zone.lookup(&handle) {
                Ok(found) => {
                    let card = found.card_urls.first().cloned().unwrap_or_default();
                    let haah = if found.haah { "1" } else { "0" };
                    println!(
                        "{raw:14}  → {id}  card={card}  haah={haah}  source=txt",
                        id = found.handle.id()
                    );
                    if found.handle.local() == "kai" && kai_card.is_empty() {
                        kai_id = found.handle.id().to_string();
                        kai_card = card;
                    }
                    if found.handle.local() == "avery" && avery_id.is_empty() {
                        avery_id = found.handle.id().to_string();
                    }
                }
                Err(err) => println!(
                    "{raw:14}  → {id}  error={err}",
                    id = handle.id()
                ),
            },
        }
    }

    println!();
    print!("{}", zone.mock_dig(&Handle::parse("@kai").unwrap()));
    println!();
    println!(
        "ok  kai={kai_id}  avery={avery_id}  card={kai_card}  haah=1  source=txt"
    );
}