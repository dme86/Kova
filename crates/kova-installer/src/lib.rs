//! Safe Kova installer planning. This crate has no disk-writing operations.
use std::process::Command;

/// Disk space reserved for the EFI system partition.
pub const EFI_SIZE_MIB: u64 = 1024;
pub const MIN_DISK_BYTES: u64 = 16 * 1024 * 1024 * 1024;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Disk {
    pub path: String,
    pub size_bytes: u64,
    pub model: String,
    pub read_only: bool,
    pub removable: bool,
    pub mounted: bool,
}

impl Disk {
    pub fn eligible(&self) -> bool {
        !self.read_only && !self.mounted && self.size_bytes >= MIN_DISK_BYTES
    }

    pub fn status(&self) -> &'static str {
        if self.read_only {
            "read-only"
        } else if self.mounted {
            "in use / mounted"
        } else if self.size_bytes < MIN_DISK_BYTES {
            "too small (minimum 16 GiB)"
        } else {
            "available for planning"
        }
    }

    pub fn size_gib(&self) -> u64 {
        self.size_bytes / (1024 * 1024 * 1024)
    }
}

fn field(line: &str, key: &str) -> Option<String> {
    let marker = format!("{key}=\"");
    let start = line.find(&marker)? + marker.len();
    let mut result = String::new();
    let mut escaped = false;
    for ch in line[start..].chars() {
        if escaped {
            result.push(ch);
            escaped = false;
        } else if ch == '\\' {
            escaped = true;
        } else if ch == '"' {
            return Some(result);
        } else {
            result.push(ch);
        }
    }
    None
}

/// Parse util-linux lsblk --pairs output without invoking a shell.
pub fn parse_disks(output: &str) -> Result<Vec<Disk>, String> {
    let mut disks = Vec::new();
    for line in output.lines().filter(|l| !l.trim().is_empty()) {
        if field(line, "TYPE").as_deref() != Some("disk") {
            continue;
        }
        let path = field(line, "PATH").ok_or("lsblk output missing PATH")?;
        if !path.starts_with("/dev/") {
            return Err("lsblk returned a non-device path".into());
        }
        let size_bytes = field(line, "SIZE")
            .ok_or("lsblk output missing SIZE")?
            .parse::<u64>()
            .map_err(|_| "invalid disk size from lsblk")?;
        let model = field(line, "MODEL").unwrap_or_default();
        let model: String = model.chars().filter(|ch| !ch.is_control()).collect();
        disks.push(Disk {
            path,
            size_bytes,
            model: model.trim().to_string(),
            read_only: field(line, "RO").as_deref() == Some("1"),
            removable: field(line, "RM").as_deref() == Some("1"),
            mounted: false,
        });
    }
    Ok(disks)
}

/// Discover top-level disks and reject any with mounted descendants.
/// This only reads system state; it never writes partition tables.
pub fn discover_disks() -> Result<Vec<Disk>, String> {
    let output = Command::new("lsblk")
        .args(["-dn", "-b", "-P", "-o", "PATH,SIZE,TYPE,MODEL,RO,RM"])
        .output()
        .map_err(|e| format!("failed to run lsblk: {e}"))?;
    if !output.status.success() {
        return Err("lsblk disk discovery failed".into());
    }
    let mut disks = parse_disks(&String::from_utf8_lossy(&output.stdout))?;
    for disk in &mut disks {
        let output = Command::new("lsblk")
            .args(["-nr", "-o", "MOUNTPOINTS", "--"])
            .arg(&disk.path)
            .output()
            .map_err(|e| format!("cannot inspect {} mounts: {e}", disk.path))?;
        if !output.status.success() {
            disk.mounted = true; // fail closed on unknown device state
            continue;
        }
        disk.mounted = output.stdout.iter().any(|b| !b.is_ascii_whitespace());
    }
    Ok(disks)
}

#[derive(Clone, Debug)]
pub struct InstallPlan {
    pub disk: Disk,
    pub username: String,
    pub hostname: String,
    pub locale: String,
    pub keyboard: String,
    pub timezone: String,
}

fn valid_label(s: &str) -> bool {
    !s.is_empty()
        && s.len() <= 32
        && s
            .chars()
            .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '-')
        && s.chars().next().is_some_and(|c| c.is_ascii_lowercase())
        && !s.ends_with('-')
}

fn valid_username(s: &str) -> bool {
    !s.is_empty()
        && s.len() <= 32
        && s.chars().next().is_some_and(|c| c.is_ascii_lowercase() || c == '_')
        && s
            .chars()
            .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_' || c == '-')
}

fn valid_region(s: &str) -> bool {
    !s.is_empty()
        && s.len() <= 80
        && !s.contains("..")
        && !s.starts_with('/')
        && s
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || "._/+-".contains(c))
}

impl InstallPlan {
    pub fn validate(&self) -> Result<(), String> {
        if !self.disk.eligible() {
            return Err(format!("{}: {}", self.disk.path, self.disk.status()));
        }
        if !valid_username(&self.username) {
            return Err("username must use lowercase letters, digits, _ or -".into());
        }
        if !valid_label(&self.hostname) {
            return Err("hostname must start with a lowercase letter and use [a-z0-9-]".into());
        }
        for (label, value) in [
            ("locale", self.locale.as_str()),
            ("keyboard", self.keyboard.as_str()),
            ("timezone", self.timezone.as_str()),
        ] {
            if !valid_region(value) {
                return Err(format!("invalid {label}"));
            }
        }
        Ok(())
    }

    pub fn preview(&self) -> Result<String, String> {
        self.validate()?;
        Ok(format!(
            "Kova Linux installer — DRY RUN ONLY\n\
             \n\
             Target: {disk} ({size} GiB; {model})\n\
             User: {user}\n\
             Hostname: {host}\n\
             Locale: {locale}; keyboard: {keyboard}; timezone: {tz}\n\
             \n\
             Planned layout (ERASE ENTIRE SELECTED DISK):\n\
               GPT p1: 1 GiB FAT32 EFI system partition -> /boot\n\
               GPT p2: remaining space Btrfs (zstd:3, noatime)\n\
               Btrfs subvolumes: @, @home, @snapshots, @var_log, @var_cache\n\
               systemd-boot, fish, pacman, rate-mirrors\n\
               Snapper + snap-pac; timeline and cleanup timers enabled\n\
               Root rollback: DISABLED until kernel/ESP recovery is tested\n\
             \n\
             Dual boot / LUKS2: not implemented in this milestone\n\
             NO PARTITIONS OR FILES WERE MODIFIED.\n",
            disk = self.disk.path,
            size = self.disk.size_gib(),
            model = self.disk.model,
            user = self.username,
            host = self.hostname,
            locale = self.locale,
            keyboard = self.keyboard,
            tz = self.timezone
        ))
    }
}

pub fn demo_plan() -> InstallPlan {
    InstallPlan {
        disk: Disk {
            path: "/dev/kova-demo".into(),
            size_bytes: 128 * 1024 * 1024 * 1024,
            model: "Virtual disk (example only)".into(),
            read_only: false,
            removable: false,
            mounted: false,
        },
        username: "user".into(),
        hostname: "kova".into(),
        locale: "en_US.UTF-8".into(),
        keyboard: "us".into(),
        timezone: "UTC".into(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_lsblk_disks_and_quoted_models() {
        let input = concat!(
            "PATH=\"/dev/nvme0n1\" SIZE=\"137438953472\" TYPE=\"disk\" MODEL=\"Example NVMe SSD\" RO=\"0\" RM=\"0\"\n",
            "PATH=\"/dev/sr0\" SIZE=\"1000\" TYPE=\"rom\" MODEL=\"Kova CDROM\" RO=\"1\" RM=\"1\"\n"
        );
        let disks = parse_disks(input).unwrap();
        assert_eq!(disks.len(), 1);
        assert_eq!(disks[0].model, "Example NVMe SSD");
        assert!(disks[0].eligible());
    }

    #[test]
    fn reject_mounted_readonly_and_small_disks() {
        let mut p = demo_plan();
        p.disk.mounted = true;
        assert!(p.validate().is_err());
        p.disk.mounted = false;
        p.disk.read_only = true;
        assert!(p.validate().is_err());
        p.disk.read_only = false;
        p.disk.size_bytes = MIN_DISK_BYTES - 1;
        assert!(p.validate().is_err());
    }

    #[test]
    fn invalid_username_hostname_and_region() {
        let mut p = demo_plan();
        p.username = "Root; rm -rf /".into();
        assert!(p.validate().is_err());
        p.username = "alice".into();
        p.hostname = "BADHOST".into();
        assert!(p.validate().is_err());
        p.hostname = "kova-laptop".into();
        p.timezone = "../../etc/shadow".into();
        assert!(p.validate().is_err());
    }

    #[test]
    fn safe_plan_is_explicitly_non_destructive() {
        let content = demo_plan().preview().unwrap();
        assert!(content.contains("DRY RUN ONLY"));
        assert!(content.contains("Snapper + snap-pac"));
        assert!(content.contains("NO PARTITIONS OR FILES WERE MODIFIED"));
        assert!(content.contains("Root rollback: DISABLED"));
    }
}
