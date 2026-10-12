# Kova wallpaper pool

**Live ISO:** The ISO build chooses three random JPG/JPEG/PNG files from
`dme86/.wallpapers` and embeds the actual images under
`/var/lib/kova/wallpapers/files`. The short-lived build checkout is deleted,
including `.git`. Anvil therefore always has an offline background.

**Installed system:** Those three files remain as permanent offline seeds.
A root-owned systemd timer starts two minutes after every boot, invoking
`kova wallpaper boot`. On the first boot with connectivity, this downloads
five randomly chosen, additional wallpapers into
`/var/lib/kova/wallpapers/cache`. After four more successful timer invocations,
the next boot downloads five new randomly chosen images.

The cache avoids the three offline seed filenames, and stores no Git checkout.
Downloads are constrained to known image formats and the official raw-content
domain; each file is checked against the GitHub API's declared byte length and
Git blob SHA, and checked for matching image signatures. The replacement cache
is activated only once **all five** images have downloaded and passed validation.
If offline, GitHub is rate-limited, a download fails or the system shuts down,
the previous cache and all seed images remain available. Interrupted cache
swaps and staging directories are recovered/cleaned up on the next run.

Anvil chooses one random wallpaper from the available seed/cache images at
each new desktop session. The current session's wallpaper is not changed by a
background download. `kova wallpaper sync` triggers an immediate refresh.

Commands:

```sh
kova wallpaper status
sudo kova wallpaper sync
# The timer invokes this itself:
sudo kova wallpaper boot
```

The installed packages include `curl`, `jq`, and `git` for GitHub metadata,
HTTP transfer and Git blob verification; there is **no** local Git repository.

The systemd timer is installed/enabled by `scripts/install-system.sh`.
It is intentionally **not** enabled in the live ISO.
