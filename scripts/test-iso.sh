#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ISO_DIR=${KOVA_TEST_ISO_DIR:-"$ROOT/out"}
MODE=${KOVA_TEST_MODE:-production}
case "$MODE" in ci|production) ;; *) echo "KOVA_TEST_MODE must be ci or production" >&2; exit 2 ;; esac
FIRMWARE=${KOVA_TEST_FIRMWARE:-bios}
case "$FIRMWARE" in bios|uefi) ;; *) echo "KOVA_TEST_FIRMWARE must be bios or uefi" >&2; exit 2 ;; esac
ISO=$(find "$ISO_DIR" -maxdepth 1 -name '*.iso' -type f -print -quit)
[[ -n "$ISO" ]] || { echo "No Kova ISO found in out/" >&2; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "QEMU is not installed" >&2; exit 1; }

LOG_DIR="$ROOT/test-results/$MODE-$FIRMWARE"
mkdir -p "$LOG_DIR"
SERIAL_LOG="$LOG_DIR/qemu-serial.log"
QEMU_LOG="$LOG_DIR/qemu-stderr.log"
: > "$SERIAL_LOG"
: > "$QEMU_LOG"

# GitHub-hosted runners may expose KVM, but nested virtualization is not
# supported by GitHub. QEMU falls back to TCG if KVM cannot initialize.
ACCEL="tcg"
if [[ -c /dev/kvm && -r /dev/kvm && -w /dev/kvm ]]; then
  ACCEL="kvm:tcg"
fi

firmware_args=()
if [[ $FIRMWARE == uefi ]]; then
  # Ubuntu's ovmf package supplies separate readonly firmware and writable vars.
  code=${KOVA_OVMF_CODE:-/usr/share/OVMF/OVMF_CODE_4M.fd}
  vars=${KOVA_OVMF_VARS:-/usr/share/OVMF/OVMF_VARS_4M.fd}
  [[ -r "$code" && -r "$vars" ]] || { echo "OVMF images missing: $code $vars" >&2; exit 1; }
  cp "$vars" "$LOG_DIR/ovmf-vars.fd"
  firmware_args=(
    -drive "if=pflash,format=raw,readonly=on,file=$code"
    -drive "if=pflash,format=raw,file=$LOG_DIR/ovmf-vars.fd"
  )
fi

echo "Booting $(basename "$ISO") with QEMU ($FIRMWARE, accelerator: $ACCEL)"
qemu-system-x86_64 \
  -machine "q35,accel=$ACCEL" \
  -cpu max \
  -smp 2 \
  -m 3072 \
  "${firmware_args[@]}" \
  -boot order=d \
  -drive "file=$ISO,media=cdrom,format=raw,readonly=on" \
  -display none \
  -monitor none \
  -serial "file:$SERIAL_LOG" \
  -netdev user,id=net0 \
  -device virtio-net-pci,netdev=net0 \
  -no-reboot \
  > /dev/null 2> "$QEMU_LOG" &
QEMU_PID=$!

cleanup() {
  if kill -0 "$QEMU_PID" 2>/dev/null; then
    kill "$QEMU_PID" 2>/dev/null || true
  fi
  wait "$QEMU_PID" 2>/dev/null || true
}
trap cleanup EXIT

# 10 minutes is intentionally generous for software emulation (TCG).
DEADLINE=$((SECONDS + 600))
while (( SECONDS < DEADLINE )); do
  if [[ $MODE == ci ]]; then
    if grep -aq 'KOVA_CI_PASS' "$SERIAL_LOG"; then
      echo "Kova instrumented guest smoke tests passed."
      grep -a 'KOVA_CI_' "$SERIAL_LOG" | tail -n 25 || true
      exit 0
    fi
    if grep -aq 'KOVA_CI_FAIL' "$SERIAL_LOG" ||
       grep -aq 'kova-ci-smoke.service: Failed with result' "$SERIAL_LOG"; then
      echo "Guest smoke test failed. CI steps and last serial output:" >&2
      grep -a 'KOVA_CI_' "$SERIAL_LOG" >&2 || true
      tail -n 120 "$SERIAL_LOG" >&2
      exit 1
    fi
  else
    if grep -aq 'KOVA_CI_BEGIN' "$SERIAL_LOG" || grep -aq 'unit=kova-ci-smoke' "$SERIAL_LOG"; then
      echo "PRODUCTION ISO BOOTED CI-ONLY TEST UNIT; refusing release!" >&2
      exit 1
    fi
    # This verifies the actual public ISO boots to a live login (BIOS).
    # The CI image separately runs full interactive shell/desktop assertions.
    if grep -aq 'unit=kova-live-user.*res=success' "$SERIAL_LOG" &&
       grep -aq 'unit=getty@tty1.*res=success' "$SERIAL_LOG" &&
       grep -aq 'kova login:' "$SERIAL_LOG"; then
      # Keep a visible trace of the /dev/sr0 loop-device warning from #14
      # rather than masking unrelated systemd failures to make CI green.
      if grep -aq 'Failed to start Attach File.*Loopback Block Device' "$SERIAL_LOG"; then
        echo "::warning::Systemd reported a loopback attachment failure; inspect the QEMU serial artifact (issue #14)."
      fi
      echo "Unmodified production Kova ISO booted with live user and login."
      exit 0
    fi
  fi
  if ! kill -0 "$QEMU_PID" 2>/dev/null; then
    echo "QEMU exited before the guest reported success." >&2
    cat "$QEMU_LOG" >&2
    tail -n 120 "$SERIAL_LOG" >&2
    exit 1
  fi
  sleep 2
done

echo "Timed out waiting for the Kova $MODE guest boot signal." >&2
cat "$QEMU_LOG" >&2
tail -n 120 "$SERIAL_LOG" >&2
exit 1
