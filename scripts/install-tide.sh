#!/usr/bin/env bash
set -euo pipefail
# Tide v6 installed as global Fish functions, no first-boot network needed.
# Tide is loaded for every user. Kova seeds Fish universal defaults on first login.
# No interactive `tide configure` step is needed; users may customize later.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fL --retry 3 https://codeload.github.com/IlanCosman/tide/tar.gz/refs/tags/v6 -o "$tmp/tide.tar.gz"
mkdir -p "$tmp/unpacked"
tar -xzf "$tmp/tide.tar.gz" -C "$tmp/unpacked" --strip-components=1
base="$1"
for dir in completions conf.d functions; do
  install -d "$base/etc/fish/$dir"
  cp -a "$tmp/unpacked/$dir/." "$base/etc/fish/$dir/"
done
