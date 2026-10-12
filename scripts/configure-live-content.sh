#!/usr/bin/env bash
set -Eeuo pipefail
# Live ISO build-only Pacman extraction policy. DO NOT alter the installed system.
profile=${1:?Usage: configure-live-content.sh ARCHISO_PROFILE}
conf="$profile/pacman.conf"
[[ -f "$conf" ]] || { echo "Missing Archiso pacman.conf" >&2; exit 1; }
grep -Eq '^\[options\][[:space:]]*$' "$conf" || { echo "Missing [options] section" >&2; exit 1; }
# Preserve DE/EN/C translations. /usr/share/i18n locale source definitions remain.
# Keep English man1/man3/... and DE/EN translated manpages.
# /usr/share/licenses stays untouched; only nonessential docs are excluded.
if grep -Fq '# KOVA_LIVE_CONTENT_POLICY_START' "$conf"; then echo "Policy already applied" >&2; exit 1; fi
policy=$(cat <<'POLICY'
# KOVA_LIVE_CONTENT_POLICY_START
# Only mkarchiso's temporary profile uses these rules.
# Later negated (!...) paths restore languages that should remain.
NoExtract = usr/share/locale/* !usr/share/locale/de*/LC_MESSAGES/* !usr/share/locale/en*/LC_MESSAGES/* !usr/share/locale/C/LC_MESSAGES/* !usr/share/locale/locale.alias
NoExtract = usr/share/man/* !usr/share/man/man*/* !usr/share/man/de*/* !usr/share/man/en*/*
NoExtract = usr/share/doc/*
# KOVA_LIVE_CONTENT_POLICY_END
POLICY
)
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
awk -v policy="$policy" '{ print; if ($0 ~ /^\[options\][[:space:]]*$/ && !done) { print policy; done=1 } }' "$conf" > "$tmp"
cat "$tmp" > "$conf"
echo "Kova live ISO: retain DE/EN locale+man, exclude other translations and nonessential docs"
