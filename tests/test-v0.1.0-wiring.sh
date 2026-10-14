#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY'
from pathlib import Path

installer = Path("scripts/install-system.sh").read_text()
identity = 'install -Dm644 /etc/os-release "$target/etc/os-release"'
assert installer.count(identity) == 1, "Do not duplicate installation of os-release"
assert installer.index(identity) < installer.index('arch-chroot "$target" mkinitcpio -P'), "Stale Arch identity would be embedded in initramfs"
assert 'PRETTY_NAME="Kova Linux"' in Path("config/airootfs/etc/os-release").read_text()
assert "title Kova Linux" in installer
assert 'install -Dm644 /etc/xdg/fastfetch/config.jsonc' in installer
assert "fastfetch" in installer

tui = Path("crates/kova-cli/src/tui.rs").read_text()
renderer = tui[tui.index("    fn render("):tui.index("    fn byte(")]
assert r'\x1b[2J' not in renderer, "Whole-screen clears on every keystroke cause flicker"
assert "self.previous_lines" in renderer and "self.previous_size" in renderer
assert r'\x1b[2K' in renderer, "Redraw only changed rows"

workflow = Path(".github/workflows/build.yml").read_text()
assert 'gh release create v0.1.0' in workflow
assert 'gh release view v0.1.0' in workflow
assert '2147483648' in workflow
assert "tags: ['v*']" not in workflow, "Tag triggered rebuild wastes a CI ISO build"
assert 'needs: boot' in workflow
assert 'GH_REPO: ${{ github.repository }}' in workflow
print("Kova v0.1.0 identity, terminal renderer and single-build release policy: OK")
PY
