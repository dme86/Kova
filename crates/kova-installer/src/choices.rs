//! Offline lists used by the minimal installation wizard.
use std::fs;
use std::path::{Path, PathBuf};

pub fn parse_locales(content: &str) -> Vec<String> {
    let mut names = Vec::new();
    for line in content.lines() {
        let line = line.trim_start().trim_start_matches('#').trim_start();
        let mut words = line.split_whitespace();
        if let (Some(name), Some(encoding)) = (words.next(), words.next()) {
            if encoding == "UTF-8" && name.ends_with(".UTF-8") {
                names.push(name.to_string());
            }
        }
    }
    names.sort_unstable();
    names.dedup();
    names
}

pub fn locales_from(path: &Path) -> Result<Vec<String>, String> {
    let content = fs::read_to_string(path)
        .map_err(|e| format!("cannot read {}: {e}", path.display()))?;
    let names = parse_locales(&content);
    if names.is_empty() {
        Err(format!("no UTF-8 locales found in {}", path.display()))
    } else {
        Ok(names)
    }
}

pub fn locales() -> Result<Vec<String>, String> {
    locales_from(Path::new("/etc/locale.gen"))
}

pub fn parse_timezones(content: &str) -> Vec<String> {
    let mut names = vec!["UTC".to_string()];
    for line in content.lines() {
        if line.starts_with('#') || line.trim().is_empty() {
            continue;
        }
        // zone.tab: country<TAB>coordinates<TAB>Zone[/City]<TAB>comment
        if let Some(zone) = line.split('\t').nth(2) {
            if !zone.is_empty() && !zone.starts_with('/') && !zone.contains("..") {
                names.push(zone.to_string());
            }
        }
    }
    names.sort_unstable();
    names.dedup();
    names
}

pub fn timezones_from(path: &Path) -> Result<Vec<String>, String> {
    let content = fs::read_to_string(path)
        .map_err(|e| format!("cannot read {}: {e}", path.display()))?;
    let names = parse_timezones(&content);
    if names.len() < 2 {
        return Err(format!("timezone database is empty: {}", path.display()));
    }
    Ok(names)
}

pub fn timezones() -> Result<Vec<String>, String> {
    let tab = Path::new("/usr/share/zoneinfo/zone.tab");
    let fallback = Path::new("/usr/share/zoneinfo/zone1970.tab");
    let all = timezones_from(if tab.exists() { tab } else { fallback })?;
    // Avoid offering zones for which the current ISO has no zoneinfo file.
    Ok(all.into_iter().filter(|z| Path::new("/usr/share/zoneinfo").join(z).is_file()).collect())
}

fn keymap_name(path: &Path) -> Option<String> {
    let name = path.file_name()?.to_str()?;
    let base = name.strip_suffix(".map.gz").or_else(|| name.strip_suffix(".map"))?;
    if base.is_empty() { None } else { Some(base.to_owned()) }
}

pub fn keymaps_from(root: &Path) -> Result<Vec<String>, String> {
    if !root.is_dir() {
        return Err(format!("console keymaps directory missing: {}", root.display()));
    }
    let mut stack = vec![PathBuf::from(root)];
    let mut names = Vec::new();
    while let Some(folder) = stack.pop() {
        for entry in fs::read_dir(&folder).map_err(|e| format!("cannot read {}: {e}", folder.display()))? {
            let entry = entry.map_err(|e| e.to_string())?;
            let kind = entry.file_type().map_err(|e| e.to_string())?;
            if kind.is_dir() {
                stack.push(entry.path());
            } else if kind.is_file() {
                if let Some(name) = keymap_name(&entry.path()) { names.push(name); }
            }
        }
    }
    names.sort_unstable();
    names.dedup();
    if names.is_empty() {
        Err(format!("no console keymaps found in {}", root.display()))
    } else {
        Ok(names)
    }
}

pub fn keymaps() -> Result<Vec<String>, String> {
    for path in ["/usr/share/kbd/keymaps", "/usr/share/keymaps"] {
        if Path::new(path).is_dir() {
            return keymaps_from(Path::new(path));
        }
    }
    Err("no local console keymaps found; install the kbd package".into())
}

pub fn validate_choice(kind: &str, chosen: &str, available: &[String]) -> Result<(), String> {
    if available.iter().any(|item| item == chosen) {
        Ok(())
    } else {
        Err(format!("unknown {kind}: {chosen}; choose a value from the list"))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn accepts_only_real_utf8_locale_definitions() {
        let locales = parse_locales("#de_DE.UTF-8 UTF-8\n#en_US.UTF-8 UTF-8\n#de_DE ISO-8859-1\n");
        assert_eq!(locales, vec!["de_DE.UTF-8", "en_US.UTF-8"]);
        assert!(validate_choice("locale", "de_DE.UTF-9", &locales).is_err());
        assert!(validate_choice("locale", "de_DE.UTF-8", &locales).is_ok());
    }
    #[test]
    fn tzdb_accepts_iana_identifiers() {
        let tz = parse_timezones("# header\nDE\t+5230+01322\tEurope/Berlin\nUS\t+404251-0740023\tAmerica/New_York\tEastern\n");
        assert!(tz.contains(&"Europe/Berlin".to_owned()));
        assert!(tz.contains(&"UTC".to_owned()));
        assert!(validate_choice("timezone", "../../etc/shadow", &tz).is_err());
    }
    #[test]
    fn maps_are_filtered_by_extension() {
        assert_eq!(keymap_name(Path::new("de.map.gz")).as_deref(), Some("de"));
        assert_eq!(keymap_name(Path::new("us.map")).as_deref(), Some("us"));
        assert_eq!(keymap_name(Path::new("readme.txt")), None);
    }
    #[test]
    fn missing_sources_fail_closed() {
        assert!(locales_from(Path::new("/this/path/does/not/exist/locale.gen")).is_err());
        assert!(timezones_from(Path::new("/this/path/does/not/exist/zone.tab")).is_err());
        assert!(keymaps_from(Path::new("/this/path/does/not/exist/keymaps")).is_err());
    }
}
