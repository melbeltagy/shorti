# shell: `sn`, `ds`, `aup` helpers

System upkeep for an apt + snap box, plus the shared bits (`print`, `_shorti_require`) the other folders build on. `[sudo]` in any help output marks a command that needs root.

- **`aup`** full update: `apt update`, `upgrade`, `autoremove --purge`, `autoclean`, then `snap refresh` when snapd is present, then a reboot-required check. Stays on `upgrade` rather than `full-upgrade` so an unattended `-y` never removes packages.
- **`sn`** snap: `up` (refresh), `orphans` (report), `clean` (old revisions, orphans, cache)
- **`ds`** disk space: `usage` (free space and what is reclaimable), `top` (ncdu), `clean`
- **`shorti`** lists every helper in the repo
- Aliases: `o`, `cls`, `ll`, and `lls` when [lsd](https://github.com/lsd-rs/lsd) is installed

Run `sn help` or `ds help` for the full command list with examples.

Worth knowing:

- `sn orphans` is read-only and prints the `snap remove` commands rather than running them. It flags a content provider only when *all* its slots are unconnected; a slot whose consumer is installed but merely disconnected is listed separately, matched by plug name, so read that section as a prompt to look closer rather than a verdict.
- `sn clean` sweeps old revisions, then orphans, then the download cache, listing each set and confirming each stage. A pattern limits it to matching snaps and skips the cache, which is shared.
- Old revisions are snapd's rollback buffer, not leftovers: they rebuild at the next refresh. `refresh.retain` cannot go below 2, so "active only" means cleaning after each refresh.
- `ds top` runs `ncdu -x`, so scanning `/` stays off your other mounts and any host share.
- A size reads `needs root` when it is unreadable even with a warm sudo timestamp, and `empty` for a directory holding nothing (`du` reports 4K for the directory entry itself).
- Without `/var/log/journal` the journal lives in `/run` (tmpfs): `ds usage` marks it "frees RAM only" and `ds clean` skips it.
- Reclaiming space inside the guest doesn't shrink a VMware disk: that needs `vmware-toolbox-cmd disk shrink <mountpoint>` afterwards.

## Prerequisites

General ones live in the [root README](../README.md#prerequisites). Specific to these helpers:

- `sudo` for `aup`, `sn up`, `sn clean` and `ds clean`; `sn orphans` and `ds usage` need none
- `snap` is optional and skipped when absent; `ncdu` is only needed by `ds top`
