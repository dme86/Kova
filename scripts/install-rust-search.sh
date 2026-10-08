#!/usr/bin/env bash
set -euo pipefail

# Rust implementations of GNU-compatible search commands, pinned to releases.
# These live in /usr/local/bin in the image, which takes precedence over
# /usr/bin. Pacman-owned GNU files remain available as an emergency fallback.
ROOT=${1:?Usage: install-rust-search.sh <airootfs directory>}
DEST="$ROOT/usr/local/bin"
mkdir -p "$DEST"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

install_release() {
  local project=$1 version=$2 asset=$3 sha256=$4
  shift 4
  local archive="$TMP/$asset" extracted="$TMP/$project"
  mkdir -p "$extracted"
  curl -fLsS --retry 3 --retry-delay 2 \
    "https://github.com/uutils/$project/releases/download/$version/$asset" \
    -o "$archive"
  printf '%s  %s\n' "$sha256" "$archive" | sha256sum -c -
  tar -xJf "$archive" -C "$extracted"

  local name binary
  for name in "$@"; do
    binary=$(find "$extracted" -type f -name "$name" -print -quit)
    [[ -n "$binary" ]] || { echo "Missing $name in $asset" >&2; exit 1; }
    install -m 0755 "$binary" "$DEST/$name"
    echo "Installed Rust $name from uutils/$project $version"
  done
}

install_release grep 0.2.0 \
  uu_grep-x86_64-unknown-linux-gnu.tar.xz \
  7ffdf7ef9fee0fc07b6a389f14fad0b5236011cf1d08885ffe69f0831f2923e5 \
  grep

install_release findutils 0.10.0 \
  findutils-x86_64-unknown-linux-gnu.tar.xz \
  7322849977b571a82bdaab589ca982129bf4c1e38686e366d7bd04b6e11455d9 \
  find xargs

# Verify expected commands are executable before mkarchiso assembles the image.
for cmd in grep find xargs; do test -x "$DEST/$cmd"; done
