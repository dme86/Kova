#!/usr/bin/env bash
set -Eeuo pipefail
root=${1:?Usage: install-anvil.sh AIROOTFS}
version=0.6.4
name="anvil-$version-x86_64-unknown-linux-gnu"
url="https://github.com/dme86/anvil/releases/download/v$version/$name.tar.gz"
sha256=36e47f3393471db7ecb80c02d76e943b239124f838c4e05a6ba08ba484f0d802
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
# Pinned Anvil v0.6.4 ships [media], [bar.network] and the native overview.
# Its release archive is built with all features; runtime XWayland stays opt-in.
config="$root/etc/skel/.config/anvil/config.toml"
sed -i \
  -e 's@^terminal = "foot -o resize-by-cells=no"$@terminal = "alacritty"@' \
  -e 's@^# volume_up = .*@volume_up = "kova-osd volume up"@' \
  -e 's@^# volume_down = .*@volume_down = "kova-osd volume down"@' \
  -e 's@^# volume_mute = .*@volume_mute = "kova-osd volume mute"@' \
  -e 's@^# brightness_up = .*@brightness_up = "kova-osd brightness up"@' \
  -e 's@^# brightness_down = .*@brightness_down = "kova-osd brightness down"@' \
  -e 's@^enabled = false$@enabled = true@' \
  "$config"
grep -Fqx 'terminal = "alacritty"' "$config"
grep -Fqx 'volume_up = "kova-osd volume up"' "$config"
grep -Fqx 'brightness_down = "kova-osd brightness down"' "$config"
grep -Fqx 'overview = "Tab"' "$config"
grep -Fqx 'xwayland = false' "$config"
grep -Fqx '[bar.network]' "$config"
grep -Fqx 'enabled = true' "$config"
grep -Fqx 'click_command = "alacritty -e nmtui-connect"' "$config"
install -Dm644 "$work/$name/anvil.desktop" "$root/usr/share/wayland-sessions/anvil.desktop"
sed -i 's@Exec=/usr/local/bin/anvil@Exec=/usr/local/bin/kova-session@' \
 "$root/usr/share/wayland-sessions/anvil.desktop"
mkdir -p "$root/usr/local/share/kova"
printf '%s\n' "v$version" > "$root/usr/local/share/kova/anvil-version"
echo "Installed pinned Anvil v$version with layer-shell/all features"
