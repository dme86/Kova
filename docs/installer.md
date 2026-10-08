# Kova installer architecture (design; not implemented)

Kova should offer a single, opinionated install path on a **dedicated disk**.
Disk selection, username/password, locale/timezone and irreversible-destruction
confirmation are inputs; filesystem and bootloader are not menu choices.

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
- **M2:** develop a non-interactive Rust installer with a `--dry-run` plan;
  validate block-device identity and reject the running system disk. Require
  a typed confirmation naming the target device before any disk write.
- **M3:** implement actual partitioning, mounting, pacstrap, users, fstab,
  mkinitcpio, UEFI bootloader, Snapper and pacman hooks; only on an attached
  **disposable QEMU virtual disk** in CI.
- **M4:** prove first boot from installed disk with the installation ISO
  removed; upgrade, snapshot, simulate a failed upgrade and perform recovery.
  UEFI/OVMF must be tested before any hardware release.
- **M5:** review disk wiping, encryption policy, unattended installation
  safeguards and kernel rollback, then enable the installer in live media.

References:
- https://wiki.archlinux.org/title/Btrfs
- https://wiki.archlinux.org/title/Snapper
- https://man.archlinux.org/man/snapper.8.en
