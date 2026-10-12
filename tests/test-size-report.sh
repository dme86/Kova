#!/usr/bin/env bash
set -Eeuo pipefail
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
root="$tmp/work/x86_64/airootfs"
mkdir -p "$tmp/out" "$tmp/profile" "$root/usr/lib" "$root/opt" \
  "$root/var/lib/pacman/local/test-1" "$root/var/lib/kova/wallpapers/files" \
  "$root/var/lib/kova/wallpapers/.git"
truncate -s 4096 "$tmp/out/kova-test.iso"
printf 'base\nlinux\n# comment\n' > "$tmp/profile/packages.x86_64"
printf 'fakepng\n' > "$root/var/lib/kova/wallpapers/files/one.png"
printf 'fakejpg\n' > "$root/var/lib/kova/wallpapers/files/two.jpg"
printf 'metadata\n' > "$root/var/lib/kova/wallpapers/.git/HEAD"
cat > "$root/var/lib/pacman/local/test-1/desc" <<'DESC'
%NAME%
test-package

%SIZE%
1048576
DESC
bash scripts/report-iso-size.sh "$tmp/out" "$tmp/work" "$tmp/profile"
report="$tmp/out/SIZE_REPORT.md"
grep -Fq '| kova-test.iso | 4096 | 0 |' "$report"
grep -Fq -- '- Explicit package declarations: 2' "$report"
grep -Fq -- '- Offline wallpaper images: 2' "$report"
grep -Fq -- '- Wallpaper image bytes: 16' "$report"
grep -Fq -- '- Embedded wallpaper git checkout bytes:' "$report"
grep -Fq $'1.0 MiB\ttest-package' "$report"
echo "ISO size audit fixture passed"
