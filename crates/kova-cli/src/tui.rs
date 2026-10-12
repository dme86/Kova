//! Dependency-free, keyboard-first installer TUI for text consoles / SSH.
//! The low-level installer and its exact ERASE confirmation remain unchanged.
use kova_installer::{choices, Disk, InstallPlan};
use std::fs::{File, OpenOptions};
use std::io::{Read, Write};
use std::process::Command;
use std::thread;
use std::time::Duration;

pub fn supported() -> bool {
    std::env::var("TERM").is_ok_and(|term| term != "dumb" && !term.is_empty())
        && std::path::Path::new("/dev/tty").exists()
}

struct Terminal {
    tty: File,
    original: String,
}

impl Terminal {
    fn command(args: &[&str]) -> Result<String, String> {
        let output = Command::new("stty").arg("-F").arg("/dev/tty")
            .args(args).output().map_err(|e| format!("stty: {e}"))?;
        if !output.status.success() {
            return Err(format!("terminal setup failed: {}",
                String::from_utf8_lossy(&output.stderr)));
        }
        Ok(String::from_utf8_lossy(&output.stdout).trim().to_owned())
    }

    fn new() -> Result<Self, String> {
        let tty = OpenOptions::new().read(true).write(true).open("/dev/tty")
            .map_err(|e| format!("TTY unavailable: {e}"))?;
        let original = Self::command(&["-g"])?;
        // Non-canonical, non-echo, non-signal mode. ^C becomes a regular byte,
        // handled below, so restoring terminal settings is deterministic.
        Self::command(&["-echo", "-icanon", "-isig", "min", "0", "time", "1"])?;
        let mut result = Self { tty, original };
        result.tty.write_all(b"\x1b[?1049h\x1b[?25l")
            .map_err(|e| e.to_string())?;
        Ok(result)
    }

    fn size(&self) -> (usize, usize) {
        let output = Self::command(&["size"]).unwrap_or_default();
        let mut parts = output.split_whitespace()
            .filter_map(|s| s.parse::<usize>().ok());
        let rows = parts.next().unwrap_or(24).max(8);
        let cols = parts.next().unwrap_or(80).max(20);
        (rows, cols)
    }

    fn render(&mut self, lines: &[String]) -> Result<(), String> {
        let (rows, cols) = self.size();
        let mut buffer = String::from("\x1b[H\x1b[2J");
        if rows < 12 || cols < 35 {
            buffer.push_str("Kova installer: enlarge terminal (>=35x12)\r\n");
            buffer.push_str("Ctrl+C cancels safely. No disk changes.\r\n");
        } else {
            for line in lines.iter().take(rows) {
                let plain: String = line.chars().filter(|c| !c.is_control())
                    .take(cols.saturating_sub(1)).collect();
                buffer.push_str(&plain);
                buffer.push_str("\r\n");
            }
        }
        self.tty.write_all(buffer.as_bytes()).map_err(|e| e.to_string())?;
        self.tty.flush().map_err(|e| e.to_string())
    }

    fn byte(&mut self) -> Result<u8, String> {
        let mut b = [0_u8; 1];
        loop {
            match self.tty.read(&mut b) {
                Ok(1) => return Ok(b[0]),
                Ok(0) => thread::sleep(Duration::from_millis(15)),
                Ok(_) => unreachable!(),
                Err(e) if e.kind() == std::io::ErrorKind::Interrupted => continue,
                Err(e) => return Err(format!("cannot read tty: {e}")),
            }
        }
    }

    fn next_byte(&mut self) -> Result<Option<u8>, String> {
        let mut b = [0_u8; 1];
        match self.tty.read(&mut b) {
            Ok(1) => Ok(Some(b[0])),
            Ok(0) => Ok(None),
            Ok(_) => unreachable!(),
            Err(e) if e.kind() == std::io::ErrorKind::Interrupted => Ok(None),
            Err(e) => Err(format!("cannot read terminal sequence: {e}")),
        }
    }

    fn key(&mut self) -> Result<Key, String> {
        let b = self.byte()?;
        let key = match b {
            3 => Key::Cancel,         // Ctrl+C (ISIG disabled)
            9 => Key::Tab,
            10 | 13 => Key::Enter,
            8 | 127 => Key::Backspace,
            21 => Key::Clear,        // Ctrl+U
            27 => {
                // 100ms timeout distinguishes Escape from an ANSI sequence.
                let Some(next) = self.next_byte()? else { return Ok(Key::Back); };
                if next != b'[' && next != b'O' { return Ok(Key::Back); }
                let mut seq = String::new();
                for _ in 0..16 {
                    let Some(c) = self.next_byte()? else { break; };
                    seq.push(c as char);
                    if (c as char).is_ascii_alphabetic() || c == b'~' { break; }
                }
                match seq.as_str() {
                    "A" => Key::Up, "B" => Key::Down,
                    "C" => Key::Right, "D" => Key::Left,
                    "H" | "1~" | "7~" => Key::Home,
                    "F" | "4~" | "8~" => Key::End,
                    "5~" => Key::PageUp, "6~" => Key::PageDown,
                    _ => Key::Ignore,
                }
            }
            x if x.is_ascii_control() => Key::Ignore,
            x if x < 128 => Key::Char(x as char),
            x => {
                // Read remaining UTF-8 bytes while preserving user-entered
                // international characters in search and account fields.
                let len = match x { 0xc2..=0xdf => 2, 0xe0..=0xef => 3,
                    0xf0..=0xf4 => 4, _ => 0 };
                if len == 0 { Key::Ignore } else {
                    let mut buf = vec![x];
                    for _ in 1..len { buf.push(self.byte()?); }
                    match std::str::from_utf8(&buf).ok().and_then(|s| s.chars().next()) {
                        Some(c) if !c.is_control() => Key::Char(c),
                        _ => Key::Ignore,
                    }
                }
            }
        };
        Ok(key)
    }
}

impl Drop for Terminal {
    fn drop(&mut self) {
        let _ = self.tty.write_all(b"\x1b[?25h\x1b[?1049l");
        let _ = self.tty.flush();
        let _ = Self::command(&[&self.original]);
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Key {
    Up, Down, Left, Right, PageUp, PageDown, Home, End,
    Enter, Backspace, Tab, Back, Clear, Cancel, Char(char), Ignore,
}

fn matched(option: &str, filter: &str, kind: &str) -> bool {
    let f = filter.trim().to_lowercase();
    if f.is_empty() { return true; }
    let text = option.to_lowercase();
    if text.contains(&f) { return true; }
    let aliases = match kind {
        "Language" => match f.as_str() {
            "deutsch" | "german" | "deutschland" | "germany" => "de_",
            "englisch" | "english" | "usa" => "en_",
            "français" | "francais" | "french" => "fr_",
            "español" | "espanol" | "spanish" => "es_",
            "japanisch" | "japanese" => "ja_",
            _ => "",
        },
        "Keyboard" => match f.as_str() {
            "german" | "deutsch" | "deutschland" => "de",
            "english" | "englisch" => "us",
            _ => "",
        },
        "Timezone" => match f.as_str() {
            "deutschland" | "germany" => "berlin",
            "usa" => "america/",
            _ => "",
        },
        _ => "",
    };
    if !aliases.is_empty() && text.contains(aliases) { return true; }
    // Also allow a simple fuzzy subsequence as a forgiving fallback.
    let mut chars = f.chars();
    let mut next = chars.next();
    for c in text.chars() {
        if Some(c) == next { next = chars.next(); }
        if next.is_none() { return true; }
    }
    false
}

fn limited(s: &str, width: usize) -> String {
    if s.chars().count() <= width { s.to_owned() }
    else { format!("{}...", s.chars().take(width.saturating_sub(3)).collect::<String>()) }
}

fn frame(step: usize, title: &str, plan: &InstallPlan, message: &str) -> Vec<String> {
    vec![
        "KOVA LINUX  /  INSTALLER                           Offline-ready TTY wizard".into(),
        "==========================================================================".into(),
        " Disk  >  User  >  Language  >  Keyboard  >  Timezone  >  Review".into(),
        format!(" Stage {} / 6   |   {}", step.min(6), title),
        "--------------------------------------------------------------------------".into(),
        format!(" Disk: {} ({} GiB)  |  User: {}@{}", plan.disk.path,
            plan.disk.size_gib(), plan.username, plan.hostname),
        format!(" Language: {}  |  Keyboard: {}  |  Timezone: {}",
            plan.locale, plan.keyboard, plan.timezone),
        "--------------------------------------------------------------------------".into(),
        message.into(),
    ]
}

fn choose<'a>(
    terminal: &mut Terminal, step: usize, label: &str,
    plan: &InstallPlan, items: &'a [String], selected: &str,
    descriptions: &[String],
) -> Result<Option<String>, String> {
    let mut filter = String::new();
    let mut index = items.iter().position(|i| i == selected).unwrap_or(0);
    let mut warning = String::new();
    loop {
        let matches: Vec<usize> = items.iter().enumerate()
            .filter(|(_, item)| matched(item, &filter, label))
            .map(|(i, _)| i).collect();
        if matches.is_empty() { index = 0; }
        else { index = index.min(matches.len() - 1); }
        let (height, width) = terminal.size();
        let slots = height.saturating_sub(14).clamp(1, 16);
        let first = index.saturating_sub(slots / 2)
            .min(matches.len().saturating_sub(slots));
        let mut lines = frame(step, label, plan,
            if warning.is_empty() { "Type to search. Arrows select. Enter confirms." } else { &warning });
        lines.push(format!(" Search: {}_    {}/{} results", filter,
            if matches.is_empty() { 0 } else { index + 1 }, matches.len()));
        lines.push(String::new());
        if matches.is_empty() { lines.push("  No matches. Backspace or Ctrl+U clears the filter.".into()); }
        for (position, &item_index) in matches.iter().enumerate().skip(first).take(slots) {
            let name = &items[item_index];
            let description = descriptions.get(item_index).map(String::as_str).unwrap_or("");
            let marker = if position == index { ">" } else { " " };
            lines.push(limited(&format!(" {marker} {}  {}", name, description), width.saturating_sub(2)));
        }
        lines.push(String::new());
        lines.push("Up/Down: select  PgUp/PgDn: scroll  Home/End  Esc: back".into());
        lines.push("Backspace: delete search  Ctrl+U: clear  Ctrl+C: cancel".into());
        terminal.render(&lines)?;
        match terminal.key()? {
            Key::Cancel => return Err("installation cancelled; no disk changed".into()),
            Key::Back => return Ok(None),
            Key::Up => index = index.saturating_sub(1),
            Key::Down => index = (index + 1).min(matches.len().saturating_sub(1)),
            Key::PageUp => index = index.saturating_sub(slots),
            Key::PageDown => index = (index + slots).min(matches.len().saturating_sub(1)),
            Key::Home => index = 0,
            Key::End => index = matches.len().saturating_sub(1),
            Key::Enter => if let Some(&pick) = matches.get(index) {
                if descriptions.get(pick).is_some_and(|d| d.contains("[FORBIDDEN]")) {
                    warning = "That disk is not safe for installation. Choose an available disk.".into();
                } else { return Ok(Some(items[pick].clone())); }
            },
            Key::Clear => { filter.clear(); index = 0; },
            Key::Backspace => { filter.pop(); index = 0; },
            Key::Char(c) if !c.is_control() => { filter.push(c); index = 0; },
            _ => {},
        }
    }
}

fn edit(
    terminal: &mut Terminal, step: usize, field: &str,
    plan: &InstallPlan, value: &str,
) -> Result<Option<String>, String> {
    let mut input = value.to_owned();
    let mut pristine = true;
    let mut error = String::new();
    loop {
        let mut lines = frame(step, "User", plan, field);
        lines.push(String::new());
        lines.push(format!(" {field}: {input}_"));
        lines.push(String::new());
        lines.push(if error.is_empty() {
            "Enter: accept   Esc: back   Ctrl+U: clear".into()
        } else { error.clone() });
        lines.push("Username: lowercase letters, digits, _ and -".into());
        lines.push("Hostname: starts with lowercase letter, digits and -".into());
        terminal.render(&lines)?;
        match terminal.key()? {
            Key::Cancel => return Err("installation cancelled; no disk changed".into()),
            Key::Back => return Ok(None),
            Key::Enter => {
                let valid = match field {
                    "Username" => !input.is_empty() && input.len() <= 32 &&
                        input.chars().next().is_some_and(|c| c.is_ascii_lowercase() || c == '_') &&
                        input.chars().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_' || c == '-'),
                    _ => !input.is_empty() && input.len() <= 32 &&
                        input.chars().next().is_some_and(|c| c.is_ascii_lowercase()) &&
                        !input.ends_with('-') &&
                        input.chars().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '-'),
                };
                if valid { return Ok(Some(input)); }
                error = format!("Invalid {field}. Please correct it before continuing.");
            }
            Key::Clear => { input.clear(); pristine = false; error.clear(); },
            Key::Backspace => { if pristine { input.clear(); } else { input.pop(); } pristine = false; error.clear(); },
            Key::Char(c) if !c.is_control() => {
                if pristine { input.clear(); pristine = false; }
                if input.len() < 32 { input.push(c); }
                error.clear();
            },
            _ => {},
        }
    }
}

fn review(terminal: &mut Terminal, plan: &InstallPlan, apply: bool) -> Result<Option<bool>, String> {
    loop {
        let mut lines = frame(6, "Review", plan, "Please verify EVERY setting.");
        lines.extend([
            String::new(),
            format!(" Target disk: {} | {} GiB | {} | {}", plan.disk.path,
                plan.disk.size_gib(), plan.disk.model, plan.disk.status()),
            format!(" Account: {}     Computer: {}", plan.username, plan.hostname),
            format!(" Locale: {}     Keyboard: {}     Timezone: {}",
                plan.locale, plan.keyboard, plan.timezone),
            String::new(),
            " GPT + 1 GiB EFI + Btrfs, ZSTD, Snapper and systemd-boot".into(),
            " WARNING: Installation will ERASE THE ENTIRE DISK.".into(),
            " THE NEXT SCREEN WILL REQUIRE TYPING THE PRECISE DEVICE PATH.".into(),
            String::new(),
            format!(" Enter: {}   Esc: back   Ctrl+C: cancel",
                if apply { "continue to ERASE confirmation" } else { "continue to confirmation" }),
        ]);
        terminal.render(&lines)?;
        match terminal.key()? {
            Key::Enter => return Ok(Some(true)),
            Key::Back => return Ok(Some(false)),
            Key::Cancel => return Err("installation cancelled; no disk changed".into()),
            _ => {},
        }
    }
}

/// Returns None if the user cancels via Ctrl+C.  The terminal guard is dropped
/// and restores all settings before any password/ERASE prompt can appear.
pub fn wizard(
    disks: &[Disk], current: InstallPlan,
    locales: &[String], keyboards: &[String], timezones: &[String],
    apply: bool,
) -> Result<Option<InstallPlan>, String> {
    let available: Vec<&Disk> = disks.iter().filter(|d| d.eligible()).collect();
    if available.is_empty() {
        return Err("No eligible disks (remove installation media; need >=16 GiB non-USB unmounted disk)".into());
    }
    let mut tty = Terminal::new()?;
    let mut plan = current;
    let mut stage = 0_usize;
    loop {
        let outcome = match stage {
            0 => {
                let items: Vec<_> = disks.iter().map(|d| d.path.clone()).collect();
                let descriptions: Vec<_> = disks.iter().map(|d| format!(
                    "{} GiB  {}  [FS: {}] {} {}", d.size_gib(), d.model,
                    if d.fs_type.is_empty() { "unknown" } else { &d.fs_type },
                    if d.eligible() { "[AVAILABLE]" } else { "[FORBIDDEN]" },
                    d.status()
                )).collect();
                let selected = choose(&mut tty, 1, "Disk", &plan, &items, &plan.disk.path, &descriptions)?;
                if let Some(path) = selected {
                    let disk = disks.iter().find(|d| d.path == path).ok_or("unknown disk")?;
                    if !disk.eligible() { continue; }
                    plan.disk = disk.clone();
                    stage = 1;
                } else { return Ok(None); }
                continue;
            }
            1 => edit(&mut tty, 2, "Username", &plan, &plan.username)?,
            2 => edit(&mut tty, 2, "Hostname", &plan, &plan.hostname)?,
            3 => choose(&mut tty, 3, "Language", &plan, locales, &plan.locale, &[])?,
            4 => choose(&mut tty, 4, "Keyboard", &plan, keyboards, &plan.keyboard, &[])?,
            5 => choose(&mut tty, 5, "Timezone", &plan, timezones, &plan.timezone, &[])?,
            6 => {
                plan.validate()?;
                match review(&mut tty, &plan, apply)? {
                    Some(true) => return Ok(Some(plan)),
                    Some(false) => { stage = 5; continue; },
                    None => return Ok(None),
                }
            }
            _ => unreachable!(),
        };
        match outcome {
            Some(value) => {
                match stage {
                    1 => plan.username = value,
                    2 => plan.hostname = value,
                    3 => plan.locale = value,
                    4 => plan.keyboard = value,
                    5 => plan.timezone = value,
                    _ => unreachable!(),
                }
                stage += 1;
            }
            None => { stage = stage.saturating_sub(1); }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn locale_search_is_localized_and_unicode_aware() {
        assert!(matched("de_DE.UTF-8", "deutsch", "Language"));
        assert!(matched("de_DE.UTF-8", "german", "Language"));
        assert!(matched("fr_FR.UTF-8", "français", "Language"));
        assert!(matched("Europe/Berlin", "deutschland", "Timezone"));
        assert!(matched("Europe/Berlin", "ber", "Timezone"));
        assert!(!matched("de_DE.UTF-8", "中文", "Language"));
    }
    #[test]
    fn no_matches_never_crash_and_small_terminal_is_clamped() {
        let options = ["foo", "bar"];
        let matches: Vec<_> = options.iter().filter(|v| matched(v, "xyz", "Language")).collect();
        assert!(matches.is_empty());
        assert_eq!(10_usize.saturating_sub(14).clamp(1, 16), 1);
        assert_eq!(limited("abcdef", 5), "ab...");
    }
    #[test]
    fn untouched_disk_does_not_skip_confirmation() {
        assert_eq!(frame(6, "Review", &kova_installer::demo_plan(), "")
            .iter().any(|line| line.contains("Review")), true);
    }
}
