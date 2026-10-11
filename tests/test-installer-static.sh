#!/usr/bin/env bash
set -euo pipefail

# Offline regression checks; never execute the destructive installer here.
python3 - <<'PY'
from pathlib import Path

motd = Path("config/airootfs/etc/motd").read_text()
assert "To install Arch Linux" not in motd
assert "kova-session" in motd
assert "Super + Enter" in motd
assert "Alacritty" in motd

installer = Path("scripts/install-system.sh").read_text()
initial = installer.split('pacstrap -K "$target" \\', 1)[1].split('arch-chroot "$target" snapper -c root create-config', 1)[0]
assert "snapper " in initial
assert "snap-pac" not in initial, "snap-pac hooks must not run during initial pacstrap"
assert installer.index("arch-chroot \"$target\" snapper -c root create --description") < installer.index('arch-chroot "$target" pacman -S --noconfirm --needed snap-pac')
assert 'gpgconf --homedir "$target/etc/pacman.d/gnupg" --kill gpg-agent' in installer
assert 'findmnt -R "$target" >&2' in installer
assert "fuser -vm" in installer
assert '[[ -n $password' in installer

build = Path("scripts/build.sh").read_text()
assert 'cp -a "$ROOT/config/airootfs/." "$PROFILE/airootfs/"' in build
assert 'grep -Fq "Super + Enter" "$PROFILE/airootfs/etc/motd"' in build
print("Kova live MOTD, password policy, snap-pac ordering and cleanup: OK")
PY
