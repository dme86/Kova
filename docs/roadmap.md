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

## Native multimedia shortcuts in Anvil — planned upstream

Kova ships `mako`, `libnotify`, PipeWire/WirePlumber, `brightnessctl`
and `kova-osd`. The helper changes sound/backlight levels and displays a
brief notification at the upper right:
`kova-osd volume up|down|mute`, `kova-osd brightness up|down`.

Anvil v0.3.0 does not support user-definable media-key bindings. Implement
configurable bindings in the Anvil compositor for `XF86AudioRaiseVolume`,
`XF86AudioLowerVolume`, `XF86AudioMute`, `XF86MonBrightnessUp` and
`XF86MonBrightnessDown`; map them to `kova-osd`. This avoids a privileged
keylogger-style libinput listener. Release and test new Anvil before Kova
claims hardware shortcut support. Until then, the OSD helper works when
called explicitly; hardware media keys are NOT hooked up.

## Destructive installer verification

Before allowing hardware installations: create a disposable UEFI/OVMF
QEMU disk, install Kova using test credentials, reboot WITHOUT the ISO,
verify user login and Wayland session, Snapper and `snap-pac` hooks,
and recovery after kernel updates. Separate CI for dual boot and LUKS2.
