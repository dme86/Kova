#!/usr/bin/env bash
set -Eeuo pipefail
root=${1:?Usage: install-anvil.sh AIROOTFS}
version=0.3.0
name="anvil-$version-x86_64-unknown-linux-gnu"
url="https://github.com/dme86/anvil/releases/download/v$version/$name.tar.gz"
sha256=cc748f81605bb41a0b3d0409d8ead1ba7c461f184c6374db15f9ad5e301e6d01
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
curl -fLsS --retry 3 "$url" -o "$work/$name.tar.gz"
printf '%s  %s\n' "$sha256" "$work/$name.tar.gz" | sha256sum -c -
tar -xzf "$work/$name.tar.gz" -C "$work"
for exe in anvil anvilctl; do
  install -Dm755 "$work/$name/$exe" "$root/usr/local/bin/$exe"
done
mkdir -p "$root/etc/skel/.config/anvil"
sed 's@^startup = \[\]@startup = ["mako", "/usr/local/lib/kova/set-wallpaper"]@' \
  "$work/$name/config.toml" > "$root/etc/skel/.config/anvil/config.toml"
install -Dm644 "$work/$name/anvil.desktop" "$root/usr/share/wayland-sessions/anvil.desktop"
sed -i 's@Exec=/usr/local/bin/anvil@Exec=/usr/local/bin/kova-session@' \
 "$root/usr/share/wayland-sessions/anvil.desktop"
mkdir -p "$root/usr/local/share/kova"
printf '%s\n' "v$version" > "$root/usr/local/share/kova/anvil-version"
echo "Installed pinned Anvil v$version with layer-shell/all features"
