#!/usr/bin/env bash
set -euo pipefail
[[ $(id -u) -eq 0 ]] || { echo 'Run as root inside Arch Linux'; exit 1; }
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
WORK=${KOVA_WORK:-/tmp/kova-archiso-work}
PROFILE=$(mktemp -d /tmp/kova-profile.XXXXXX)
trap 'rm -rf "$PROFILE"' EXIT
cp -a /usr/share/archiso/configs/releng/. "$PROFILE/"
cp -a "$ROOT/config/airootfs/." "$PROFILE/airootfs/"
# Enable the first-boot user provisioning service in the live image.
mkdir -p "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants"
ln -s ../kova-live-user.service "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants/kova-live-user.service"
cat >> "$PROFILE/packages.x86_64" <<'PKGS'
fish
neovim
git
networkmanager
eza
bat
fd
ripgrep
bottom
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
# ISO name/branding; keep upstream bootstrap and bootloader configurations unchanged.
# Live networking follows the official releng configuration.
mkdir -p "$ROOT/out"
mkarchiso -v -w "$WORK" -o "$ROOT/out" "$PROFILE"
(cd "$ROOT/out" && sha256sum ./*.iso > SHA256SUMS)
