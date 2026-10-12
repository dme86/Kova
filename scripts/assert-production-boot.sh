#!/usr/bin/env bash
set -euo pipefail
# Host-side verification of an *unmodified* production ISO's serial console.
# systemd does not consistently emit unit start audit records for oneshot
# kova-live-user or long-running getty@tty1; do not wait for those.
(( $# == 1 )) || { echo "Usage: $0 SERIAL_LOG" >&2; exit 2; }
log=$1
[[ -f "$log" ]] || exit 1
# No test instrumentation may boot in a production ISO.
if grep -aEq 'KOVA_CI_(BEGIN|PASS|FAIL)|unit=kova-ci-smoke|kova-ci-smoke.service' "$log"; then
  echo "CI smoke infrastructure detected in production guest" >&2
  exit 2
fi
# The serial login prompt alone could come from serial-getty while tty1 fails.
# A successful PAM login for the ephemeral user on tty1 additionally proves
# that kova-live-user provisioned the account and getty autologin succeeded.
grep -aFq 'kova login:' "$log" &&
  grep -aEq 'acct="kova".*exe="/usr/bin/login".*terminal=/dev/tty1.*res=success' "$log"
