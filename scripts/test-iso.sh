#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ISO=$(find "$ROOT/out" -maxdepth 1 -name '*.iso' -type f -print -quit)
[[ -n "$ISO" ]] || { echo "No Kova ISO found in out/" >&2; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "QEMU is not installed" >&2; exit 1; }

LOG_DIR="$ROOT/test-results"
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

echo "Booting $(basename "$ISO") with QEMU (accelerator: $ACCEL)"
qemu-system-x86_64 \
  -machine "q35,accel=$ACCEL" \
  -cpu max \
  -smp 2 \
  -m 3072 \
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
  if grep -q 'KOVA_CI_PASS' "$SERIAL_LOG"; then
    echo "Kova boot and guest smoke tests passed."
    grep 'KOVA_CI_' "$SERIAL_LOG" | tail -n 25 || true
    exit 0
  fi
  if grep -q 'KOVA_CI_FAIL' "$SERIAL_LOG" ||
     grep -q 'kova-ci-smoke.service: Failed with result' "$SERIAL_LOG"; then
    echo "Guest smoke test failed. CI steps and last serial output:" >&2
    grep -a 'KOVA_CI_' "$SERIAL_LOG" >&2 || true
    tail -n 120 "$SERIAL_LOG" >&2
    exit 1
  fi
  if ! kill -0 "$QEMU_PID" 2>/dev/null; then
    echo "QEMU exited before the guest reported success." >&2
    cat "$QEMU_LOG" >&2
    tail -n 120 "$SERIAL_LOG" >&2
    exit 1
  fi
  sleep 2
done

echo "Timed out waiting for the Kova guest smoke test." >&2
cat "$QEMU_LOG" >&2
tail -n 120 "$SERIAL_LOG" >&2
exit 1
