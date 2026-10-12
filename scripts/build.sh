#!/usr/bin/env bash
set -euo pipefail
[[ $(id -u) -eq 0 ]] || { echo 'Run as root inside Arch Linux'; exit 1; }
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
WORK=${KOVA_WORK:-/tmp/kova-archiso-work}
OUT=${KOVA_OUT_DIR:-"$ROOT/out"}
# Production image is always the default. CI-only payload is explicit.
case ${KOVA_CI_IMAGE:-0} in 0|1) ;; *) echo "KOVA_CI_IMAGE must be 0 or 1" >&2; exit 2 ;; esac
PROFILE=$(mktemp -d /tmp/kova-profile.XXXXXX)
trap 'rm -rf "$PROFILE"' EXIT
cp -a /usr/share/archiso/configs/releng/. "$PROFILE/"
[[ -x "$ROOT/config/airootfs/usr/local/bin/kova" ]] || {
  echo "Missing Kova Rust binary; run cargo build --release -p kova-cli and stage target/release/kova first" >&2
  exit 1
}
cp -a "$ROOT/config/airootfs/." "$PROFILE/airootfs/"
# A release image must not contain internal CI scripts/units, even disabled.
# Keep these in the repository for the separately built CI boot-test ISO.
if [[ ${KOVA_CI_IMAGE:-0} != 1 ]]; then
  rm -f "$PROFILE/airootfs/usr/local/lib/kova/ci-smoke"
  rm -f "$PROFILE/airootfs/etc/systemd/system/kova-ci-smoke.service"
fi
# The Archiso releng MOTD contains upstream Arch install instructions.
# Explicitly override it with concise Kova live help.
grep -Fq "Super + Enter" "$PROFILE/airootfs/etc/motd"
# Enable live user provisioning and serial smoke testing in the live image.
mkdir -p "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants"
ln -s ../kova-live-user.service "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants/kova-live-user.service"
if [[ ${KOVA_CI_IMAGE:-0} == 1 ]]; then
  ln -s ../kova-ci-smoke.service "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants/kova-ci-smoke.service"
else
  test ! -e "$PROFILE/airootfs/usr/local/lib/kova/ci-smoke"
  test ! -e "$PROFILE/airootfs/etc/systemd/system/kova-ci-smoke.service"
  test ! -e "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants/kova-ci-smoke.service"
fi
mkdir -p "$PROFILE/airootfs/etc/systemd/system/timers.target.wants"
ln -s ../kova-mirrors.timer "$PROFILE/airootfs/etc/systemd/system/timers.target.wants/kova-mirrors.timer"
ln -s ../kova-news.timer "$PROFILE/airootfs/etc/systemd/system/timers.target.wants/kova-news.timer"
# Global user-timer enablement applies to the live user and future accounts.
mkdir -p "$PROFILE/airootfs/etc/systemd/user/timers.target.wants"
# Use a rootfs-relative link, not an absolute host path that becomes broken
# while Archiso copies the profile into its staging root.
ln -s ../../../../usr/lib/systemd/user/kova-battery.timer "$PROFILE/airootfs/etc/systemd/user/timers.target.wants/kova-battery.timer"
test -r "$PROFILE/airootfs/etc/systemd/user/timers.target.wants/kova-battery.timer" || {
  echo "Kova battery user timer symlink is broken in the Archiso profile" >&2
  exit 1
}
cat >> "$PROFILE/packages.x86_64" <<'PKGS'
fish
neovim
git
networkmanager
rate-mirrors
arch-install-scripts
gptfdisk
parted
btrfs-progs
dosfstools
snapper
snap-pac
jq
wayland
mesa
libinput
seatd
greetd
greetd-tuigreet
swaybg
mako
libnotify
pipewire
pipewire-alsa
pipewire-pulse
wireplumber
brightnessctl
alacritty
librewolf
xdg-utils
ttf-jetbrains-mono
ttf-nerd-fonts-symbols-mono
adwaita-icon-theme
xorg-xwayland
wl-clipboard
zram-generator
eza
bat
fd
ripgrep
bottom
dust
procs
dysk
sd
uutils-coreutils
zoxide
starship
fzf
lazygit
tmux
npm
go
tree-sitter-cli
unzip
base-devel
curl
sudo
PKGS
# dedupe package list, preserving upstream releng dependencies
awk '!seen[$0]++' "$PROFILE/packages.x86_64" > "$PROFILE/packages.x86_64.tmp"
mv "$PROFILE/packages.x86_64.tmp" "$PROFILE/packages.x86_64"
sed -i -E 's/^iso_name=.*/iso_name="kova"/; s/^iso_publisher=.*/iso_publisher="Kova Linux"/; s/^iso_application=.*/iso_application="Kova Linux Live Environment"/' "$PROFILE/profiledef.sh"
# Apply Kova boot menu branding to the copied upstream releng profile.
bash "$ROOT/scripts/brand-profile.sh" "$PROFILE"
# Expose kernel, initramfs and systemd output on QEMU's first serial port.
# Keep tty0 as the primary console so the ISO also remains usable on real PCs.
# Without this, syslinux appears on the serial log but the Linux boot is silent,
# making it impossible to tell a boot failure from an inactive smoke-test unit.
SYSLINUX_CFG="$PROFILE/syslinux/archiso_sys-linux.cfg"
[[ -f "$SYSLINUX_CFG" ]] || { echo "Missing Archiso BIOS boot entry: $SYSLINUX_CFG" >&2; exit 1; }
sed -i -E '/^APPEND /s|$| console=ttyS0,115200n8 console=tty0 loglevel=6 systemd.log_level=info systemd.log_target=kmsg|' "$SYSLINUX_CFG"
grep -q 'console=ttyS0,115200n8' "$SYSLINUX_CFG"
# Archiso copies custom airootfs files without their original file modes.
# Explicitly restore executable permissions for our live-system scripts.
# Missing these entries causes kova-live-user.service to fail with 203/EXEC.
cat >> "$PROFILE/profiledef.sh" <<'KOVA_PERMISSIONS'
file_permissions["/usr/local/lib/kova/setup-live-user"]="0:0:755"
file_permissions["/usr/local/lib/kova/update-mirrors"]="0:0:755"
file_permissions["/usr/local/bin/kova"]="0:0:755"
file_permissions["/usr/local/bin/anvil"]="0:0:755"
file_permissions["/usr/local/bin/anvilctl"]="0:0:755"
file_permissions["/usr/local/bin/kova-session"]="0:0:755"
file_permissions["/usr/local/bin/kova-osd"]="0:0:755"
file_permissions["/usr/local/lib/kova/install-system"]="0:0:755"
file_permissions["/usr/local/lib/kova/update-news"]="0:0:755"
file_permissions["/usr/local/lib/kova/update-anvil"]="0:0:755"
file_permissions["/usr/local/lib/kova/update-wallpapers"]="0:0:755"
file_permissions["/usr/local/lib/kova/set-wallpaper"]="0:0:755"
file_permissions["/usr/local/lib/kova/check-battery"]="0:0:755"
# The three default Rust search commands are installed into /usr/local/bin.
file_permissions["/usr/local/bin/grep"]="0:0:755"
file_permissions["/usr/local/bin/find"]="0:0:755"
file_permissions["/usr/local/bin/xargs"]="0:0:755"
KOVA_PERMISSIONS

# Make test-image filenames distinct, and never upload them as production ISOs.
if [[ ${KOVA_CI_IMAGE:-0} == 1 ]]; then
  sed -i 's/^iso_name=.*/iso_name="kova-ci"/' "$PROFILE/profiledef.sh"
  cat >> "$PROFILE/profiledef.sh" <<'KOVA_CI_PERMISSIONS'
file_permissions["/usr/local/lib/kova/ci-smoke"]="0:0:755"
KOVA_CI_PERMISSIONS
fi
# ISO name/branding; keep upstream bootstrap and bootloader configurations unchanged.
# Live networking follows the official releng configuration.
mkdir -p "$OUT"
mkarchiso -v -w "$WORK" -o "$OUT" "$PROFILE"
# Verify the actual assembled SquashFS source, not only the temporary profile.
if [[ ${KOVA_CI_IMAGE:-0} != 1 ]]; then
  for relative in usr/local/lib/kova/ci-smoke etc/systemd/system/kova-ci-smoke.service \
    etc/systemd/system/multi-user.target.wants/kova-ci-smoke.service; do
    test ! -e "$WORK/x86_64/airootfs/$relative" || {
      echo "Refusing to ship a production ISO containing $relative" >&2
      exit 1
    }
  done
fi
# Record package/asset sizes before mkarchiso staging is discarded.
bash "$ROOT/scripts/report-iso-size.sh" "$OUT" "$WORK" "$PROFILE"
(cd "$OUT" && sha256sum ./*.iso > SHA256SUMS)
