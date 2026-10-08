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
and `kova-osd`. Anvil v0.3.3 adds configurable unmodified XF86 media keys;
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

## Network bar icon — implemented, hardware validation pending

Anvil v0.3.3 introduces an opt-in native NetworkManager icon. Kova
enables it by default, supplies Nerd Font Symbols Mono, and opens the
NetworkManager `nmtui-connect` interface in Alacritty when clicked.
The icon differentiates Ethernet/Wi-Fi/disconnected link states;
do not infer that a device marked connected has working Internet.
Later: validate icon rendering and clicking across multiple displays
and hardware, consider NetworkManager D-Bus signals instead of periodic
`nmcli` queries, and provide a more integrated Wayland selector if desired.
