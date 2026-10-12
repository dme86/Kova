#!/usr/bin/env bash
set -Eeuo pipefail
# Read-only ISO build size inventory. Usage: OUT_DIR WORK_DIR PROFILE_DIR
(( $# == 3 )) || { echo "Usage: $0 OUT_DIR ARCHISO_WORK_DIR PROFILE_DIR" >&2; exit 2; }
out=$1
work=$2
profile=$3
mkdir -p "$out"
report="$out/SIZE_REPORT.md"
root="$work/x86_64/airootfs"

{
  printf '# Kova ISO size audit\n\n'
  printf 'Generated during mkarchiso from the exact packages and files in this build.\n\n'
  printf '## ISO images\n\n'
  printf '| Image | Bytes | MiB |\n| --- | ---: | ---: |\n'
  compgen -G "$out/*.iso" >/dev/null || { echo "No ISO files in $out" >&2; exit 1; }
  for iso in "$out"/*.iso; do
    bytes=$(stat -c '%s' "$iso")
    printf '| %s | %s | %s |\n' "$(basename "$iso")" "$bytes" "$((bytes / 1048576))"
  done
  printf '\n## ISO build profile\n\n'
  count=$(grep -Ev '^[[:space:]]*(#|$)' "$profile/packages.x86_64" | wc -l)
  printf -- '- Explicit package declarations: %s\n' "$count"
  printf -- '- Archiso compressed image artifacts (bytes):\n\n'
  find "$work" -type f \( -name '*.sfs' -o -name '*.squashfs' -o -name '*.erofs' \) -printf '%s\t%p\n' | sort -nr | head -n 15 || true
  printf '\n## Installed root filesystem\n\n'
  if [[ -d "$root" ]]; then
    printf -- '- Rootfs uncompressed directory size: %s bytes\n\n' "$(du -sb "$root" | awk '{print $1}')"
    printf '### Largest root filesystem directories\n\n'
    du -h -d 2 "$root/usr" "$root/var" "$root/opt" 2>/dev/null | sort -hr | head -n 30 || true
    printf '\n### Localization and documentation remaining in the live image\n\n'
    printf '| Directory | Bytes | MiB |\n| --- | ---: | ---: |\n'
    for relative in usr/share/locale usr/share/man usr/share/doc usr/share/i18n usr/share/licenses; do
      if [[ -d "$root/$relative" ]]; then
        bytes=$(du -sb "$root/$relative" | cut -f1)
        printf '| /%s | %s | %s |\n' "$relative" "$bytes" "$((bytes / 1048576))"
      else
        printf '| /%s | absent | 0 |\n' "$relative"
      fi
    done
    printf '\n### Wallpapers\n\n'
    wallpapers="$root/var/lib/kova/wallpapers"
    if [[ -d "$wallpapers/files" ]]; then
      count=$(find "$wallpapers/files" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | wc -l)
      bytes=$(find "$wallpapers/files" -type f -printf '%s\n' | awk '{sum += $1} END {printf "%.0f", sum}')
      printf -- '- Offline wallpaper images: %s\n- Wallpaper image bytes: %s\n' "$count" "$bytes"
      if [[ -d "$wallpapers/.git" ]]; then
        printf -- '- Embedded wallpaper git checkout bytes: %s\n' "$(du -sb "$wallpapers/.git" | awk '{print $1}')"
      else
        printf -- '- Embedded wallpaper git checkout: none\n'
      fi
    else
      printf 'No offline wallpaper image directory found.\n'
    fi
    printf '\n### Largest pacman-installed packages (installed size)\n\n'
    db="$root/var/lib/pacman/local"
    if [[ -d "$db" ]]; then
      tmp=$(mktemp)
      for desc in "$db"/*/desc; do
        [[ -f "$desc" ]] || continue
        awk '/^%NAME%$/ {getline; name=$0} /^%SIZE%$/ {getline; bytes=$0} END {if (name != "") printf "%.0f\t%s\n", bytes+0, name}' "$desc"
      done | sort -nr > "$tmp"
      head -n 30 "$tmp" | awk -F '\t' '{printf "%.1f MiB\t%s\n", $1/1048576, $2}'
      rm -f "$tmp"
    else
      printf 'The Archiso pacman database was not found.\n'
    fi
  else
    printf 'No assembled rootfs at %s; ISO size and profile counts still recorded.\n' "$root"
  fi
} > "$report"
echo "Wrote ISO size audit: $report"
