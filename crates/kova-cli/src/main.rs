//! Kova's single user-facing Rust executable.
use kova_installer::{choices, demo_plan, discover_disks, Disk, InstallPlan};
mod wallpapers;
use std::io::{self, IsTerminal, Write};
use std::process::{Command, Stdio};

fn usage() {
    println!(
        "Kova Linux\n\
         kova install                 Preview; optionally install with confirmation\n\
         kova install --list-disks    Read-only disk discovery\n\
         kova install --dry-run --demo  Preview a synthetic disk (CI)\n\
         kova install --apply         Show plan, then request ERASE confirmation (UEFI)\n\
         kova news                   Relevant Arch Linux announcements\n\
         kova news --summary         Fast cached login notification\n\
         kova news read N            Read and acknowledge announcement N\n\
         kova wallpaper status        Show offline seeds, cached pool and boot count\n\
         kova wallpaper sync          Download five random, verified wallpapers now\n\
         kova wallpaper boot          Rotate pool on every fifth boot (systemd)\n\
         \n\
         WARNING: --apply irreversibly erases the ENTIRE target disk. Dual boot is not implemented."
    );
}

fn ask(prompt: &str, default: &str) -> Result<String, String> {
    print!("{prompt} [{default}]: ");
    io::stdout().flush().map_err(|e| e.to_string())?;
    let mut answer = String::new();
    if io::stdin().read_line(&mut answer).map_err(|e| e.to_string())? == 0 {
        return Err("input closed".into());
    }
    let value = answer.trim();
    Ok(if value.is_empty() { default.to_owned() } else { value.to_owned() })
}

fn ask_exact(prompt: &str) -> Result<String, String> {
    println!("{prompt}");
    print!("> ");
    io::stdout().flush().map_err(|e| e.to_string())?;
    let mut response = String::new();
    if io::stdin().read_line(&mut response).map_err(|e| e.to_string())? == 0 {
        return Err("input closed".into());
    }
    Ok(response.trim_end_matches(['\n', '\r']).to_string())
}

fn secret(prompt: &str) -> Result<String, String> {
    print!("{prompt}: ");
    io::stdout().flush().map_err(|e| e.to_string())?;
    let off = Command::new("stty").arg("-echo").status().map_err(|e| e.to_string())?;
    if !off.success() {
        return Err("cannot disable terminal echo".into());
    }
    let mut input = String::new();
    let read = io::stdin().read_line(&mut input);
    let restore = Command::new("stty").arg("echo").status().map_err(|e| e.to_string())?;
    println!();
    if !restore.success() {
        return Err("cannot restore terminal echo".into());
    }
    read.map_err(|e| e.to_string())?;
    Ok(input.trim_end_matches(['\n', '\r']).to_string())
}

// Numbered, searchable menus: no GUI or extra terminal dependency needed.
// Returning None navigates to the previous field.
fn select_option(label: &str, options: &[String], default: &str) -> Result<Option<String>, String> {
    if options.is_empty() {
        return Err(format!("no {label} options available; cannot continue"));
    }
    let mut filter = String::new();
    loop {
        let needle = filter.to_ascii_lowercase();
        let mut matches: Vec<&String> = options.iter()
            .filter(|v| v.to_ascii_lowercase().contains(needle.as_str()))
            .collect();
        // Offer the current value first, then a small list; avoid flooding tty/serial.
        if let Some(idx) = matches.iter().position(|v| v.as_str() == default) {
            let current = matches.remove(idx);
            matches.insert(0, current);
        }
        println!("\n{label}: {} choices{} (current: {default})",
            matches.len(), if filter.is_empty() { "" } else { " matching filter" });
        for (i, value) in matches.iter().take(12).enumerate() {
            println!("  {:>2}. {}", i + 1, value);
        }
        if matches.len() > 12 {
            println!("  ... type /text to filter the list");
        }
        let response = ask_exact("Choose number, /search, exact name, Enter=current, b=back")?;
        if response == "b" {
            return Ok(None);
        }
        if response.is_empty() {
            if options.iter().any(|v| v == default) {
                return Ok(Some(default.to_owned()));
            }
            println!("Current value is not available; choose from the list.");
        } else if let Some(needle) = response.strip_prefix('/') {
            filter = needle.to_owned();
        } else if let Ok(index) = response.parse::<usize>() {
            if let Some(value) = index.checked_sub(1).and_then(|i| matches.get(i)).filter(|_| index <= 12) {
                return Ok(Some((**value).clone()));
            }
            println!("Invalid selection.");
        } else if options.iter().any(|v| v == &response) {
            return Ok(Some(response));
        } else {
            filter = response;
            println!("Searching for {filter:?}; enter a number to select.");
        }
    }
}

fn valid_password(password: &str) -> bool {
    !password.is_empty()
        && !password.contains(':')
        && !password.contains('\n') && !password.contains('\r')
}

fn ask_password() -> Result<String, String> {
    loop {
        let password = secret("New user password")?;
        if !valid_password(&password) {
            println!("Password must not be empty or contain a colon. Please try again.");
            continue;
        }
        if password.chars().count() < 8 {
            println!("WARNING: short passwords are insecure; use only on disposable/test systems.");
        }
        let repeated = secret("Confirm user password")?;
        if repeated != password {
            println!("Passwords do not match; please try again.");
            continue;
        }
        return Ok(password);
    }
}

#[cfg(test)]
mod ui_tests {
    use super::*;
    #[test]
    fn short_passwords_allowed_with_safe_backend_constraints() {
        assert!(valid_password("123"));
        assert!(valid_password("much-longer-password"));
        assert!(!valid_password(""));
        assert!(!valid_password("ab:cd"));
        assert!(!valid_password("ab\ncd"));
        assert!(!valid_password("ab\rcd"));
    }
}

fn disks_list(disks: &[Disk]) {
    for (i, d) in disks.iter().enumerate() {
        println!(
            "{:>2}. {:<20} {:>5} GiB  {:<28} {}",
            i + 1, d.path, d.size_gib(), d.model, d.status()
        );
    }
}

fn install(args: &[String]) -> Result<(), String> {
    if args.iter().any(|s| s == "--help" || s == "-h") {
        usage();
        return Ok(());
    }
    let mut demo = false;
    let mut apply = false;
    let mut dry_run = false;
    let mut list_disks = false;
    let (mut disk, mut user, mut host, mut locale, mut keyboard, mut timezone) =
        (None, None, None, None, None, None);
    let mut iter = args.iter();
    while let Some(arg) = iter.next() {
        let slot = match arg.as_str() {
            "--demo" => { demo = true; continue; }
            "--apply" => { apply = true; continue; }
            "--dry-run" => { dry_run = true; continue; }
            "--list-disks" => { list_disks = true; continue; }
            "--disk" => &mut disk,
            "--username" => &mut user,
            "--hostname" => &mut host,
            "--locale" => &mut locale,
            "--keyboard" => &mut keyboard,
            "--timezone" => &mut timezone,
            other => return Err(format!("unknown installer flag: {other}")),
        };
        *slot = Some(iter.next().ok_or_else(|| format!("{arg} needs a value"))?.clone());
    }
    if apply && (dry_run || demo || list_disks) {
        return Err("cannot combine --apply with --dry-run, --demo or --list-disks".into());
    }
    if demo {
        println!("{}", demo_plan().preview()?);
        return Ok(());
    }
    let disks = discover_disks()?;
    if list_disks {
        disks_list(&disks);
        return Ok(());
    }
    if apply && !io::stdin().is_terminal() {
        return Err("--apply REQUIRES an interactive terminal; unattended erasure is disabled".into());
    }
    let selected = if let Some(path) = disk {
        disks.iter().find(|d| d.path == path).cloned()
            .ok_or_else(|| format!("{path} is not present in lsblk"))?
    } else {
        if !io::stdin().is_terminal() {
            return Err("provide --disk or use --dry-run --demo".into());
        }
        println!("Kova Linux disk selection");
        disks_list(&disks);
        let index: usize = ask("Target disk number", "1")?.parse()
            .map_err(|_| "invalid disk index")?;
        disks.get(index.checked_sub(1).ok_or("invalid selection")?)
            .cloned().ok_or("invalid disk selection")?
    };
    let interactive = io::stdin().is_terminal() && !dry_run;
    let mut plan = InstallPlan {
        disk: selected,
        username: user.clone().unwrap_or_else(|| "user".into()),
        hostname: host.clone().unwrap_or_else(|| "kova".into()),
        locale: locale.clone().unwrap_or_else(|| "en_US.UTF-8".into()),
        keyboard: keyboard.clone().unwrap_or_else(|| "us".into()),
        timezone: timezone.clone().unwrap_or_else(|| "UTC".into()),
    };
    // Get actual valid choices from the running live ISO. All lists are offline.
    let locales = choices::locales()?;
    let keyboards = choices::keymaps()?;
    let timezones = choices::timezones()?;
    if interactive {
        let mut stage: usize = 0;
        while stage < 5 {
            let selected: Option<String> = match stage {
                0 if user.is_some() => Some(plan.username.clone()),
                0 => { let v = ask("Username (b=back)", &plan.username)?; if v == "b" { None } else { Some(v) } }
                1 if host.is_some() => Some(plan.hostname.clone()),
                1 => { let v = ask("Hostname (b=back)", &plan.hostname)?; if v == "b" { None } else { Some(v) } }
                2 if locale.is_some() => Some(plan.locale.clone()),
                2 => select_option("Locale", &locales, &plan.locale)?,
                3 if keyboard.is_some() => Some(plan.keyboard.clone()),
                3 => select_option("Keyboard layout", &keyboards, &plan.keyboard)?,
                4 if timezone.is_some() => Some(plan.timezone.clone()),
                4 => select_option("Timezone", &timezones, &plan.timezone)?,
                _ => unreachable!(),
            };
            match selected {
                None => { stage = stage.saturating_sub(1); }
                Some(value) => {
                    match stage {
                        0 => plan.username = value,
                        1 => plan.hostname = value,
                        2 => plan.locale = value,
                        3 => plan.keyboard = value,
                        4 => plan.timezone = value,
                        _ => unreachable!(),
                    }
                    stage += 1;
                }
            }
        }
    }
    choices::validate_choice("locale", &plan.locale, &locales)?;
    choices::validate_choice("keyboard", &plan.keyboard, &keyboards)?;
    choices::validate_choice("timezone", &plan.timezone, &timezones)?;
    println!("{}", plan.preview()?);
    if !apply {
        if !interactive {
            return Ok(());
        }
        let answer = ask("Apply this plan now? (yes/no)", "no")?;
        if answer != "yes" {
            println!("No disk changes made.");
            return Ok(());
        }
    }
    if plan.disk.removable {
        return Err("removable disks are not supported for destructive installation".into());
    }
    println!("WARNING: ALL partitions and data on {} WILL BE LOST.", plan.disk.path);
    let expected = format!("ERASE {}", plan.disk.path);
    if ask_exact(&format!("To continue type exactly: {expected}"))? != expected {
        return Err("disk erase confirmation did not match; no changes made".into());
    }
    let password = ask_password()?;
    // Capture identity at the last possible moment; backend independently rechecks.
    let output = Command::new("lsblk").args(["-dn", "-o", "MAJ:MIN", "--"])
        .arg(&plan.disk.path).output().map_err(|e| e.to_string())?;
    if !output.status.success() {
        return Err("cannot verify target disk identity".into());
    }
    let identity = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if identity.is_empty() || !identity.contains(':') {
        return Err("invalid target disk identity".into());
    }
    let mut child = Command::new("sudo").arg("-n")
        .arg("/usr/local/lib/kova/install-system")
        .arg(&plan.disk.path)
        .arg(&identity)
        .arg(&plan.username)
        .arg(&plan.hostname)
        .arg(&plan.locale)
        .arg(&plan.keyboard)
        .arg(&plan.timezone)
        .arg(format!("ERASE:{identity}"))
        .stdin(Stdio::piped()).spawn().map_err(|e| format!("installer launch failed: {e}"))?;
    let mut input = child.stdin.take().ok_or("installer has no stdin")?;
    input.write_all(format!("{password}\n").as_bytes()).map_err(|e| e.to_string())?;
    drop(input);
    let result = child.wait().map_err(|e| e.to_string())?;
    if !result.success() {
        return Err(format!("installation failed (exit status: {result}); inspect preceding log"));
    }
    Ok(())
}

fn run() -> Result<(), String> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    match args.first().map(String::as_str) {
        None | Some("--help") | Some("-h") => { usage(); Ok(()) }
        Some("install") => install(&args[1..]),
        Some("news") => kova_news::run(&args[1..]),
        Some("wallpaper") => wallpapers::run(&args[1..]),
        Some(other) => Err(format!("unknown subcommand: {other}")),
    }
}

fn main() {
    if let Err(err) = run() {
        eprintln!("kova: {err}");
        std::process::exit(2);
    }
}
