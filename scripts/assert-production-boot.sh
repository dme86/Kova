#!/usr/bin/env bash
set -euo pipefail
# Host-side verification of an unmodified production ISO's serial console.
# Audit NOTICE printk is intentionally hidden from the *console* on production
# images. Require an active logind session on real tty1 instead of audit text.
(( $# == 1 )) || { echo "Usage: $0 SERIAL_LOG" >&2; exit 2; }
log=$1
[[ -f "$log" ]] || exit 1
if grep -aEq 'KOVA_CI_(BEGIN|PASS|FAIL)|unit=kova-ci-smoke|kova-ci-smoke.service' "$log"; then
  echo "CI smoke infrastructure detected in production guest" >&2
  exit 2
fi
# A serial-getty login prompt alone does not prove tty1 autologin. The
# production live-ready service emits this marker only after loginctl reports
# an *active* session belonging to kova on tty1.
grep -aFq 'kova login:' "$log" &&
  grep -aFq 'KOVA_LIVE_TTY1_READY user=kova tty=tty1' "$log"
