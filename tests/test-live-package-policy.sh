#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY'
from pathlib import Path
source = Path("scripts/build.sh").read_text()
packages = source.split("<<'PKGS'\n", 1)[1].split("\nPKGS", 1)[0].splitlines()
assert "go" not in packages, "Go toolchain must not be explicitly bundled in the live ISO"
assert "npm" in packages, "Mason LSP tooling must retain npm in live ISO"
assert "tree-sitter-cli" in packages, "Treesitter parser builds must remain available"
print("Live ISO package policy: Go excluded, Neovim tooling preserved")
PY
