#!/usr/bin/env bash
set -Eeuo pipefail
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/profile/airootfs/etc"
cat > "$tmp/profile/pacman.conf" <<'PACMAN'
[options]
Architecture = auto
SigLevel = Required DatabaseOptional
[core]
Include = /etc/pacman.d/mirrorlist
PACMAN
printf "UNMODIFIED\n" > "$tmp/profile/airootfs/etc/pacman.conf"
bash scripts/configure-live-content.sh "$tmp/profile"
cmp -s "$tmp/profile/airootfs/etc/pacman.conf" <(printf "UNMODIFIED\n")
if bash scripts/configure-live-content.sh "$tmp/profile" >/dev/null 2>&1; then
  echo "Policy was allowed to duplicate itself" >&2; exit 1
fi
python3 - "$tmp/profile/pacman.conf" <<'PY'
import fnmatch, pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text()
assert text.count('[options]') == 1
assert text.count('# KOVA_LIVE_CONTENT_POLICY_START') == 1
assert text.index('# KOVA_LIVE_CONTENT_POLICY_START') < text.index('[core]')
rules = []
for line in text.splitlines():
    if line.startswith('NoExtract = '):
        rules.extend(line.partition('=')[2].strip().split())
assert len(rules) >= 10, rules
def excluded(file):
    value = False
    for rule in rules:
        keep = rule.startswith('!')
        pattern = rule[1:] if keep else rule
        if fnmatch.fnmatchcase(file, pattern):
            value = not keep
    return value
for keep in [
    'usr/share/locale/de/LC_MESSAGES/coreutils.mo',
    'usr/share/locale/de_DE/LC_MESSAGES/librewolf.mo',
    'usr/share/locale/en_GB/LC_MESSAGES/app.mo',
    'usr/share/locale/C/LC_MESSAGES/app.mo',
    'usr/share/man/man1/pacman.8.gz',
    'usr/share/man/man8/locale-gen.8.gz',
    'usr/share/man/de/man1/foo.1.gz',
    'usr/share/man/en/man1/foo.1.gz',
    'usr/share/i18n/locales/fr_FR',
    'usr/share/zoneinfo/Europe/Berlin',
    'usr/share/keymaps/i386/qwerty/us.map.gz',
    'usr/share/licenses/librewolf/LICENSE',
]:
    assert not excluded(keep), keep
for remove in [
    'usr/share/locale/fr/LC_MESSAGES/foo.mo',
    'usr/share/locale/ja/LC_MESSAGES/foo.mo',
    'usr/share/man/fr/man1/foo.1.gz',
    'usr/share/man/ja/man1/foo.1.gz',
    'usr/share/doc/bash/README',
]:
    assert excluded(remove), remove
print('Live translations/manpages extraction policy and installer-locale preservation: OK')
PY
