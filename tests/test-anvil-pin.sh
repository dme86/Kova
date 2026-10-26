#!/usr/bin/env bash
set -Eeuo pipefail
python3 - <<'PY'
from pathlib import Path
import re

script = Path("scripts/install-anvil.sh").read_text()
version = re.search(r"^version=([0-9]+\.[0-9]+\.[0-9]+)$", script, re.M)
digest = re.search(r"^sha256=([0-9a-f]{64})$", script, re.M)
assert version and digest, "Anvil release version and checksum must be pinned"
assert version.group(1) == "0.6.4", "Kova v0.1.2 must ship Anvil v0.6.4"
assert digest.group(1) == "36e47f3393471db7ecb80c02d76e943b239124f838c4e05a6ba08ba484f0d802", "Anvil v0.6.4 release archive digest mismatch"
for value in (
    'url="https://github.com/dme86/anvil/releases/download/v$version/$name.tar.gz"',
    'printf \'%s  %s\\n\' "$sha256" "$work/$name.tar.gz" | sha256sum -c -',
    'install -Dm755 "$work/$name/$exe" "$root/usr/local/bin/$exe"',
    'printf \'%s\\n\' "v$version" > "$root/usr/local/share/kova/anvil-version"',
    'grep -Fqx \'terminal = "alacritty"\' "$config"',
    'grep -Fqx \'overview = "Tab"\' "$config"',
    'grep -Fqx \'xwayland = false\' "$config"',
    'grep -Fqx \'[bar.network]\' "$config"',
    'grep -Fqx \'volume_up = "kova-osd volume up"\' "$config"',
):
    assert value in script, f"Missing Anvil integration safeguard: {value}"
installer = Path("scripts/install-system.sh").read_text()
assert 'for file in /usr/local/bin/kova /usr/local/bin/anvil /usr/local/bin/anvilctl' in installer
assert 'install -Dm644 /usr/local/share/kova/anvil-version "$target/usr/local/share/kova/anvil-version"' in installer
print("Pinned Anvil v0.6.4, archive checksum and live/installed integration: OK")
PY
