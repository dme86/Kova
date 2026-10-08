#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

cat > "$work/ranker" <<'MOCK'
#!/usr/bin/env bash
if [[ ${MOCK_RANKER_FAIL:-0} == 1 ]]; then
  echo 'network unavailable' >&2
  exit 1
fi
if [[ ${MOCK_RANKER_INVALID:-0} == 1 ]]; then
  echo 'Server = http://invalid.example/archlinux/$repo/os/$arch'
  exit 0
fi
printf 'Server = https://a.example/archlinux/$repo/os/$arch\n'
printf 'Server = https://b.example/archlinux/$repo/os/$arch\n'
printf 'Server = https://c.example/archlinux/$repo/os/$arch\n'
MOCK
chmod +x "$work/ranker"

export KOVA_MIRRORLIST="$work/mirrorlist"
export KOVA_MIRROR_STAMP="$work/state/stamp"
export KOVA_RATE_MIRRORS="$work/ranker"
echo 'Server = https://original.example/$repo/os/$arch' > "$KOVA_MIRRORLIST"

bash "$root/config/airootfs/usr/local/lib/kova/update-mirrors"
test "$(grep -c '^Server = https://' "$KOVA_MIRRORLIST")" = 3
grep -q 'original.example' "$KOVA_MIRRORLIST.kova-previous"
test -f "$KOVA_MIRROR_STAMP"

MOCK_RANKER_FAIL=1 bash "$root/config/airootfs/usr/local/lib/kova/update-mirrors"
test "$(grep -c '^Server = https://' "$KOVA_MIRRORLIST")" = 3

if KOVA_MIRRORS_FORCE=1 MOCK_RANKER_FAIL=1 bash "$root/config/airootfs/usr/local/lib/kova/update-mirrors"; then
  echo 'Expected network failure did not occur' >&2; exit 1
fi
test "$(grep -c '^Server = https://' "$KOVA_MIRRORLIST")" = 3

if KOVA_MIRRORS_FORCE=1 MOCK_RANKER_INVALID=1 bash "$root/config/airootfs/usr/local/lib/kova/update-mirrors"; then
  echo 'Expected invalid list rejection did not occur' >&2; exit 1
fi
test "$(grep -c '^Server = https://' "$KOVA_MIRRORLIST")" = 3
echo 'Kova mirror updater tests passed'
