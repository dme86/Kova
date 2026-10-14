#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY'
from pathlib import Path
build = Path("scripts/build.sh").read_text()
assert "BOOT_ARGS='console=ttyS0,115200n8 console=tty0 quiet loglevel=5 systemd.log_level=warning'" in build
assert "BOOT_ARGS='console=ttyS0,115200n8 console=tty0 loglevel=6 systemd.log_level=info systemd.log_target=kmsg'" in build
assert build.count('"$BOOT_ARGS"') == 2, "Both BIOS and UEFI must use selected policy"
assert "audit=0" not in build, "Do not disable kernel auditing"
assert "kova-live-ready.service" in build
assert 'file_permissions["/usr/local/lib/kova/report-live-session"]="0:0:755"' in build
unit = Path("config/airootfs/etc/systemd/system/kova-live-ready.service").read_text()
assert "After=kova-live-user.service systemd-logind.service" in unit
assert "ConditionPathExists=/dev/ttyS0" in unit
print("Firmware-specific console policies and logind proof wiring: OK")
PY
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/loginctl" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == list-sessions ]]; then
  printf '42 1000 kova seat0 tty1\n'
elif [[ "$1" == show-session ]]; then
  printf 'Name=kova\nTTY=%s\nState=%s\n' "${KOVA_MOCK_TTY:-tty1}" "${KOVA_MOCK_STATE:-active}"
fi
MOCK
chmod +x "$tmp/loginctl"
KOVA_LIVE_TEST_FILE=1 KOVA_LIVE_SERIAL="$tmp/serial" KOVA_LOGINCTL="$tmp/loginctl" \
  KOVA_LIVE_MAX_ATTEMPTS=1 bash config/airootfs/usr/local/lib/kova/report-live-session
grep -Fxq 'KOVA_LIVE_TTY1_READY user=kova tty=tty1' "$tmp/serial"
rm -f "$tmp/serial"
if KOVA_MOCK_TTY=ttyS0 KOVA_LIVE_TEST_FILE=1 KOVA_LIVE_SERIAL="$tmp/serial" \
   KOVA_LOGINCTL="$tmp/loginctl" KOVA_LIVE_MAX_ATTEMPTS=1 \
   bash config/airootfs/usr/local/lib/kova/report-live-session; then
  echo "False positive: serial session passed tty1 check" >&2
  exit 1
fi
test ! -e "$tmp/serial"
if KOVA_MOCK_STATE=closing KOVA_LIVE_TEST_FILE=1 KOVA_LIVE_SERIAL="$tmp/serial" \
   KOVA_LOGINCTL="$tmp/loginctl" KOVA_LIVE_MAX_ATTEMPTS=1 \
   bash config/airootfs/usr/local/lib/kova/report-live-session; then
  echo "False positive: inactive session passed tty1 check" >&2
  exit 1
fi
echo "Quiet live boot and real logind proof: OK"
