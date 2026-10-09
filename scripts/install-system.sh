#!/usr/bin/env bash
set -Eeuo pipefail
# WARNING: permanently erases the entire selected drive. UEFI, single disk only.
# Invoked by 'kova install --apply'; password is read on stdin, not argv.
[[ $# == 8 && $EUID -eq 0 && -d /sys/firmware/efi ]] ||
 { echo "Kova installer requires root, UEFI and exact arguments" >&2; exit 2; }
disk=$1; expected_id=$2; username=$3; hostname=$4
locale=$5; keyboard=$6; timezone=$7; token=$8
[[ $disk == /dev/* && -b $disk ]] || exit 1
[[ $username =~ ^[a-z_][a-z0-9_-]{0,31}$ && $hostname =~ ^[a-z][a-z0-9-]{0,31}$ ]] || exit 1
[[ $locale =~ ^[a-zA-Z0-9_.@-]+$ && $keyboard =~ ^[a-zA-Z0-9_-]+$ ]] || exit 1
[[ $timezone =~ ^[a-zA-Z0-9_+/-]+$ && $timezone != *..* && -e /usr/share/zoneinfo/$timezone ]] || exit 1
for file in /usr/local/bin/anvil /usr/local/bin/anvilctl /usr/local/bin/kova /usr/local/bin/kova-session; do
  [[ -x $file ]] || { echo "Missing $file from Kova ISO" >&2; exit 1; }
done
[[ -d /var/lib/kova/wallpapers/files ]] || { echo "Missing Kova wallpapers" >&2; exit 1; }
# Verify actual block device identity just before ANY modification.
type=$(lsblk -dn -o TYPE -- "$disk" | tr -d '[:space:]')
ro=$(lsblk -dn -o RO -- "$disk" | tr -d '[:space:]')
rm=$(lsblk -dn -o RM -- "$disk" | tr -d '[:space:]')
transport=$(lsblk -dn -o TRAN -- "$disk" | tr -d '[:space:]')
majmin=$(lsblk -dn -o MAJ:MIN -- "$disk" | tr -d '[:space:]')
bytes=$(lsblk -bdn -o SIZE -- "$disk" | tr -d '[:space:]')
[[ $type == disk && $ro == 0 && $rm == 0 && $transport != usb && $majmin == "$expected_id" ]] ||
 { echo "Disk identity changed or target is unsafe (read-only/removable/USB)" >&2; exit 1; }
(( bytes >= 16*1024*1024*1024 )) || { echo "Target too small" >&2; exit 1; }
if lsblk -nr -o MOUNTPOINTS -- "$disk" | grep -q '[^[:space:]]'; then
  echo "Target or child partition is mounted; refusing to erase" >&2; exit 1
fi
if lsblk -nr -o FSTYPE -- "$disk" | grep -Eq 'iso9660|squashfs'; then
  echo "Installation medium detected on target; refusing erase" >&2
  exit 1
fi
[[ $token == "ERASE:$majmin" ]] || { echo "Missing device-specific erase confirmation" >&2; exit 1; }
IFS= read -r -s password || { echo "Password missing" >&2; exit 1; }
[[ ${#password} -ge 8 && $password != *:* && $password != *$'\n'* ]] || { echo "Unsafe user password" >&2; exit 1; }
target=/mnt/kova-install
[[ ! -e $target ]] || { echo "$target already exists" >&2; exit 1; }
mkdir -p "$target"
cleanup() {
  rc=$?
  set +e
  if mountpoint -q "$target"; then umount -R "$target"; fi
  rmdir "$target" 2>/dev/null || true
  if (( rc != 0 )); then echo "Install failed (exit $rc). Disk may contain partial installation." >&2; fi
}
trap cleanup EXIT
# Do not erase anything unless package sources and required tools are reachable.
for cmd in pacstrap arch-chroot sgdisk partprobe mkfs.btrfs mkfs.fat genfstab; do
  command -v "$cmd" >/dev/null || { echo "Missing installer tool $cmd" >&2; exit 1; }
done
curl -fLsS --max-time 15 --head https://archlinux.org/ >/dev/null ||
 { echo "No network for pacstrap; refusing to erase disk" >&2; exit 1; }
echo "ERASING $disk — creating GPT and Kova Btrfs filesystem"
sgdisk --zap-all "$disk"
sgdisk --clear --new=1:0:+1G --typecode=1:ef00 --change-name=1:KOVA-EFI "$disk"
sgdisk --new=2:0:0 --typecode=2:8300 --change-name=2:KOVA-ROOT "$disk"
partprobe "$disk"
udevadm settle
mapfile -t parts < <(lsblk -ln -p -o PATH,TYPE -- "$disk" | awk '$2=="part"{print $1}')
[[ ${#parts[@]} -eq 2 ]] || { echo "Partition discovery failed" >&2; exit 1; }
efi=${parts[0]}; root=${parts[1]}
mkfs.fat -F32 -n KOVA_EFI "$efi"
mkfs.btrfs -f -L KOVA_ROOT "$root"
mount "$root" "$target"
for sv in @ @home @snapshots @var_log @var_cache; do btrfs subvolume create "$target/$sv"; done
umount "$target"
mount -o subvol=@,compress=zstd:3,noatime "$root" "$target"
mkdir -p "$target/boot" "$target/home" "$target/var/log" "$target/var/cache"
mount -o subvol=@home,compress=zstd:3,noatime "$root" "$target/home"
mount -o subvol=@var_log,compress=zstd:3,noatime "$root" "$target/var/log"
mount -o subvol=@var_cache,compress=zstd:3,noatime "$root" "$target/var/cache"
mount "$efi" "$target/boot"
# Signed Arch repositories; no ephemeral CI artifacts for installed-kernel updates.
pacstrap -K "$target" \
  base linux linux-firmware mkinitcpio btrfs-progs snapper snap-pac \
  sudo fish git curl jq rate-mirrors neovim networkmanager \
  eza bat fd ripgrep bottom dust procs dysk sd uutils-coreutils \
  zoxide fzf tmux starship wayland mesa libinput seatd \
  greetd greetd-tuigreet swaybg mako libnotify pipewire pipewire-alsa pipewire-pulse wireplumber brightnessctl alacritty librewolf xdg-utils ttf-jetbrains-mono ttf-nerd-fonts-symbols-mono adwaita-icon-theme xorg-xwayland wl-clipboard \
  zram-generator dosfstools efibootmgr
# Snapper create-config requires .snapshots to be unmounted.
arch-chroot "$target" snapper -c root create-config /
btrfs subvolume delete "$target/.snapshots"
mkdir -p "$target/.snapshots"
mount -o subvol=@snapshots,compress=zstd:3,noatime "$root" "$target/.snapshots"
genfstab -U "$target" > "$target/etc/fstab"
ln -sfn "/usr/share/zoneinfo/$timezone" "$target/etc/localtime"
arch-chroot "$target" hwclock --systohc
printf 'LANG=%s\n' "$locale" > "$target/etc/locale.conf"
printf 'KEYMAP=%s\n' "$keyboard" > "$target/etc/vconsole.conf"
printf '%s\n' "$hostname" > "$target/etc/hostname"
grep -Eq "^#?$locale[[:space:]]+UTF-8" "$target/etc/locale.gen" || { echo "Unknown locale" >&2; exit 1; }
sed -i -E "s/^#($locale[[:space:]]+UTF-8)/\1/" "$target/etc/locale.gen"
arch-chroot "$target" locale-gen
for file in /usr/local/bin/kova /usr/local/bin/anvil /usr/local/bin/anvilctl /usr/local/bin/kova-session /usr/local/bin/kova-osd; do
  install -Dm755 "$file" "$target$file"
done
for name in update-mirrors update-news update-anvil update-wallpapers set-wallpaper check-battery; do
  install -Dm755 "/usr/local/lib/kova/$name" "$target/usr/local/lib/kova/$name"
done
for name in kova-mirrors kova-news kova-update-anvil kova-update-wallpapers; do
  install -Dm644 "/etc/systemd/system/$name.service" "$target/etc/systemd/system/$name.service"
  install -Dm644 "/etc/systemd/system/$name.timer" "$target/etc/systemd/system/$name.timer"
done
for name in kova-battery.service kova-battery.timer; do
  install -Dm644 "/usr/lib/systemd/user/$name" "$target/usr/lib/systemd/user/$name"
done
install -Dm644 /etc/greetd/config.toml "$target/etc/greetd/config.toml"
# System-wide XDG browser defaults, overridable by each user's mimeapps.list.
install -Dm644 /etc/xdg/mimeapps.list "$target/etc/xdg/mimeapps.list"
install -Dm644 /etc/fonts/conf.d/70-kova-monospace.conf "$target/etc/fonts/conf.d/70-kova-monospace.conf"
install -Dm644 /etc/os-release "$target/etc/os-release"
install -Dm644 /etc/issue "$target/etc/issue"
install -Dm644 /usr/local/share/kova/anvil-version "$target/usr/local/share/kova/anvil-version"
install -Dm644 /usr/share/wayland-sessions/anvil.desktop "$target/usr/share/wayland-sessions/anvil.desktop"
mkdir -p "$target/etc/skel/.config" "$target/etc/fish/conf.d" "$target/var/lib/kova"
cp -a /etc/skel/.config/. "$target/etc/skel/.config/"
cp -a /etc/fish/conf.d/kova*.fish "$target/etc/fish/conf.d/"
cp -a /var/lib/kova/wallpapers "$target/var/lib/kova/wallpapers"
mkdir -p "$target/etc/systemd" "$target/etc/sudoers.d"
printf '[zram0]\nzram-size = ram / 2\ncompression-algorithm = zstd\n' > "$target/etc/systemd/zram-generator.conf"
printf '%%wheel ALL=(ALL:ALL) ALL\n' > "$target/etc/sudoers.d/10-kova-wheel"
chmod 0440 "$target/etc/sudoers.d/10-kova-wheel"
arch-chroot "$target" useradd -m -G wheel,video,audio -s /usr/bin/fish -- "$username"
printf '%s:%s\n' "$username" "$password" | arch-chroot "$target" chpasswd
unset password
arch-chroot "$target" passwd -l root
arch-chroot "$target" systemctl enable NetworkManager.service systemd-timesyncd.service greetd.service \
  snapper-timeline.timer snapper-cleanup.timer kova-mirrors.timer \
  kova-news.timer kova-update-anvil.timer kova-update-wallpapers.timer
arch-chroot "$target" systemctl --global enable kova-battery.timer
arch-chroot "$target" snapper -c root create --description 'Kova first installation'
arch-chroot "$target" bootctl --esp-path=/boot --no-variables install
uuid=$(blkid -s UUID -o value "$root")
mkdir -p "$target/boot/loader/entries"
printf 'default kova.conf\ntimeout 3\neditor no\n' > "$target/boot/loader/loader.conf"
printf 'title Kova Linux\nlinux /vmlinuz-linux\ninitrd /initramfs-linux.img\noptions root=UUID=%s rw rootflags=subvol=@\n' "$uuid" > "$target/boot/loader/entries/kova.conf"
echo "Kova installed. Remove installation ISO and reboot."
