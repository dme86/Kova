# Kova installer architecture

**Current state:** `kova install --apply` can erase a dedicated disk
and perform UEFI/GPT, Btrfs and Snapper installation. This is destructive
experimental code, NOT YET VERIFIED end-to-end under QEMU/OVMF. Only use
disposable virtual disks for evaluation until installed-system boots are
proven. The previous read-only preview remains available.

Kova is opinionated about the installed Linux system, **not** about
destroying an existing operating system. The first implementation will
support installation to an empty, dedicated disk; shared-disk dual boot is
a later, separately tested installer mode.
The first milestone ships a dependency-light Rust terminal wizard called
`kova install` for disk discovery, validation and a dry-run preview.
Upgrade that wizard to a ratatui/crossterm interface after we have a
tested real installation backend. Do not claim the preview installs Linux.
The eventual installer uses a small native Rust TUI,
not the Python archinstall or desktop-focused Calamares. The Rust frontend
invokes tested Arch tools (`sgdisk`, `mkfs`, `pacstrap`, `genfstab`,
`arch-chroot`, `bootctl`) for the actual disk and system operations.

The user chooses the target disk, keyboard layout, locale/language, timezone
(prefilled from detection), first username and credentials. Wi-Fi setup is
shown only if no network is available. Optional disk encryption (LUKS2)
is a deliberate security choice that must be designed and tested separately.
Require typed confirmation naming the disk before wiping any device.
NTP is automatic via systemd-timesyncd; no time-sync choice is necessary.
Btrfs, GPT, ZSTD, subvolume layout, Snapper and systemd-boot are fixed Kova
defaults, not user-facing filesystem/bootloader menus.

For `--apply`, the Rust CLI requires a TTY, a typed confirmation of
the precise disk path, and a twice-entered password. The root backend
re-checks major:minor device identity, UEFI mode, size, mounts, and
removable status before any wipe. It erases the entire disk; there is
no resize/dual-boot mode yet. The installer is NOT safety-certified.

## Installation modes and dual boot

The Rust installer will eventually offer two storage modes, both using the
same Kova defaults (Btrfs, ZSTD, Snapper, systemd-boot):

- **Erase selected disk** (initial implementation). Only after the user
  confirms the exact model, size and stable device identity. The installer
  refuses its live-boot device and mounted system devices.
- **Install beside an existing OS** (later). Never format, move, or delete
  existing partitions. Initially require **already unallocated space**:
  users can shrink Windows NTFS through Windows Disk Management first.
  Do not attempt automatic NTFS resizing or encrypted BitLocker resizing.

For UEFI/GPT Windows dual boot, preserve the existing ESP and
`EFI/Microsoft` data, reusing the partition only if there is sufficient
free space for Kova boot files. Many Windows ESPs are too small. When that
is the case, the installer must stop safely and explain the limitation,
rather than resize or format the ESP. A separately tested XBOOTLDR layout
may become an option. systemd-boot can detect Windows Boot Manager on
the same ESP. Document Secure Boot, BitLocker recovery keys, firmware
boot order and Windows Fast Startup requirements before enabling this mode.

The disk operations use tools such as `lsblk`, `blkid`, `sgdisk` and
`mkfs.btrfs` orchestrated from Rust; these are mature tools invoked
explicitly, not a custom partition-table implementation.

## Storage layout

| Storage | Filesystem | Mount |
|---|---|---|
| GPT p1, 1 GiB | FAT32 ESP | /boot (UEFI/systemd-boot) |
| GPT p2, remaining space | Btrfs, `compress=zstd:3`, `noatime` | root and subvolumes |

Btrfs subvolumes: `@` mounted at `/`, `@home` at `/home`,
`@snapshots` at `/.snapshots`, `@var_log` at `/var/log`, and
`@var_cache` at `/var/cache`. Keep `/var/lib/pacman` inside the root
subvolume so installed packages and the pacman database roll back together.
`@home` and log/cache volumes are not included in root snapshots.

For later standard `snapper rollback`, the design must either boot from the
Btrfs **default subvolume** without hardcoded `rootflags=subvol=@` and
without a hardcoded root `subvol=` fstab entry, or explicitly manage
bootloader targets in a custom recovery mechanism. The fixed `@` root
entry and conventional snapper rollback are **not** interchangeable. This
behavior requires VM installation/rollback tests.

## Automatic mirrors

The live ISO ships the Rust `rate-mirrors` package and a
`kova-mirrors.service`/`kova-mirrors.timer` pair. The timer runs shortly
after startup and periodically, but the updater enforces a 7-day minimum
refresh interval. It benchmarks synchronized HTTPS mirrors only and swaps
the mirrorlist atomically after validation; ranking failures keep the
previous pacman mirrorlist. Before pacstrap, the installer requests a
refresh if networking is available, and falls back to the existing list
if benchmarking fails. The installed system must include `rate-mirrors`,
the updater and the enabled timer.

## Snapper integration

Inside the installed target, after mounting and `pacstrap`:

1. Install `btrfs-progs`, `snapper` and `snap-pac` from official repos.
2. Create the root Snapper configuration using `snapper -c root create-config /`
   **before** mounting the dedicated `@snapshots` volume at `/.snapshots`.
   Snapper creates an initial `/.snapshots` Btrfs subvolume itself.
3. Remove that temporary subvolume, create its mountpoint, and mount
   `@snapshots` at `/.snapshots`. Persist its mount in `/etc/fstab`.
   This avoids the common create-config conflict with a pre-mounted
   `@snapshots` volume. Apply appropriate permissions.
4. Enable `snapper-timeline.timer` and `snapper-cleanup.timer`, and
   explicitly configure retention. `snap-pac` supplies pacman hooks for
   pre- and post-transaction snapshots.
5. Create a baseline snapshot and verify that `snapper -c root list`
   includes it.

**Snapshot ≠ backup**: data on the same physical disk will be lost if the
disk fails. Add Btrfs send/receive or other remote backup later.

**Kernel rollback caveat**: systemd-boot reads the kernel/initramfs from
the ESP, outside a root-only Btrfs snapshot. Reverting root while retaining
a newer kernel may break some updates, especially if kernel modules changed.
A true one-click rollback must account for kernel artifacts and boot entries,
or implement an explicit recovery process that restores matching versions.
Do not advertise bootable automatic rollbacks before a complete VM test.

## Safe installation milestones

- **M1 (now):** specify partition layout, boot mode, configuration and
  dependency lifecycle; keep the destructive installer disabled.
- **M2 (read-only planner):** Cargo workspace, safe disk discovery and
  validation, interactive CLI and `--dry-run` preview. The current planner
  excludes mounted or read-only devices but **does not yet have robust
  live-install-medium identification**.
- **M2b:** add stable block-device identity, live-media exclusion and
  a typed confirmation before any write. Implement a true Rust TUI.
- **M3 (code drafted):** destructive partitioning, pacstrap, Snapper,
  systemd-boot, greetd and Anvil. Still needs disposable-VM install tests.
  Do not use on production disks before that milestone.
- **M4:** prove first boot from installed disk with the installation ISO
  removed; upgrade, snapshot, simulate a failed upgrade and perform recovery.
  UEFI/OVMF must be tested before any hardware release.
- **M5:** review disk wiping, encryption policy, unattended installation
  safeguards and kernel rollback, then enable the dedicated-disk installer.
- **M6:** add safe dual-boot installation into existing unallocated space,
  preserving the existing ESP and partitions, with separate OVMF and
  Windows/BitLocker recovery tests.

References:
- https://wiki.archlinux.org/title/Btrfs
- https://wiki.archlinux.org/title/Snapper
- https://man.archlinux.org/man/snapper.8.en

## Kernel update policy

Use Arch's upstream `linux` kernel package, modules and associated
`mkinitcpio` hooks through the normal signed pacman repository. Kova
boot/menu branding is separate from the upstream kernel's `-arch1`
version string. Kova does not rebuild kernels or fetch short-lived GitHub
Actions artifacts for installed-system updates.

If a custom Kova kernel ever becomes essential, publish versioned,
signed pacman packages in a durable repository with normal `pacman -Syu`
support. This is not part of the initial release.

## Kova desktop and news integration

The installed system ships greetd + tuigreet (TTY login) and executes
`kova-session` to start Anvil on Wayland. Anvil v0.3.3 is pinned
at ISO build time by SHA256. `feh` is intentionally omitted; `swaybg` drives backgrounds via
Anvil's layer-shell feature. Users inherit an Anvil startup config
from `/etc/skel`; one wallpaper is randomly selected on every login.

The shared wallpapers live in `/var/lib/kova/wallpapers` and are
updated daily using a shallow Git checkout. Anvil is updated weekly
from GitHub **Releases** with a SHA256 check and an atomic executable
replacement, taking effect on the next session. Both update services
preserve existing files when downloads fail.

`kova-news.timer` downloads the official Arch RSS feed into a
global read-only cache. The per-user CLI filters it against locally
installed packages, records acknowledged links in
`~/.local/state/kova/news-read`, and provides an offline-only Fish
login summary. Matching is conservative but heuristic, not a
guarantee that all action-required announcements are detected.

## Wayland notifications and media controls

Anvil starts `mako` alongside the wallpaper client after login. The
user inherits `~/.config/mako/config` via `/etc/skel`, defining a dark,
blue-accented, top-right overlay. Standard `notify-send` comes from
`libnotify`. PipeWire + WirePlumber provide `wpctl`; `brightnessctl`
modifies supported hardware backlights. `kova-osd` changes each setting
and notifies via D-Bus with a short, replaceable progress popup.
Anvil v0.3.3 intercepts the five XF86 volume/brightness keys and
executes the configured `kova-osd` commands without a privileged global
keyboard event listener. Physical input-device validation is still required.
See `docs/roadmap.md`.

## Default terminal, font and icons

The live environment and installed system both install `alacritty`,
`ttf-jetbrains-mono`, `ttf-nerd-fonts-symbols-mono` and
`adwaita-icon-theme`. Anvil v0.3.3 launches Alacritty via Super+Return
and enables XF86 volume and brightness shortcuts to `kova-osd`.
The system Fontconfig default is JetBrains Mono with Nerd Font fallback.
Mako uses Adwaita audio/brightness icons and JetBrains Mono.
All new accounts inherit default Alacritty/Mako/Anvil configs from
`/etc/skel`; Fontconfig settings apply system-wide.

## Native NetworkManager bar widget

Kova enables Anvil's native `[bar.network]` indicator in the default
configuration. The compositor checks Ethernet and Wi-Fi device state
using NetworkManager's `nmcli` utility, paints Ethernet/Wi-Fi/offline
glyphs using `Symbols Nerd Font Mono`, and keeps a precise click target.
Left-click starts `alacritty -e nmtui-connect` and lets the authenticated
user pick a Wi-Fi SSID. NetworkManager is enabled during installation;
`acpid` is not installed just for network state. The icon reflects
device connectivity, not verified Internet reachability.
