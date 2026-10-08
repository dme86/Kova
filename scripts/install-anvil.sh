#!/usr/bin/env bash
set -Eeuo pipefail
root=${1:?Usage: install-anvil.sh AIROOTFS}
version=3.0.1
name="anvil-$version-x86_64-unknown-linux-gnu"
url="https://github.com/dme86/anvil/releases/download/v$version/$name.tar.gz"
sha256=6842a3fd377e11433c74eb7d8d67cc8b37729e31bd7af05583872354796cf603
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
# Kova uses a Rust terminal and native Anvil XF86 media-key actions.
# The pinned Anvil v3.0.1 understands the [media] section.
config="$root/etc/skel/.config/anvil/config.toml"
sed -i \
  -e 's@^terminal = "foot -o resize-by-cells=no"$@terminal = "alacritty"@' \
  -e 's@^# volume_up = .*@volume_up = "kova-osd volume up"@' \
  -e 's@^# volume_down = .*@volume_down = "kova-osd volume down"@' \
  -e 's@^# volume_mute = .*@volume_mute = "kova-osd volume mute"@' \
  -e 's@^# brightness_up = .*@brightness_up = "kova-osd brightness up"@' \
  -e 's@^# brightness_down = .*@brightness_down = "kova-osd brightness down"@' \
  "$config"
grep -Fqx 'terminal = "alacritty"' "$config"
grep -Fqx 'volume_up = "kova-osd volume up"' "$config"
grep -Fqx 'brightness_down = "kova-osd brightness down"' "$config"
install -Dm644 "$work/$name/anvil.desktop" "$root/usr/share/wayland-sessions/anvil.desktop"
sed -i 's@Exec=/usr/local/bin/anvil@Exec=/usr/local/bin/kova-session@' \
 "$root/usr/share/wayland-sessions/anvil.desktop"
mkdir -p "$root/usr/local/share/kova"
printf '%s\n' "v$version" > "$root/usr/local/share/kova/anvil-version"
echo "Installed pinned Anvil v$version with layer-shell/all features"
