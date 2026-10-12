# Kova terminal logo

Kova ships one logo in different text encodings. All files reside in
\`/usr/share/kova/\` on both the live ISO and the installed system.

- \`logo-fastfetch.txt\`: 22-line Unicode logo, silver \`$1\`, orange \`$2\`.
- \`logo-fastfetch-mini.txt\`: smaller Unicode variant.
- \`logo-neofetch.txt\`: same design with Neofetch c1/c2 color placeholders.
- \`logo-ascii.txt\`: plain 7-bit ASCII for rescue TTYs.
- \`/etc/xdg/fastfetch/config.jsonc\`: system-wide Fastfetch default. User
  config under ~/.config/fastfetch/config.jsonc overrides it.
- \`/etc/skel/.config/neofetch/config.conf\`: optional Neofetch defaults for
  newly created users.

Fastfetch is included in both the ISO and installed system. Run \`fastfetch\`
to see the logo. No fetch tool is forced to run on every shell startup.
The two Fastfetch colors are #DEE5EC and #FA7925.

Optional mini logo: \`fastfetch --logo-type file --logo /usr/share/kova/logo-fastfetch-mini.txt\`.
Neofetch is not bundled; its classic terminal palette approximates silver and
orange with colors 7 and 3 when Neofetch is separately installed.
