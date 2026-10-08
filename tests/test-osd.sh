#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/wpctl" <<'MOCK'
#!/usr/bin/env bash
if [[ $1 == get-volume ]]; then printf 'Volume: 0.65 [MUTED]\n'; fi
MOCK
cat > "$tmp/brightnessctl" <<'MOCK'
#!/usr/bin/env bash
case "${*: -1}" in get) echo 35 ;; max) echo 100 ;; esac
MOCK
cat > "$tmp/notify-send" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$KOVA_OSD_TEST_NOTIFICATIONS"
MOCK
chmod +x "$tmp/wpctl" "$tmp/brightnessctl" "$tmp/notify-send"
export KOVA_WPCTL="$tmp/wpctl"
export KOVA_BRIGHTNESSCTL="$tmp/brightnessctl"
export KOVA_NOTIFY_SEND="$tmp/notify-send"
export KOVA_OSD_TEST_NOTIFICATIONS="$tmp/notifications"
script="$root/config/airootfs/usr/local/bin/kova-osd"
bash -n "$script"
bash "$script" --help | grep -q 'kova-osd volume'
bash "$script" volume mute
grep -q 'Audio muted' "$tmp/notifications"
grep -q 'int:value:65' "$tmp/notifications"
bash "$script" brightness up
grep -q 'int:value:35' "$tmp/notifications"
grep -q 'kova-brightness' "$tmp/notifications"
if bash "$script" volume invalid 2>/dev/null; then
  echo 'Invalid volume action unexpectedly succeeded' >&2; exit 1
fi
echo 'Kova OSD offline tests passed'
