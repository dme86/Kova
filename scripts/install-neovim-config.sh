#!/usr/bin/env bash
set -euo pipefail

# Vendor dme86's Neovim configuration into /etc/skel so new users
# (including the auto-created kova live user) inherit the same config.
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TARGET="$ROOT/config/airootfs/etc/skel/.config/nvim"
SOURCE_URL=${KOVA_NVIM_REPO:-https://github.com/dme86/neovim.git}
SOURCE_REF=${KOVA_NVIM_REF:-main}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

git clone --quiet --depth 1 --branch "$SOURCE_REF" "$SOURCE_URL" "$tmp/neovim"
install -d "$(dirname "$TARGET")"
rm -rf "$TARGET"
install -d "$TARGET"
cp -a "$tmp/neovim/." "$TARGET/"
rm -rf "$TARGET/.git"
printf '%s\n' "$(git -C "$tmp/neovim" rev-parse HEAD)" > "$TARGET/.kova-source-commit"
chmod -R a+rX "$TARGET"
printf 'Vendored Neovim config (%s): %s\n' "$SOURCE_REF" "$(cat "$TARGET/.kova-source-commit")"
