#!/usr/bin/env bash
set -euo pipefail
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Observed serial getty login prompt + independent logind tty1 confirmation.
cat > "$tmp/boot.log" <<'LOG'
kova login:
KOVA_LIVE_TTY1_READY user=kova tty=tty1
LOG
bash scripts/assert-production-boot.sh "$tmp/boot.log"

printf 'kova login:\n' > "$tmp/serial-only.log"
if bash scripts/assert-production-boot.sh "$tmp/serial-only.log"; then
  echo "False positive: serial getty mistaken for tty1 autologin" >&2; exit 1
fi

cp "$tmp/boot.log" "$tmp/ci-leak.log"
printf '[ 20.0] KOVA_CI_BEGIN\n' >> "$tmp/ci-leak.log"
if bash scripts/assert-production-boot.sh "$tmp/ci-leak.log"; then
  echo "False positive: production accepted a CI-instrumented guest" >&2; exit 1
fi

sed 's@tty=tty1@tty=ttyS0@' "$tmp/boot.log" > "$tmp/wrong-tty.log"
if bash scripts/assert-production-boot.sh "$tmp/wrong-tty.log"; then
  echo "False positive: production accepted a serial-console login" >&2; exit 1
fi

sed 's@user=kova@user=root@' "$tmp/boot.log" > "$tmp/wrong-user.log"
if bash scripts/assert-production-boot.sh "$tmp/wrong-user.log"; then
  echo "False positive: production accepted another user's login" >&2; exit 1
fi

echo "Production-ISO real tty1 login marker validator: OK"
