#!/usr/bin/env bash
set -Eeuo pipefail
root=${1:?Usage: install-wallpapers.sh AIROOTFS}
repo="$root/var/lib/kova/wallpapers"
mkdir -p "$(dirname "$repo")"
if [[ ! -d "$repo/.git" ]]; then
  git clone --depth 1 --single-branch https://github.com/dme86/.wallpapers.git "$repo"
fi
count=$(find "$repo/files" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) | wc -l)
((count > 0)) || { echo "Wallpaper repository has no images" >&2; exit 1; }
echo "Bundled $count wallpapers for offline use"
