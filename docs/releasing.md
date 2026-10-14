# Kova v0.1.0 release

The first verified `main` build that contains this change automatically publishes
**v0.1.0** on GitHub Releases, after the production ISO has passed both BIOS
and UEFI QEMU live boot tests. No second tag-triggered ISO rebuild is needed.

- Tag and releases page: https://github.com/dme86/Kova/releases/tag/v0.1.0
- Assets: the exact CI-tested production ISO plus `SHA256SUMS`.
- GitHub's per-release-asset file size limit of **2 GiB** is checked.
- Existing v0.1.0 assets are never overwritten on subsequent pushes.
- The next release requires deliberately updating the version in the workflow.
- Installation is experimental and wipes a dedicated disk.

Download: `gh release download v0.1.0 -R dme86/Kova --pattern '*.iso'`.

Bundled improvements: Fastfetch K logo (#22), reduced TUI redraw flicker
(#24), correct initrd identity (#27). Audit noise (#25) remains separate
because production boot smoke tests rely on PAM/audit events. Optical
`systemd-loop@` failure (#26) is the upstream systemd bug
https://github.com/systemd/systemd/issues/43605, fixed upstream but
potentially still present in current Arch packages.
