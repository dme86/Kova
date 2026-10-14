#!/usr/bin/env bash
set -euo pipefail
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
printf 'ISO\n' > "$tmp/kova.iso"
printf 'CODE\n' > "$tmp/code.fd"
printf 'VARS\n' > "$tmp/vars.fd"
KOVA_OVMF_CODE="$tmp/code.fd" KOVA_OVMF_VARS_TEMPLATE="$tmp/vars.fd" \
 KOVA_QEMU_STATE_DIR="$tmp/new-nvram" KOVA_QEMU_DRY_RUN=1 \
 bash scripts/qemu-macos.sh "$tmp/kova.iso" > "$tmp/run.txt"
grep -Fq 'if=pflash,format=raw,readonly=on' "$tmp/run.txt"
grep -Fq 'media=cdrom' "$tmp/run.txt"
grep -Fq 'order=d,menu=on' "$tmp/run.txt"
cmp "$tmp/vars.fd" "$tmp/new-nvram/kova-uefi-vars-fresh.fd"
printf 'OLD_NVRAM_DO_NOT_TOUCH\n' > "$tmp/uefi-vars.fd"
KOVA_OVMF_CODE="$tmp/code.fd" KOVA_OVMF_VARS_TEMPLATE="$tmp/vars.fd" \
 KOVA_QEMU_STATE_DIR="$tmp/new-nvram" KOVA_QEMU_DRY_RUN=1 \
 bash scripts/qemu-macos.sh "$tmp/kova.iso" > /dev/null
grep -Fxq 'OLD_NVRAM_DO_NOT_TOUCH' "$tmp/uefi-vars.fd"
KOVA_QEMU_FIRMWARE=bios KOVA_QEMU_DRY_RUN=1 \
 bash scripts/qemu-macos.sh "$tmp/kova.iso" > "$tmp/bios.txt"
if grep -Fq 'if=pflash' "$tmp/bios.txt"; then
  echo 'BIOS mode incorrectly set up UEFI pflash' >&2; exit 1
fi
if KOVA_OVMF_CODE="$tmp/code.fd" KOVA_QEMU_DRY_RUN=1 \
 bash scripts/qemu-macos.sh "$tmp/kova.iso" > /dev/null 2>&1; then
  echo "Missing UEFI VARS template was accepted" >&2; exit 1
fi
echo "macOS safe QEMU boot helper: OK"
