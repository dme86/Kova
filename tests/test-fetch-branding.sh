#!/usr/bin/env bash
set -Eeuo pipefail
python3 - <<'PY'
import json
from pathlib import Path

root = Path("config/airootfs")
logos = root / "usr/share/kova"
for name in ("logo-fastfetch.txt", "logo-fastfetch-mini.txt", "logo-neofetch.txt", "logo-ascii.txt"):
    assert (logos / name).is_file(), name
    assert (logos / name).stat().st_size < 8192, name
normal = (logos / "logo-fastfetch.txt").read_text()
mini = (logos / "logo-fastfetch-mini.txt").read_text()
neo = (logos / "logo-neofetch.txt").read_text()
ascii_art = (logos / "logo-ascii.txt").read_text()
assert normal.count("\n") == 22
assert mini.count("\n") < normal.count("\n")
for content in (normal, mini):
    assert "$1" in content and "$2" in content
    assert "\x1b" not in content
assert neo == normal.replace("$1", "$" + "{c1}").replace("$2", "$" + "{c2}")
assert all(ord(c) < 128 for c in ascii_art)
cfg = json.loads((root / "etc/xdg/fastfetch/config.jsonc").read_text())
assert cfg["logo"]["type"] == "file"
assert cfg["logo"]["source"] == "/usr/share/kova/logo-fastfetch.txt"
assert cfg["logo"]["color"] == {"1": "#DEE5EC", "2": "#FA7925"}
neocfg = (root / "etc/skel/.config/neofetch/config.conf").read_text()
assert 'image_backend="ascii"' in neocfg
assert 'image_source="/usr/share/kova/logo-neofetch.txt"' in neocfg
assert 'ascii_colors=(7 3)' in neocfg
live = Path("scripts/build.sh").read_text()
packages = live.split("<<'PKGS'\n", 1)[1].split("\nPKGS", 1)[0].splitlines()
assert "fastfetch" in packages
assert "go" not in packages
installer = Path("scripts/install-system.sh").read_text()
assert "fastfetch" in installer
assert 'install -Dm644 "$logo" "$target$logo"' in installer
assert 'install -Dm644 /etc/xdg/fastfetch/config.jsonc' in installer
assert 'cp -a /etc/skel/.config/.' in installer
print("Kova fetch branding: OK")
PY
