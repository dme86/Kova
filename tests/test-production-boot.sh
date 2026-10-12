#!/usr/bin/env bash
set -euo pipefail
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Excerpts from an ACTUAL passing Kova production guest boot in GitHub Actions,
# whose old smoke validator timed out waiting for nonexistent unit audit events.
cat > "$tmp/boot.log" <<'LOG'
[ 206.914203] audit: type=1114 audit(...): msg='op=add-user acct="kova" exe="/usr/bin/useradd" hostname=? terminal=? res=success'
[ 213.114240] audit: type=1101 audit(...): msg='op=PAM:accounting acct="kova" exe="/usr/bin/login" hostname=kova addr=? terminal=/dev/tty1 res=success'
kova login: [ 214.840035] audit: type=1130 audit(...): msg='unit=user-runtime-dir@1000 ... res=success'
LOG
bash scripts/assert-production-boot.sh "$tmp/boot.log"

# Serial-getty alone does not prove that tty1 autologin has succeeded.
printf 'kova login:\n' > "$tmp/serial-only.log"
if bash scripts/assert-production-boot.sh "$tmp/serial-only.log"; then
  echo "False positive: serial getty mistaken for tty1 autologin" >&2; exit 1
fi

# Test-only services must never be observed when booting the published image.
cp "$tmp/boot.log" "$tmp/ci-leak.log"
printf '[ 20.0] KOVA_CI_BEGIN\n' >> "$tmp/ci-leak.log"
if bash scripts/assert-production-boot.sh "$tmp/ci-leak.log"; then
  echo "False positive: production accepted a CI-instrumented guest" >&2; exit 1
fi

# An audit record for another user or serial port is not a tty1 login.
sed 's@terminal=/dev/tty1@terminal=/dev/ttyS0@' "$tmp/boot.log" > "$tmp/wrong-tty.log"
if bash scripts/assert-production-boot.sh "$tmp/wrong-tty.log"; then
  echo "False positive: production accepted a serial-console login" >&2; exit 1
fi

echo "Production-ISO serial login validator fixture: OK"
