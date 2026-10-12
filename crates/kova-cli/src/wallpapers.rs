//! A tiny wallpaper pool manager. The ISO ships three offline seeds; an
//! installed Kova downloads five randomly selected images every five boots.
//! No Git checkout, heavy HTTP crate, or persistent package metadata needed.
//! curl, jq and git are already part of the installed Kova toolchain.
use std::fs::{self, File, OpenOptions};
use std::io::{Read, Write};
use std::os::fd::AsRawFd;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{SystemTime, UNIX_EPOCH};

const GALLERY: &str = "https://api.github.com/repos/dme86/.wallpapers/contents/files?ref=main";
const RAW_PREFIX: &str = "https://raw.githubusercontent.com/dme86/.wallpapers/";
const POOL_SIZE: usize = 5;
const BOOT_INTERVAL: u32 = 5;
const MAX_FILE_BYTES: u64 = 25_000_000;

unsafe extern "C" {
    fn flock(fd: i32, operation: i32) -> i32;
}

struct Lock(File);

impl Lock {
    fn new(root: &Path) -> Result<Self, String> {
        let file = OpenOptions::new().read(true).write(true).create(true)
            .open(root.join(".sync.lock")).map_err(|e| e.to_string())?;
        // LOCK_EX | LOCK_NB: never run two syncs at once, and locks die with
        // the owning process (including when the machine powers off).
        if unsafe { flock(file.as_raw_fd(), 2 | 4) } != 0 {
            return Err("wallpaper sync is already running".into());
        }
        Ok(Self(file))
    }
}

struct Stage(PathBuf);
impl Drop for Stage {
    fn drop(&mut self) { let _ = fs::remove_dir_all(&self.0); }
}

#[derive(Clone, Debug)]
struct Image {
    name: String,
    url: String,
    git_sha: String,
    bytes: u64,
}

fn root() -> PathBuf {
    // Override is primarily for non-destructive fixture tests / development.
    std::env::var_os("KOVA_WALLPAPERS_DIR")
        .map(PathBuf::from).unwrap_or_else(|| PathBuf::from("/var/lib/kova/wallpapers"))
}

fn image_extension(name: &str) -> bool {
    let lower = name.to_ascii_lowercase();
    [".png", ".jpg", ".jpeg"].iter().any(|ext| lower.ends_with(ext))
}

fn safe_name(name: &str) -> bool {
    !name.is_empty() && name.len() <= 150 && image_extension(name)
        && name.bytes().all(|b| b.is_ascii_alphanumeric()
            || b == b'.' || b == b'-' || b == b'_')
        && !name.starts_with('.')
}

fn catalog() -> Result<Vec<Image>, String> {
    let output = Command::new("curl")
        .args(["--fail", "--silent", "--show-error", "--location",
               "--connect-timeout", "10", "--max-time", "30",
               "--retry", "2", "--user-agent", "Kova-Wallpaper-Sync/1",
               "--header", "Accept: application/vnd.github+json", GALLERY])
        .output().map_err(|e| format!("GitHub request failed: {e}"))?;
    if !output.status.success() {
        return Err(format!("cannot retrieve GitHub wallpaper catalog: {}", 
            String::from_utf8_lossy(&output.stderr).trim()));
    }
    // Parse GitHub's JSON via jq (installed already), not by extracting URLs
    // with fragile regular expressions. No user-supplied jq expression.
    let mut jq = Command::new("jq")
        .args(["-r", ".[] | select(.type == \"file\") | [.name, .download_url, .sha, .size] | @tsv"])
        .stdin(Stdio::piped()).stdout(Stdio::piped()).stderr(Stdio::piped())
        .spawn().map_err(|e| format!("jq is unavailable: {e}"))?;
    jq.stdin.take().ok_or("jq stdin unavailable")?
        .write_all(&output.stdout).map_err(|e| e.to_string())?;
    let parsed = jq.wait_with_output().map_err(|e| e.to_string())?;
    if !parsed.status.success() {
        return Err(format!("invalid GitHub catalog: {}",
            String::from_utf8_lossy(&parsed.stderr).trim()));
    }
    let listing = String::from_utf8(parsed.stdout)
        .map_err(|_| "catalog contains invalid UTF-8")?;
    let mut images = Vec::new();
    for line in listing.lines() {
        let cols: Vec<_> = line.split('\t').collect();
        if cols.len() != 4 { return Err("invalid catalog record".into()); }
        let [name, url, sha, size] = [cols[0], cols[1], cols[2], cols[3]];
        if !safe_name(name) {
            continue; // ignore README or unsupported artwork formats
        }
        let bytes = size.parse::<u64>().map_err(|_| "bad image size in catalog")?;
        if !(8..=MAX_FILE_BYTES).contains(&bytes) {
            return Err(format!("unsafe image size for {name}: {bytes}"));
        }
        let expected_suffix = format!("/files/{name}");
        if !url.starts_with(RAW_PREFIX) || !url.ends_with(&expected_suffix)
            || sha.len() != 40 || !sha.bytes().all(|b| b.is_ascii_hexdigit())
        {
            return Err(format!("untrusted image metadata: {name}"));
        }
        images.push(Image { name: name.into(), url: url.into(),
            git_sha: sha.into(), bytes });
    }
    if images.len() < POOL_SIZE {
        return Err(format!("catalog has fewer than {POOL_SIZE} valid images"));
    }
    images.sort_by(|a, b| a.name.cmp(&b.name));
    images.dedup_by(|a, b| a.name == b.name);
    Ok(images)
}

fn select_five(mut images: Vec<Image>) -> Result<Vec<Image>, String> {
    let mut random = File::open("/dev/urandom").map_err(|e| e.to_string())?;
    for i in (1..images.len()).rev() {
        let mut bytes = [0_u8; 8];
        random.read_exact(&mut bytes).map_err(|e| e.to_string())?;
        let index = (u64::from_le_bytes(bytes) % (i as u64 + 1)) as usize;
        images.swap(i, index);
    }
    images.truncate(POOL_SIZE);
    Ok(images)
}

fn verify_image(path: &Path, image: &Image) -> Result<(), String> {
    let metadata = fs::metadata(path).map_err(|e| e.to_string())?;
    if metadata.len() != image.bytes {
        return Err(format!("unexpected size for {}", image.name));
    }
    let mut magic = [0_u8; 8];
    File::open(path).and_then(|mut file| file.read_exact(&mut magic))
        .map_err(|e| e.to_string())?;
    let is_png = magic == [137, 80, 78, 71, 13, 10, 26, 10];
    let is_jpeg = magic[..3] == [0xff, 0xd8, 0xff];
    if !((image.name.to_ascii_lowercase().ends_with(".png") && is_png)
        || (!image.name.to_ascii_lowercase().ends_with(".png") && is_jpeg)) {
        return Err(format!("invalid image header for {}", image.name));
    }
    // GitHub's blob SHA is the Git object hash, not SHA1(file bytes).
    let output = Command::new("git").args(["hash-object", "--no-filters", "--"])
        .arg(path).output().map_err(|e| format!("git hash-object: {e}"))?;
    if !output.status.success()
        || String::from_utf8_lossy(&output.stdout).trim() != image.git_sha
    {
        return Err(format!("GitHub blob hash mismatch for {}", image.name));
    }
    Ok(())
}

fn download(image: &Image, stage: &Path) -> Result<(), String> {
    let path = stage.join(&image.name);
    let out = Command::new("curl")
        .args(["--fail", "--silent", "--show-error", "--location",
               "--connect-timeout", "10", "--max-time", "50", "--retry", "2",
               "--max-filesize", "25000000", "--user-agent", "Kova-Wallpaper-Sync/1",
               "--output"])
        .arg(&path).arg(&image.url).output()
        .map_err(|e| format!("downloading {}: {e}", image.name))?;
    if !out.status.success() {
        return Err(format!("downloading {}: {}", image.name,
            String::from_utf8_lossy(&out.stderr).trim()));
    }
    verify_image(&path, image)
}

fn recover_swap(root: &Path) -> Result<(), String> {
    let cache = root.join("cache");
    let previous = root.join(".cache-previous");
    if previous.is_dir() {
        if cache.is_dir() {
            fs::remove_dir_all(previous).map_err(|e| e.to_string())?;
        } else {
            fs::rename(previous, cache).map_err(|e| e.to_string())?;
        }
    }
    Ok(())
}

fn has_pool(root: &Path) -> bool {
    let cache = root.join("cache");
    let Ok(entries) = fs::read_dir(cache) else { return false };
    entries.filter_map(Result::ok).filter(|e| {
        e.file_type().is_ok_and(|kind| kind.is_file()) &&
            safe_name(&e.file_name().to_string_lossy())
    }).count() == POOL_SIZE
}

fn refresh(root: &Path) -> Result<(), String> {
    recover_swap(root)?;
    // Prefer fresh images: never select one of the three ISO fallbacks,
    // so a populated cache offers eight distinct motifs rather than five.
    let images = catalog()?.into_iter()
        .filter(|image| !root.join("files").join(&image.name).exists())
        .collect::<Vec<_>>();
    if images.len() < POOL_SIZE {
        return Err("catalog contains fewer than five images outside the ISO seeds".into());
    }
    let selected = select_five(images)?;
    let nonce = SystemTime::now().duration_since(UNIX_EPOCH)
        .map_err(|e| e.to_string())?.as_nanos();
    let stage_path = root.join(format!(".download-{}-{nonce}", std::process::id()));
    fs::create_dir(&stage_path).map_err(|e| e.to_string())?;
    let _stage = Stage(stage_path.clone());
    for image in &selected {
        download(image, &stage_path)?;
    }
    // Only swap after all five verified downloads succeeded. Existing images
    // survive DNS issues, HTTP failures, hash mismatches and invalid files.
    let cache = root.join("cache");
    let previous = root.join(".cache-previous");
    if cache.exists() {
        fs::rename(&cache, &previous).map_err(|e| e.to_string())?;
    }
    if let Err(err) = fs::rename(&stage_path, &cache) {
        if previous.exists() {
            let _ = fs::rename(&previous, &cache);
        }
        return Err(format!("cannot activate wallpaper pool: {err}"));
    }
    if previous.exists() { fs::remove_dir_all(previous).map_err(|e| e.to_string())?; }
    println!("Kova: refreshed 5 random wallpapers from dme86/.wallpapers");
    Ok(())
}

fn read_count(root: &Path) -> u32 {
    fs::read_to_string(root.join(".boots-since-sync"))
        .ok().and_then(|s| s.trim().parse::<u32>().ok())
        .unwrap_or(0).min(BOOT_INTERVAL)
}

fn save_count(root: &Path, count: u32) -> Result<(), String> {
    let tmp = root.join(format!(".boots-since-sync.{}", std::process::id()));
    fs::write(&tmp, format!("{count}\n")).map_err(|e| e.to_string())?;
    fs::rename(tmp, root.join(".boots-since-sync")).map_err(|e| e.to_string())
}

fn on_boot(root: &Path) -> Result<(), String> {
    recover_swap(root)?;
    let boots = read_count(root) + 1;
    if boots >= BOOT_INTERVAL || !has_pool(root) {
        match refresh(root) {
            Ok(()) => save_count(root, 0)?,
            Err(err) => {
                // Offline is normal. Keep the three ISO seeds and any old pool,
                // then retry on the next boot, not repeatedly in one session.
                eprintln!("Kova: wallpaper sync skipped ({err}); offline gallery remains available");
                save_count(root, BOOT_INTERVAL - 1)?;
            }
        }
    } else {
        save_count(root, boots)?;
        println!("Kova: wallpaper rotation in {} boots", BOOT_INTERVAL - boots);
    }
    Ok(())
}

pub fn run(args: &[String]) -> Result<(), String> {
    let root = root();
    match args.first().map(String::as_str) {
        Some("status") if args.len() == 1 => {
            println!("Kova wallpaper pool: {}", root.display());
            let seeds = fs::read_dir(root.join("files")).ok().into_iter().flatten()
                .filter_map(Result::ok).filter(|e| {
                    e.file_type().is_ok_and(|kind| kind.is_file()) &&
                        safe_name(&e.file_name().to_string_lossy())
                }).count();
            println!("{seeds} offline fallback images, {} cached images",
                if has_pool(&root) { POOL_SIZE } else { 0 });
            println!("Boots since refresh: {}", read_count(&root));
            Ok(())
        }
        Some("boot" | "sync") if args.len() == 1 => {
            fs::create_dir_all(&root).map_err(|e| format!("{}: {e}", root.display()))?;
            let _lock = Lock::new(&root)?;
            if args[0] == "boot" { on_boot(&root) }
            else {
                refresh(&root)?;
                save_count(&root, 0)
            }
        }
        _ => Err("usage: kova wallpaper {status|sync|boot} (boot is called by systemd)".into()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn prevents_unsafe_remote_names() {
        for name in ["../oops.png", ".hidden.png", "a/b.jpg", "bad.gif",
                     "line\nbreak.jpeg", "über.png"] {
            assert!(!safe_name(name), "{name}");
        }
        assert!(safe_name("national_park.jpeg"));
        assert!(safe_name("3d_handdrawn.png"));
    }
    #[test]
    fn rotation_and_pool_constants() {
        assert_eq!(POOL_SIZE, 5);
        assert_eq!(BOOT_INTERVAL, 5);
    }
    #[test]
    fn stale_backup_is_recovered_without_network() {
        let dir = std::env::temp_dir().join(format!("kova-pool-test-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(dir.join(".cache-previous")).unwrap();
        fs::write(dir.join(".cache-previous/preserved.jpg"), b"offline").unwrap();
        recover_swap(&dir).unwrap();
        assert!(dir.join("cache/preserved.jpg").exists());
        fs::remove_dir_all(dir).unwrap();
    }
}
