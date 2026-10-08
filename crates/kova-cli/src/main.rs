//! Kova's single user-facing Rust executable.
use kova_installer::{demo_plan, discover_disks, Disk, InstallPlan};
use std::io::{self, IsTerminal, Write};
use std::process::{Command, Stdio};

fn usage() {
    println!(
        "Kova Linux\n\
         kova install                 Interactive disk and installation planner\n\
         kova install --list-disks    Read-only disk discovery\n\
         kova install --dry-run --demo  Preview a synthetic disk (CI)\n\
         kova install --apply        ERASE selected dedicated disk and install Kova (UEFI only)\n\
         kova news                   Relevant Arch Linux announcements\n\
         kova news --summary         Fast cached login notification\n\
         kova news read N            Read and acknowledge announcement N\n\
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
        username: user.unwrap_or_else(|| "user".into()),
        hostname: host.unwrap_or_else(|| "kova".into()),
        locale: locale.unwrap_or_else(|| "en_US.UTF-8".into()),
        keyboard: keyboard.unwrap_or_else(|| "us".into()),
        timezone: timezone.unwrap_or_else(|| "UTC".into()),
    };
    if interactive {
        plan.username = ask("Username", &plan.username)?;
        plan.hostname = ask("Hostname", &plan.hostname)?;
        plan.locale = ask("Locale", &plan.locale)?;
        plan.keyboard = ask("Keyboard", &plan.keyboard)?;
        plan.timezone = ask("Timezone", &plan.timezone)?;
    }
    println!("{}", plan.preview()?);
    if !apply {
        return Ok(());
    }
    if plan.disk.removable {
        return Err("removable disks are not supported for destructive installation".into());
    }
    println!("WARNING: ALL partitions and data on {} WILL BE LOST.", plan.disk.path);
    let expected = format!("ERASE {}", plan.disk.path);
    if ask_exact(&format!("To continue type exactly: {expected}"))? != expected {
        return Err("disk erase confirmation did not match; no changes made".into());
    }
    let password = secret("New user password (8+ characters)")?;
    if password.len() < 8 || password.contains(':') || password.contains('\n') {
        return Err("password must contain at least 8 characters and no colon".into());
    }
    let repeated = secret("Confirm user password")?;
    if repeated != password {
        return Err("passwords did not match".into());
    }
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
        Some(other) => Err(format!("unknown subcommand: {other}")),
    }
}

fn main() {
    if let Err(err) = run() {
        eprintln!("kova: {err}");
        std::process::exit(2);
    }
}
