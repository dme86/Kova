//! Offline-first Arch news matching. Login never performs network I/O.
use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Article {
    pub title: String,
    pub link: String,
    pub description: String,
    pub published: String,
}

fn tag(item: &str, name: &str) -> String {
    let open = format!("<{name}>");
    let close = format!("</{name}>");
    let Some((_, rest)) = item.split_once(&open) else {
        return String::new();
    };
    let Some((content, _)) = rest.split_once(&close) else {
        return String::new();
    };
    let content = content.trim().strip_prefix("<![CDATA[")
        .and_then(|s| s.strip_suffix("]]>"))
        .unwrap_or(content.trim());
    decode_entities(content)
}

fn decode_entities(s: &str) -> String {
    s.replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&apos;", "'")
        .replace("&amp;", "&")
}

pub fn parse_rss(input: &str) -> Vec<Article> {
    input.split("<item>").skip(1)
        .filter_map(|chunk| chunk.split_once("</item>").map(|(item, _)| item))
        .map(|item| Article {
            title: tag(item, "title"),
            link: tag(item, "link"),
            description: tag(item, "description"),
            published: tag(item, "pubDate"),
        })
        .filter(|item| item.link.starts_with("https://archlinux.org/") && !item.title.is_empty())
        .collect()
}

/// Exact token or package-family matching; never hide urgent generic advisories.
pub fn relevant(article: &Article, installed: &HashSet<String>) -> bool {
    let all = format!("{} {}", article.title, article.description).to_lowercase();
    if ["manual intervention", "action required", "system-wide", "user action required"]
        .iter().any(|s| all.contains(s)) {
        return true;
    }
    let words: HashSet<&str> = all.split(|c: char| !c.is_ascii_alphanumeric() && c != '-')
        .filter(|w| !w.is_empty())
        .collect();
    installed.iter().any(|pkg| {
        if words.contains(pkg.as_str()) {
            return true;
        }
        // A QEMU item should match qemu-system-x86_64; avoid generic prefixes.
        let family = pkg.split('-').next().unwrap_or("");
        family.len() >= 4
            && !["python", "linux", "lib", "perl", "rust", "base", "fonts", "gnome", "kde"]
                .contains(&family)
            && words.contains(family)
    })
}

pub fn installed_packages() -> Result<HashSet<String>, String> {
    let output = Command::new("pacman").arg("-Qq").output()
        .map_err(|e| format!("pacman -Qq: {e}"))?;
    if !output.status.success() {
        return Err("pacman -Qq failed".into());
    }
    Ok(String::from_utf8_lossy(&output.stdout)
        .lines().map(|s| s.to_lowercase()).collect())
}

pub fn state_path() -> PathBuf {
    let home = std::env::var_os("HOME").unwrap_or_default();
    let fallback = PathBuf::from(home).join(".local/state");
    let dir = std::env::var_os("XDG_STATE_HOME").map(PathBuf::from).unwrap_or(fallback);
    dir.join("kova/news-read")
}

pub fn read_state(path: &Path) -> HashSet<String> {
    fs::read_to_string(path).unwrap_or_default()
        .lines().map(str::to_owned).collect()
}

pub fn mark_read(path: &Path, link: &str) -> Result<(), String> {
    if !link.starts_with("https://archlinux.org/") || link.contains('\n') {
        return Err("invalid article link".into());
    }
    let mut state = read_state(path);
    state.insert(link.to_string());
    let parent = path.parent().ok_or("invalid state path")?;
    fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    let mut lines: Vec<_> = state.into_iter().collect();
    lines.sort();
    fs::write(path, format!("{}\n", lines.join("\n"))).map_err(|e| e.to_string())
}

pub fn run(args: &[String]) -> Result<(), String> {
    let path = std::env::var("KOVA_NEWS_CACHE")
        .unwrap_or_else(|_| "/var/cache/kova/arch-news.xml".into());
    let feed = match fs::read_to_string(&path) {
        Ok(v) => v,
        Err(_) => {
            if !args.iter().any(|a| a == "--summary" || a == "--cached") {
                println!("Arch news cache unavailable; a systemd timer fetches it when online.");
            }
            return Ok(());
        }
    };
    let all = parse_rss(&feed);
    let installed = installed_packages()?;
    let read = read_state(&state_path());
    let show_all = args.iter().any(|a| a == "--all");
    let articles: Vec<_> = all.iter().filter(|a| show_all || relevant(a, &installed)).collect();
    let unread: Vec<_> = articles.iter().filter(|a| !read.contains(&a.link)).collect();
    if args.iter().any(|a| a == "--summary" || a == "--cached") {
        if !unread.is_empty() {
            println!("Kova News: {} relevant unread Arch announcement(s) — run 'kova news'.", unread.len());
        }
        return Ok(());
    }
    if args.len() >= 2 && args[0] == "read" {
        let number = args[1].parse::<usize>().map_err(|_| "invalid article number")?;
        let article = articles.get(number.checked_sub(1).ok_or("invalid article")?)
            .ok_or("article not found")?;
        println!("{}\n{}\n{}\n\n{}", article.title, article.published, article.link, article.description);
        mark_read(&state_path(), &article.link)?;
        return Ok(());
    }
    println!("Kova News — {}/{} relevant announcements unread", unread.len(), articles.len());
    for (n, article) in articles.iter().enumerate() {
        let marker = if read.contains(&article.link) { " " } else { "*" };
        println!("  {} {:>2}. {}", marker, n + 1, article.title);
    }
    println!("Use 'kova news read N' to read and acknowledge a notice, 'kova news --all' for all news.");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn parses_and_matches_qemu_without_showing_unrelated() {
        let feed = r#"<rss><channel>
          <item><title>QEMU update requires action</title>
          <link>https://archlinux.org/news/qemu-update/</link>
          <description><![CDATA[Users of qemu should check configuration.]]></description>
          </item><item><title>PostgreSQL change</title>
          <link>https://archlinux.org/news/postgresql/</link></item>
          </channel></rss>"#;
        let articles = parse_rss(feed);
        assert_eq!(articles.len(), 2);
        let installed = HashSet::from(["qemu-system-x86".into()]);
        assert!(relevant(&articles[0], &installed));
        assert!(!relevant(&articles[1], &installed));
    }
    #[test]
    fn shows_urgent_advisories() {
        let article = Article { title: "Manual intervention required".into(),
            link: "https://archlinux.org/news/example/".into(),
            description: "".into(), published: "".into() };
        assert!(relevant(&article, &HashSet::new()));
    }
    #[test]
    fn rejects_non_arch_feed_links() {
        assert!(parse_rss("<item><title>Fake</title><link>https://evil.invalid</link></item>").is_empty());
    }
}
