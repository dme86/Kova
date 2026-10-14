#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY'
from pathlib import Path
build = Path("scripts/build.sh").read_text()
pipeline = Path(".github/workflows/build.yml").read_text()
test = Path("scripts/test-iso.sh").read_text()
assert "KOVA_CI_IMAGE:-0" in build, "default mode must be a clean ISO"
assert 'rm -f "$PROFILE/airootfs/usr/local/lib/kova/ci-smoke"' in build
assert 'rm -f "$PROFILE/airootfs/etc/systemd/system/kova-ci-smoke.service"' in build
assert '== 1 ]]; then' in build
assert 'ln -s ../kova-ci-smoke.service ' in build
assert 'iso_name="kova-ci"' in build
assert 'KOVA_CI_IMAGE=1 KOVA_OUT_DIR=/repo/out-ci' in pipeline
assert 'name: kova-ci-iso' in pipeline
assert 'name: kova-iso' in pipeline
assert 'Boot exact production ISO using BIOS' in pipeline
assert 'Boot exact production ISO using OVMF/UEFI' in pipeline
assert 'KOVA_TEST_FIRMWARE=uefi' in pipeline
assert 'ovmf' in pipeline
assert 'console=ttyS0,115200n8' in build
assert 'KOVA_TEST_FIRMWARE:-bios' in test
assert 'OVMF_CODE_4M.fd' in test

assert 'KOVA_TEST_MODE=production' in pipeline
assert 'KOVA_TEST_MODE=ci' in pipeline
assert 'KOVA_TEST_MODE:-production' in test
assert 'KOVA_CI_PASS' in test
assert 'scripts/assert-production-boot.sh' in test
assert 'KOVA_LIVE_TTY1_READY user=kova tty=tty1' in Path('scripts/assert-production-boot.sh').read_text()
assert 'kova login:' in Path('scripts/assert-production-boot.sh').read_text()
assert "gh release create" in pipeline
assert 'out/SHA256SUMS' in pipeline
# The release job now resolves the single already-tested ISO to "$iso".
# Accept the previous glob too, but never publish the CI-only image.
assert 'out/*.iso out/SHA256SUMS' in pipeline or '"$iso" out/SHA256SUMS' in pipeline
assert 'out-ci/*.iso' not in pipeline.split("  release:", 1)[1]
print("CI instrumentation isolation and clean production ISO publishing: OK")
PY
