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
# A syntax-valid shell script can still contain a second destructive install.
# A previous patch accidentally appended full repeated blocks after success.
assert installer.count('pacstrap -K "$target"') == 1, "pacstrap may only run once"
assert installer.count("target=/mnt/kova-install") == 1, "installer entry must be unique"
finished = 'echo "Kova installed. Remove installation ISO and reboot."'
assert installer.count(finished) == 1, "success message may only occur once"
assert installer.rstrip().endswith(finished), "no commands may run after successful installation"
initial = installer.split('pacstrap -K "$target" \\', 1)[1].split('arch-chroot "$target" snapper --no-dbus -c root create-config', 1)[0]
assert "snapper " in initial
assert "snap-pac" not in initial, "snap-pac hooks must not run during initial pacstrap"
assert installer.index('arch-chroot "$target" snapper --no-dbus -c root create --description') < installer.index('arch-chroot "$target" pacman -S --noconfirm --needed snap-pac')
assert 'gpgconf --homedir "$target/etc/pacman.d/gnupg" --kill gpg-agent' in installer
assert 'findmnt -R "$target" >&2' in installer
assert "fuser -vm" in installer
assert '[[ -n $password' in installer
# Reproduce the live-ISO DBus failure: never call snapper without --no-dbus in chroot.
assert installer.count('arch-chroot "$target" snapper --no-dbus') == 2
assert 'arch-chroot "$target" snapper -c root' not in installer
assert 'snapper --no-dbus -c root create-config /' in installer
assert 'snapper --no-dbus -c root create --description' in installer
# The first pacstrap's mkinitcpio hooks need vconsole.conf already present.
assert installer.index('printf \'KEYMAP=%s\\n\' "$keyboard" > "$target/etc/vconsole.conf"') < installer.index('pacstrap -K "$target"')
assert installer.index('arch-chroot "$target" mkinitcpio -P') > installer.index('arch-chroot "$target" locale-gen')

build = Path("scripts/build.sh").read_text()
assert 'cp -a "$ROOT/config/airootfs/." "$PROFILE/airootfs/"' in build
assert 'grep -Fq "Super + Enter" "$PROFILE/airootfs/etc/motd"' in build
print("Kova live MOTD, password policy, snap-pac ordering and cleanup: OK")
PY
