<p align="center">
  <img src="assets/kova-logo.png" alt="Kova Linux" width="560">
</p>

# Kova Linux

Kova is a minimal, Arch-based Linux live environment with a Rust-friendly command-line toolset. It uses the official Archiso `releng` profile as its foundation and adds its own shell, editor configuration, and system defaults.

> **Status:** Experimental. ISOs are built and boot-tested in QEMU on GitHub Actions; physical hardware and UEFI boot are not yet covered.

## Included

- **Arch Linux** — rolling-release packages, `pacman`, systemd, and the standard Archiso boot environment
- **Fish + Tide** — Fish as the interactive shell, with Tide v6 included in the image
- **Neovim** — default editor, configured from [dme86/neovim](https://github.com/dme86/neovim)
- **Rust CLI tools** — `eza`, `bat`, `fd`, `ripgrep`, `bottom`, `uutils-coreutils`, and `zoxide`
- **Development tools** — `git`, `fzf`, `lazygit`, `tmux`, `npm`, `go`, `tree-sitter-cli`, `unzip`, and build tools
- **Networking** — NetworkManager, inherited from Archiso

## Branding and command-line defaults

The live system identifies as Kova Linux via `/etc/os-release` (`ID=kova`, `ID_LIKE=arch`) and uses Kova-branded BIOS/UEFI boot entries and login text. The upstream Arch kernel, packaging, and repository provenance are retained.

Interactive Fish sessions prefer `eza` for `ls`, `bat` for `cat`, and the uutils implementations of `cp`, `mv`, `rm`, `mkdir`, `touch`, `sort`, and `wc`. These are Fish aliases, not replacements for executables in `/usr/bin`. System services and non-interactive scripts retain the original commands to preserve compatibility.

`rg` and `fd` deliberately keep their own command names: their options and behavior are not interchangeable with `grep` and `find`.

## Live environment

The live system uses the hostname `kova` and automatically logs in as `kova` on `tty1`, using Fish. The account is created during boot, with its password locked and passwordless `sudo` enabled for the live session.

These permissions apply **only to the disposable live environment**. A persistent installation requires its own user provisioning and authentication policy.

Tide is included in the image under `/etc/fish/` and can be customized with `tide configure`. A Nerd Font is recommended for full symbol support but is not bundled.

## Neovim

The build imports [dme86/neovim](https://github.com/dme86/neovim) into `/etc/skel/.config/nvim`. The `kova` user inherits that configuration on first boot. The upstream commit is recorded in `.kova-source-commit`.

The configuration is available offline, but `lazy.nvim`, Neovim plugins, Mason language servers, and Treesitter parsers are **not bundled**. Their initial installation may require network access. Without a persistent writable filesystem, installed plugins will not survive a reboot.

By default, the build tracks the `main` branch. `KOVA_NVIM_REF` selects a different branch or tag, and `KOVA_NVIM_REPO` overrides the source repository.

## Builds

Kova ISOs are assembled with `mkarchiso` from the official Archiso `releng` profile and the additions in `config/airootfs/`. The original Arch ISO is not used as a build input.

The GitHub Actions workflow builds on pushes to `main`, on version tags matching `v*`, or when dispatched manually. Successful builds produce a `kova-iso` artifact containing the ISO and `SHA256SUMS`. Version tags also create a GitHub Release.

The CI pipeline checks shell syntax, verifies the ISO checksum, then boots the ISO under QEMU and validates its live user, Fish/Tide, Neovim binary, and CLI tools. ISO publication only occurs after the boot test passes. The `kova-qemu-logs` artifact preserves serial-console output and QEMU diagnostics for debugging failures. GitHub-hosted nested virtualization is experimental; the QEMU runner falls back to TCG if KVM is unavailable.

### Local build

An Arch Linux host with root access is required:

```sh
sudo pacman -Syu --needed archiso curl git
sudo bash scripts/install-tide.sh config/airootfs
sudo bash scripts/install-neovim-config.sh
sudo bash scripts/build.sh
```

The ISO and checksum are written to `out/`.

Tide and the Neovim configuration are fetched during the build. The Tide install script modifies `config/airootfs/etc/fish/`; for an audited release, dependencies should be pinned to immutable commits and verified with checksums. GitHub-hosted runners may also require additional disk space for the Archiso build.

## Boot testing

Archiso includes `run_archiso` for testing images with QEMU:

```sh
sudo pacman -S --needed qemu-desktop edk2-ovmf
run_archiso -i out/kova-*.iso
```

For automated serial-console testing with QEMU installed:

```sh
bash scripts/test-iso.sh
```

The smoke-test service starts only in a virtual machine with `/dev/ttyS0`. It reports `KOVA_CI_PASS` or `KOVA_CI_FAIL` over the serial port. CI currently covers BIOS boot; UEFI, the graphical environment and a persistent installation require separate tests.

## Upstream

Kova is an Arch Linux derivative, not an independent distribution. It uses Arch packages, repositories, and the official [Archiso](https://github.com/archlinux/archiso) tooling.
