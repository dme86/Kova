#!/usr/bin/env bash
set -euo pipefail

PROFILE=${1:?Expected the Archiso profile directory}

# The releng profile is copied at build time: adjust its menu text without
# vendoring the upstream bootloader configurations.
for entry in "$PROFILE/syslinux/"*.cfg "$PROFILE/efiboot/loader/entries/"*.conf "$PROFILE/grub/"*.cfg; do
  [[ -f "$entry" ]] || continue
  sed -i \
    -e 's/It allows you to install Arch Linux or perform system maintenance\./Kova is an experimental live environment for development and recovery./g' \
    -e 's/Arch Linux install medium/Kova Linux live environment/g' \
    -e 's/Arch Linux live medium/Kova Linux live environment/g' \
    -e 's/Arch Linux/Kova Linux/g' \
    "$entry"
done

# Drop the upstream Arch splash image from the BIOS menu.
# A dedicated Kova splash can replace it later.
sed -i '/^MENU BACKGROUND splash\.png$/d' "$PROFILE/syslinux/archiso_head.cfg"
rm -f "$PROFILE/syslinux/splash.png"

grep -q 'MENU TITLE Kova Linux' "$PROFILE/syslinux/archiso_head.cfg"
grep -q 'MENU LABEL Kova Linux live environment' "$PROFILE/syslinux/archiso_sys-linux.cfg"
grep -q '^title    Kova Linux live environment' "$PROFILE/efiboot/loader/entries/01-archiso-linux.conf"
