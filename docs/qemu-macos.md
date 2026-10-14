# Boot Kova with QEMU on macOS / Nix (issue #29)

The Kova v0.1.0 production ISO (SHA256:
`7e2f9b10e4bd0c89c24d0a0ce6ded1554f51431e2d431ac2804927f78ad9474e`)
passed **both BIOS and UEFI/OVMF CI boots** on Ubuntu. One Apple Silicon
Mac with QEMU 10.2.4 from Nix successfully booted the exact ISO in BIOS
mode, but the previously configured two-pflash UEFI VM printed
`BdsDxe: failed to load Boot0002 "UEFI Misc Device"` and fell back to PXE.
This is **not** evidence that the ISO itself is invalid. A stale UEFI NVRAM
entry, a CODE/VARS mismatch, or a different virtual device ordering can
cause this symptom.

## Reproducible macOS UEFI test

Use the **matching code and pristine variables template** shipped with
your installed firmware package. Nix's `edk2-x86_64-code.fd` must be
paired with the corresponding VARS template from the same build. Do not
guess a template from another firmware release. Inspect your QEMU
package's `share/qemu` / OVMF files if their paths are unknown.

```sh
export KOVA_OVMF_CODE='/nix/store/.../share/qemu/edk2-x86_64-code.fd'
export KOVA_OVMF_VARS_TEMPLATE='/nix/store/.../share/qemu/<matching-vars>.fd'
export KOVA_QEMU_STATE_DIR='/tmp/kovavm/kova-uefi'
# Optional installed disk; OMIT on first troubleshooting boot:
# export KOVA_QEMU_DISK='/tmp/kovavm/kova.qcow2'
bash scripts/qemu-macos.sh /tmp/kovavm/kova-2026.10.14-x86_64.iso
```

The helper writes a **new, separate** `kova-uefi-vars-fresh.fd` on first use.
It does **not** touch the original `/tmp/kovavm/uefi-vars.fd` or an existing
qcow2 disk. On subsequent runs the new variables file is preserved to
retain EFI boot entries; only delete/rename this separate test-state
directory *intentionally* when you want a fresh firmware reset.

If the firmware still starts PXE, enter the firmware **Boot Manager** and
select the UEFI QEMU DVD/CD-ROM entry. Once the Live ISO boots, optionally
attach the qcow2 through `KOVA_QEMU_DISK` for installer tests.

BIOS/SeaBIOS fallback (no OVMF files needed):

```sh
KOVA_QEMU_FIRMWARE=bios bash scripts/qemu-macos.sh \
  /tmp/kovavm/kova-2026.10.14-x86_64.iso
```

`KOVA_QEMU_DRY_RUN=1` prints the arguments without launching QEMU.
The helper uses TCG for x86_64 on Apple Silicon; it is slow but compatible.
Linux CI uses Ubuntu's matched `OVMF_CODE_4M.fd` and `OVMF_VARS_4M.fd`;
passing that test does not certify every third-party macOS firmware pair.
