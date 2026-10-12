#!/usr/bin/env bash
set -Eeuo pipefail
# Build-only: ship exactly 3 randomly selected offline images in the live ISO.
# A shallow clone still stores large image blobs inside .git; discard it.
root=${1:?Usage: install-wallpapers.sh AIROOTFS}
dest="$root/var/lib/kova/wallpapers/files"
mkdir -p "$dest"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git clone --quiet --depth 1 --single-branch \
  https://github.com/dme86/.wallpapers.git "$tmp/source"
mapfile -d '' -t images < <(
  find "$tmp/source/files" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) \
    -print0 | shuf -z -n 3
)
for file in "${images[@]}"; do
  install -Dm644 "$file" "$dest/$(basename "$file")"
done
test "$(find "$dest" -maxdepth 1 -type f | wc -l)" -eq 3
test ! -e "$root/var/lib/kova/wallpapers/.git"
echo "Kova live ISO: bundled 3 randomly selected wallpapers, no Git checkout:"
printf '  %s\n' "${images[@]##*/}"
