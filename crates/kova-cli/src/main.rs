//! One user-facing Kova command, multiple internal Rust crates.
use kova_installer::{demo_plan, discover_disks, Disk, InstallPlan};
use std::io::{self, IsTerminal, Write};

fn usage() {
    println!(
        "Kova Linux tools\n\
         Usage:\n\
           kova install                 Interactive read-only installer preview\n\
           kova install --list-disks    Discover local disks (read-only)\n\
           kova install --dry-run --demo  Preview a 128 GiB example installation\n\
           kova install --dry-run --disk /dev/sdX [--username NAME] [--hostname NAME]\n\
           kova news                    Planned for a later release\n\
         \n\
         No disk writes are implemented. This installer is a preview, not an installer capable of installing an OS."
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
    Ok(if value.is_empty() {
        default.to_string()
    } else {
        value.to_string()
    })
}

fn show_disks(disks: &[Disk]) {
    if disks.is_empty() {
        println!("No disks found.");
    }
    for (i, disk) in disks.iter().enumerate() {
        println!(
            "  {}) {} — {} GiB — {} — {}",
            i + 1,
            disk.path,
            disk.size_gib(),
            disk.model,
            disk.status()
        );
    }
}

fn install(args: &[String]) -> Result<(), String> {
    if args.iter().any(|arg| arg == "--help" || arg == "-h") {
        usage();
        return Ok(());
    }
    let mut demo = false;
    let mut dry_run = false;
    let mut list_disks = false;
    let mut disk = None;
    let mut username = None;
    let mut hostname = None;
    let mut locale = None;
    let mut keyboard = None;
    let mut timezone = None;
    let mut iter = args.iter();
    while let Some(arg) = iter.next() {
        let slot = match arg.as_str() {
            "--dry-run" => {
                dry_run = true;
                continue;
            }
            "--demo" => {
                demo = true;
                continue;
            }
            "--list-disks" => {
                list_disks = true;
                continue;
            }
            "--disk" => &mut disk,
            "--username" => &mut username,
            "--hostname" => &mut hostname,
            "--locale" => &mut locale,
            "--keyboard" => &mut keyboard,
            "--timezone" => &mut timezone,
            other => return Err(format!("unsupported option: {other}")),
        };
        *slot = Some(
            iter.next()
                .ok_or_else(|| format!("{arg} requires a value"))?
                .to_owned(),
        );
    }

    if demo {
        if disk.is_some() {
            return Err("--demo and --disk cannot be combined".into());
        }
        let mut plan = demo_plan();
        if let Some(value) = username {
            plan.username = value;
        }
        if let Some(value) = hostname {
            plan.hostname = value;
        }
        if let Some(value) = locale {
            plan.locale = value;
        }
        if let Some(value) = keyboard {
            plan.keyboard = value;
        }
        if let Some(value) = timezone {
            plan.timezone = value;
        }
        print!("{}", plan.preview()?);
        return Ok(());
    }

    let disks = discover_disks()?;
    if list_disks {
        show_disks(&disks);
        return Ok(());
    }

    let selected = if let Some(path) = disk {
        disks
            .iter()
            .find(|d| d.path == path)
            .cloned()
            .ok_or_else(|| format!("disk {path} was not discovered by lsblk"))?
    } else {
        if dry_run || !io::stdin().is_terminal() {
            return Err("provide --disk /dev/... or use --demo for non-interactive mode".into());
        }
        println!("Kova Linux installation preview\n");
        println!("No disk writes will be performed.\n");
        show_disks(&disks);
        let answer = ask("Select a disk number", "1")?;
        let index = answer
            .parse::<usize>()
            .map_err(|_| "disk selection must be a number")?;
        disks
            .get(index.checked_sub(1).ok_or("invalid disk index")?)
            .cloned()
            .ok_or("invalid disk index")?
    };

    if !selected.eligible() {
        return Err(format!("{} is not eligible: {}", selected.path, selected.status()));
    }

    let interactive = io::stdin().is_terminal() && !dry_run;
    let mut plan = InstallPlan {
        disk: selected,
        username: username.unwrap_or_else(|| "user".into()),
        hostname: hostname.unwrap_or_else(|| "kova".into()),
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
    Ok(())
}

fn run() -> Result<(), String> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    match args.first().map(String::as_str) {
        None | Some("--help") | Some("-h") => {
            usage();
            Ok(())
        }
        Some("install") => install(&args[1..]),
        Some("news") => Err("kova news is planned after the installer milestone".into()),
        Some(other) => Err(format!("unknown Kova command: {other}. Run kova --help")),
    }
}

fn main() {
    if let Err(err) = run() {
        eprintln!("kova: {err}");
        std::process::exit(2);
    }
}
