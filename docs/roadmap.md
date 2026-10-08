# Kova Linux roadmap

## Pacman-managed Anvil updates — planned

**Goal:** New Anvil versions appear during normal `pacman -Syu`, rather
than being silently downloaded by a separate root-owned updater.

1. Build an Arch `anvil` package from an immutable release/commit with
   reproducible PKGBUILD and verified source SHA256.
2. Publish it in a durable, **signed** Kova pacman repository with a trusted
   signing key, stable URLs and retained historical packages. Short-lived
   GitHub Actions artifacts are not suitable package hosting.
3. Ship the package in the Kova installation, update via `pacman -Syu`,
   and remove `kova-update-anvil.timer` to prevent two competing updaters.
4. Package Kova CLI, desktop defaults and system services so existing
   installations receive updates after their initial installation.
5. CI: package integrity, file ownership, upgrade, reboot and rollback tests.

**Status:** not implemented. Current Anvil updates use GitHub Releases and
SHA256 checksum verification.

## Native multimedia shortcuts — implemented, hardware validation pending

Kova includes `mako`, `libnotify`, PipeWire/WirePlumber, `brightnessctl`
and `kova-osd`. Anvil v3.0.1 adds configurable unmodified XF86 media keys;
Kova wires volume up/down/mute and brightness up/down to `kova-osd`.
System font/icon defaults include JetBrains Mono, Nerd Fonts Symbols Mono,
and Adwaita icons. The native session launches Alacritty by default.

Still to validate on physical laptops/keyboards: actual XF86 keysyms,
PipeWire default sink detection, desktop-user backlight permissions, and
mako popups with matching theme/icons.

## Destructive installer verification

Before allowing hardware installations: create a disposable UEFI/OVMF
QEMU disk, install Kova using test credentials, reboot WITHOUT the ISO,
verify user login and Wayland session, Snapper and `snap-pac` hooks,
and recovery after kernel updates. Separate CI for dual boot and LUKS2.
