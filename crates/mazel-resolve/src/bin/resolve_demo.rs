use mazel_core::Handle;
use mazel_resolve::{parse_txt, Resolver, StaticResolver};

fn main() {
    let resolver = StaticResolver::demo();
    println!("── Mazel resolve ────────────────────────────────");
    println!("DNS-shaped stub. No network. map + fake TXT.");
    println!("");

    for raw in ["@kai", "@nova", "kai@mazel", "@ghost"] {
        match Handle::parse(raw) {
            Err(err) => {
                println!("{raw:12}  parse error: {err}");
            }
            Ok(handle) => match resolver.lookup(&handle) {
                Ok(found) => {
                    println!(
                        "{raw:12}  → {id}  sources={sources}",
                        id = found.handle.id(),
                        sources = format_sources(&found.sources)
                    );
                    for url in &found.card_urls {
                        println!("              {url}");
                    }
                    if let Some(txt) = resolver.txt_for(&handle) {
                        println!("              TXT  {txt}");
                        for url in parse_txt(txt) {
                            println!("              TXT→ {url}");
                        }
                    }
                }
                Err(err) => println!("{raw:12}  → {id}  {err}", id = handle.id()),
            },
        }
        println!("");
    }
}

fn format_sources(sources: &[mazel_resolve::ResolveSource]) -> String {
    sources
        .iter()
        .map(|s| match s {
            mazel_resolve::ResolveSource::StaticMap => "map",
            mazel_resolve::ResolveSource::Txt => "txt",
        })
        .collect::<Vec<_>>()
        .join("+")
}
