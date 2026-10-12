#!/usr/bin/env bash
set -Eeuo pipefail
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/source/files" "$tmp/bin" "$tmp/live"
for n in 01 02 03 04 05 06 07 08 09; do
  printf "wallpaper %s\n" "$n" > "$tmp/source/files/wallpaper-$n.jpeg"
done
cat > "$tmp/bin/git" <<'FAKE_GIT'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ $1 == clone ]] || { echo "Only clone is permitted" >&2; exit 1; }
dest=${@: -1}
mkdir -p "$dest"
cp -a "$WALLPAPER_TEST_SOURCE/." "$dest/"
mkdir -p "$dest/.git"
FAKE_GIT
chmod +x "$tmp/bin/git"
PATH="$tmp/bin:$PATH" WALLPAPER_TEST_SOURCE="$tmp/source" \
  bash scripts/install-wallpapers.sh "$tmp/live"
seed_dir="$tmp/live/var/lib/kova/wallpapers/files"
test "$(find "$seed_dir" -maxdepth 1 -type f | wc -l)" -eq 3
test ! -e "$tmp/live/var/lib/kova/wallpapers/.git"
test ! -e "$tmp/live/var/lib/kova/wallpapers/cache"
grep -Fq "OnBootSec=2min" config/airootfs/etc/systemd/system/kova-update-wallpapers.timer
! grep -Fq "OnCalendar=" config/airootfs/etc/systemd/system/kova-update-wallpapers.timer
grep -Fq "ExecStart=/usr/local/bin/kova wallpaper boot" config/airootfs/etc/systemd/system/kova-update-wallpapers.service
grep -Fq "exec /usr/local/bin/kova wallpaper sync" config/airootfs/usr/local/lib/kova/update-wallpapers
grep -Fq 'Some("wallpaper") => wallpapers::run(&args[1..]),' crates/kova-cli/src/main.rs
echo "Wallpaper pool packaging and service fixtures: OK"
