#!/usr/bin/env bash
set -euo pipefail
# Local ISO boot launcher for Apple Silicon/x86_64 TCG (issue #29).
# Never overwrites existing qcow2 disks or the user's earlier UEFI NVRAM.
if (( $# != 1 )); then
  echo "Usage: KOVA_OVMF_CODE=/path/code.fd KOVA_OVMF_VARS_TEMPLATE=/path/vars.fd scripts/qemu-macos.sh /path/kova.iso" >&2
  exit 2
fi
iso=$1
[[ -r "$iso" ]] || { echo "ISO not readable: $iso" >&2; exit 1; }
mode=${KOVA_QEMU_FIRMWARE:-uefi}
case "$mode" in bios|uefi) ;; *) echo "KOVA_QEMU_FIRMWARE must be bios or uefi" >&2; exit 2 ;; esac
args=(-machine q35,accel=tcg -cpu max -smp 2 -m 4096)
if [[ "$mode" == uefi ]]; then
  code=${KOVA_OVMF_CODE:-}
  template=${KOVA_OVMF_VARS_TEMPLATE:-}
  [[ -n "$code" && -f "$code" && -r "$code" ]] || { echo "KOVA_OVMF_CODE: specify the readable OVMF CODE image" >&2; exit 2; }
  [[ -n "$template" && -f "$template" && -r "$template" ]] || { echo "KOVA_OVMF_VARS_TEMPLATE: specify its matching pristine VARS template" >&2; exit 2; }
  state=${KOVA_QEMU_STATE_DIR:-/tmp/kovavm/kova-uefi}
  mkdir -p "$state"
  vars="$state/kova-uefi-vars-fresh.fd"
  # Separate filename: the old user-owned uefi-vars.fd is never modified.
  if [[ ! -e "$vars" ]]; then
    cp "$template" "$vars"
  fi
  [[ -f "$vars" && -w "$vars" ]] || { echo "UEFI NVRAM not writable: $vars" >&2; exit 1; }
  args+=(-drive "if=pflash,format=raw,readonly=on,file=$code")
  args+=(-drive "if=pflash,format=raw,file=$vars")
fi
args+=(-boot order=d,menu=on)
args+=(-drive "file=$iso,media=cdrom,format=raw,readonly=on")
if [[ -n ${KOVA_QEMU_DISK:-} ]]; then
  [[ -f "$KOVA_QEMU_DISK" ]] || { echo "Disk not found: $KOVA_QEMU_DISK" >&2; exit 1; }
  args+=(-drive "file=$KOVA_QEMU_DISK,format=qcow2,if=virtio")
fi
args+=(-device virtio-vga -display cocoa -nic user,model=virtio-net-pci)
binary=${KOVA_QEMU_BINARY:-qemu-system-x86_64}
if [[ ${KOVA_QEMU_DRY_RUN:-0} == 1 ]]; then
  printf '%q ' "$binary" "${args[@]}"
  printf '\n'
else
  exec "$binary" "${args[@]}"
fi
